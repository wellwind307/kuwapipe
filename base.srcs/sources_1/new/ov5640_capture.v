`timescale 1ns / 1ps
// =============================================================================
// ov5640_capture.v —— OV5640 DVP 8-bit (RGB565) 采集前端
//
// 端口语义与设计中原采集 IP 兼容（对外接口为 vid_io 的 cmos_rgb），但内部为
// 本队独立实现：仅依据"对外可观测行为"重写，不复制原实现的结构与语句。
// 输出端口统一命名为 vid_*，避免与工程内 lcd 接口定义（cmos_frame_* 前缀）冲突。
//
// 对外契约（与 BD 中 v_vid_in_axi4s_0 的 vid_io 接口对齐）：
//   cam_pclk         DVP 像素时钟（同时作为输出时钟）
//   cam_vsync/href   帧同步 / 行同步，按 pclk 采样后延迟 2 拍输出
//   cam_data[7:0]    每像素两个字节，高字节在前
//   vid_ce           有效像素期间每两拍一个使能；消隐期间恒为 1（此时数据保持）
//   vid_data         RGB565 -> RGB888，低位补零：{R5,3'b0,G6,2'b0,B5,3'b0}
//   vid_vsync        帧同步（延迟 2 拍）
//   vid_href         行同步（延迟 2 拍）
//   vid_active       与 href 同相
//
// 上电策略：摄像头寄存器由 PS 经 I2C 配置，配置生效前输出不可信，因此前
//   START_FRAME 个帧同步周期不输出（数据/使能为 0），第 START_FRAME+1 个
//   上升沿起放行。
// =============================================================================
module ov5640_capture #(
    parameter integer START_FRAME = 10      // 放行前等待的帧同步个数
)(
    input  wire        rst_n,               // 低有效异步复位
    // ---------------- DVP 摄像头接口 ----------------
    input  wire        cam_pclk,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_data,
    output wire        cam_rst_n,           // 摄像头硬复位：本设计不使用，固定高
    output wire        cam_pwdn,            // 掉电控制：固定 0（正常工作）
    // ---------------- 并行视频输出（vid_io: cmos_rgb） ----------------
    output wire        vid_clk,
    output wire        vid_ce,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 cmos_rgb VSYNC" *)
    output wire        vid_vsync,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 cmos_rgb HSYNC" *)
    output wire        vid_href,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 cmos_rgb ACTIVE_VIDEO" *)
    output wire        vid_active,
    (* X_INTERFACE_INFO = "xilinx.com:interface:vid_io:1.0 cmos_rgb DATA" *)
    output wire [23:0] vid_data
);

    // ---------------------------------------------------------------------
    // 摄像头控制脚：不做硬复位、不进掉电模式
    // ---------------------------------------------------------------------
    assign cam_rst_n = 1'b1;
    assign cam_pwdn  = 1'b0;

    // ---------------------------------------------------------------------
    // 复位：异步置位、同步释放（2 级）
    // 释放后 rst_sync 先保持 0 一拍再拉高，保证下游从确定状态起步
    // ---------------------------------------------------------------------
    reg rst_meta;
    reg rst_sync;
    always @(posedge cam_pclk or negedge rst_n) begin
        if (!rst_n) begin
            rst_meta <= 1'b0;
            rst_sync <= 1'b0;
        end else begin
            rst_meta <= 1'b1;
            rst_sync <= rst_meta;
        end
    end

    // ---------------------------------------------------------------------
    // 同步信号延迟 2 拍
    // ---------------------------------------------------------------------
    reg vsync_d1, vsync_d2;
    reg href_d1,  href_d2;
    always @(posedge cam_pclk or negedge rst_sync) begin
        if (!rst_sync) begin
            vsync_d1 <= 1'b0;
            vsync_d2 <= 1'b0;
            href_d1  <= 1'b0;
            href_d2  <= 1'b0;
        end else begin
            vsync_d1 <= cam_vsync;
            vsync_d2 <= vsync_d1;
            href_d1  <= cam_href;
            href_d2  <= href_d1;
        end
    end

    // 帧起始：延迟链上 vsync 的上升沿
    wire vsync_rise = vsync_d1 & ~vsync_d2;

    // ---------------------------------------------------------------------
    // 上电稳定计数：数满 START_FRAME 个帧起始后放行
    // ---------------------------------------------------------------------
    reg [3:0] frame_cnt;
    reg       output_en;
    always @(posedge cam_pclk or negedge rst_sync) begin
        if (!rst_sync) begin
            frame_cnt <= 4'd0;
            output_en <= 1'b0;
        end else if (vsync_rise) begin
            if (frame_cnt < START_FRAME[3:0])
                frame_cnt <= frame_cnt + 4'd1;
            else
                output_en <= 1'b1;
        end
    end

    // ---------------------------------------------------------------------
    // 8bit -> 16bit：href 期间高低字节交替拼接
    //   phase = 0 收到的字节作为高字节暂存，phase = 1 时与当前字节合并
    // ---------------------------------------------------------------------
    reg         phase;
    reg  [7:0]  byte_hi;
    reg  [15:0] pixel16;
    always @(posedge cam_pclk or negedge rst_sync) begin
        if (!rst_sync) begin
            phase   <= 1'b0;
            byte_hi <= 8'd0;
            pixel16 <= 16'd0;
        end else if (cam_href) begin
            phase   <= ~phase;
            byte_hi <= cam_data;
            if (phase)
                pixel16 <= {byte_hi, cam_data};
        end else begin
            phase   <= 1'b0;
            byte_hi <= 8'd0;
        end
    end

    // 有效像素使能：phase 延迟一拍，正好与 pixel16 对齐
    reg phase_q;
    always @(posedge cam_pclk or negedge rst_sync) begin
        if (!rst_sync)
            phase_q <= 1'b0;
        else
            phase_q <= phase;
    end

    // ---------------------------------------------------------------------
    // 输出：RGB565 -> RGB888（低位补零）
    // 数据口只受 output_en 控制，消隐期间保持最后一个像素（与原 IP 行为一致），
    // 由下游用 ce / active_video 决定是否采样。
    // ---------------------------------------------------------------------
    wire        in_active = output_en & href_d2;
    wire [15:0] px        = pixel16;

    assign vid_clk    = cam_pclk;
    assign vid_vsync  = output_en ? vsync_d2 : 1'b0;
    assign vid_href   = in_active;
    assign vid_active = in_active;
    assign vid_ce     = output_en ? (~href_d2 | (phase_q & href_d2)) : 1'b0;
    assign vid_data   = output_en
                      ? {px[15:11], 3'b000, px[10:5], 2'b00, px[4:0], 3'b000}
                      : 24'd0;

endmodule
