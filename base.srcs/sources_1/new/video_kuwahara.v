`timescale 1ns / 1ps
// ============================================================================
// video_kuwahara.v —— Kuwahara 保边平滑(r=3) 的 AXI4-Stream 封装
//
// 位置：/video/camera_in 内，24-bit RGB888 的 AXI4-Stream 上，串在
//       中值滤波(median_blur_color_0)之后、pixel_pack 之前：
//
//   median_blur_color_0/video_out ──► video_kuwahara_0/s_axis
//   video_kuwahara_0/m_axis       ──► pixel_pack/stream_in_24
//
// 算法 = style_cartoon_640x480.py 的第 3 步（_kuwahara）：
//   7x7 窗口 / 4 个 4x4 象限 / 取亮度方差最小的象限 / 输出该象限 RGB 均值。
//   亮度 Y=77R+150G+29B (Q8)，判别式 disc=16*sum(Y^2)-sum(Y)^2，
//   均值 round-half-even —— 与参考逐位一致（边界除外）。
//   白平衡那一步在参考里是固定 Q8=256（=1.0），恒等，所以这里不需要。
//
// 流接口特性
//   * 每拍 1 像素，输出 = 输入逐像素对应（H*W 个像素，SOF/EOL 自己生成）
//   * 背压安全：全局推进 + 输出侧一级 skid 寄存器，反压/输入气泡都不丢不重
//   * 帧延迟：约 3*(W+8)+3+5 拍
//
// ============================================================================
// 参数 W / H 必须等于【上游实际输出的每行像素数 / 每帧行数】，不是 PYNQ 里的
// VideoMode！本工程里 HLS 中值 IP 的行列循环是**硬编码常量**：
//     median_blur_color_..._xfMat2AXIvideo_..._Pipeline_loop_col_mat2axi.v
//         icmp_ln204_fu_132_p2 = (j == 10'd800)   <-- 每行固定 800 像素
//     xFMedianNxN / Mat 模板                                    <-- 每帧 480 行
// 即中值输出固定 800x480，和 PYNQ 的 VideoMode(640,480) 无关
// （VideoMode 只写 VDMA/VTC，不会写中值 IP 的 rows/cols 寄存器）。
// 所以这里默认 W=800 / H=480。若行宽改错（例如按 640 算），行缓存的行对齐会
// 每行滑 160 像素，画面就会出现 ~4 重错位重影。
//
// 依赖（同目录，必须一起加入工程）：
//   kuwahara.v  linebuf.v  box4col.v  luma_q8.v
// ============================================================================
module video_kuwahara #(
    parameter integer W = 800,   // 上游每行像素数（本工程中值输出 = 800）
    parameter integer H = 480    // 每帧行数（= 480）
)(
    input  wire        aclk,
    input  wire        aresetn,      // active-low reset

    // ---- AXI4-Stream slave (input), 24-bit RGB ----
    input  wire [23:0] s_axis_tdata,
    input  wire [2:0]  s_axis_tkeep,
    input  wire [2:0]  s_axis_tstrb,
    input  wire        s_axis_tlast,
    input  wire [0:0]  s_axis_tuser, // SOF
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // ---- AXI4-Stream master (output), 24-bit RGB ----
    output wire [23:0] m_axis_tdata,
    output wire [2:0]  m_axis_tkeep,
    output wire [2:0]  m_axis_tstrb,
    output wire        m_axis_tlast,
    output wire [0:0]  m_axis_tuser,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);

    wire        kw_ready;
    wire        kw_valid;
    wire [23:0] kw_data;
    wire        kw_last;
    wire        kw_sof;

    kuwahara #(.W(W), .H(H)) u_core (
        .clk    (aclk),
        .rstn   (aresetn),
        .i_valid(s_axis_tvalid),
        .i_data (s_axis_tdata),
        .i_sof  (s_axis_tuser[0]),
        .m_ready(m_axis_tready),
        .i_ready(kw_ready),
        .o_valid(kw_valid),
        .o_data (kw_data),
        .o_last (kw_last),
        .o_sof  (kw_sof)
    );

    assign s_axis_tready = kw_ready;

    // 输出是寄存器输出（core 内有一级 skid 寄存器），反压安全
    assign m_axis_tdata  = kw_data;
    assign m_axis_tvalid = kw_valid;
    assign m_axis_tlast  = kw_last;
    assign m_axis_tuser  = kw_sof;
    assign m_axis_tkeep  = 3'b111;
    assign m_axis_tstrb  = 3'b111;

endmodule
