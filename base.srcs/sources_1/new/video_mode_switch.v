`timescale 1ns / 1ps
// ============================================================================
// video_mode_switch.v —— 输入侧"处理 / 直通"路由开关
//
// 位置：/video/camera_in 内，串在 color_convert/axis_register_slice 之后：
//
//   axis_register_slice_0/M_AXIS ─► video_mode_switch_0/s_axis
//                                     ├─ m_proc ─► median_blur_color_0/video_in
//                                     │            median ─► kuwahara ─► s_proc
//                                     └─ 内部直通支路（打 1 拍）
//                                   m_axis ─► pixel_pack/stream_in_24
//
//   mode = 0（默认）: 全处理。s_axis → m_proc（送中值→Kuwahara），
//                     s_proc → m_axis（Kuwahara 结果出去）。
//   mode = 1        : 直通。s_axis 的像素直接（打 1 拍）送到 m_axis；
//                     中值+Kuwahara 仍在跑（m_proc 照常收数据），它们的输出
//                     在内部被丢弃（s_proc_tready=1）。
//
// 为什么直通模式下还要"喂"中值链：HLS 中值 IP 是数据流流水线，如果直接断掉
// 输入，它会停在半帧状态、再恢复时要重新等 TUSER，切换后可能黑好几帧。让它
// 一直按节拍跑（输出丢弃）切换就没有这个恢复过程，只有在切回处理模式的瞬间
// 画面会"跳"约 3~5 行（一次切换一次的瞬态，可接受）。
//
// 按键：
//   * 2 级同步 + 20 ms 消抖，按下（上升沿）切换一次 mode
//   * AUTO_POL=1（默认）：上电 100 ms 静置后记住按键"空闲电平"，之后任意
//     电平反相都能正常工作（不用管按键是低有效还是高有效）
//   * AUTO_POL=0：用 BTN_ACTIVE_LOW 参数显式指定
//   * 复位后默认 mode=0（全处理）
// ============================================================================
module video_mode_switch #(
    parameter integer CLK_HZ         = 100_000_000,
    parameter integer DEBOUNCE_MS    = 20,     // 消抖时间
    parameter integer SETTLE_MS      = 100,    // 上电静置多久后认定按键空闲电平
    parameter integer AUTO_POL       = 1,      // 1=自动判极性
    parameter integer BTN_ACTIVE_LOW = 1       // AUTO_POL=0 时：1=按下为低
)(
    input  wire        aclk,
    input  wire        aresetn,

    input  wire        btn,          // 原始按键，异步
    output wire        mode,         // 0=全处理  1=直通

    // ---- AXI4-Stream slave：来自摄像头支路 ----
    input  wire [23:0] s_axis_tdata,
    input  wire [2:0]  s_axis_tkeep,
    input  wire [2:0]  s_axis_tstrb,
    input  wire        s_axis_tlast,
    input  wire [0:0]  s_axis_tuser,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // ---- AXI4-Stream master：送中值（处理支路入口）----
    output wire [23:0] m_proc_tdata,
    output wire [2:0]  m_proc_tkeep,
    output wire [2:0]  m_proc_tstrb,
    output wire        m_proc_tlast,
    output wire [0:0]  m_proc_tuser,
    output wire        m_proc_tvalid,
    input  wire        m_proc_tready,

    // ---- AXI4-Stream slave：接 Kuwahara 输出（处理支路出口）----
    input  wire [23:0] s_proc_tdata,
    input  wire [2:0]  s_proc_tkeep,
    input  wire [2:0]  s_proc_tstrb,
    input  wire        s_proc_tlast,
    input  wire [0:0]  s_proc_tuser,
    input  wire        s_proc_tvalid,
    output wire        s_proc_tready,

    // ---- AXI4-Stream master：去 pixel_pack ----
    output wire [23:0] m_axis_tdata,
    output wire [2:0]  m_axis_tkeep,
    output wire [2:0]  m_axis_tstrb,
    output wire        m_axis_tlast,
    output wire [0:0]  m_axis_tuser,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);

    localparam integer DEB_MAX = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer SET_MAX = (CLK_HZ / 1000) * SETTLE_MS;

    // ========================================================================
    // 1. 按键：2 级同步 + 消抖
    // ========================================================================
    reg        btn_m, btn_s, btn_db;
    reg [31:0] deb_cnt;

    always @(posedge aclk) begin
        if (!aresetn) begin
            btn_m   <= 1'b1;
            btn_s   <= 1'b1;
            btn_db  <= 1'b1;
            deb_cnt <= 32'd0;
        end else begin
            btn_m <= btn;
            btn_s <= btn_m;
            if (btn_s != btn_db) begin
                if (deb_cnt >= DEB_MAX) begin
                    btn_db  <= btn_s;
                    deb_cnt <= 32'd0;
                end else begin
                    deb_cnt <= deb_cnt + 1'b1;
                end
            end else begin
                deb_cnt <= 32'd0;
            end
        end
    end

    // ========================================================================
    // 2. 上电静置 -> 记住按键空闲电平（自动判极性）
    // ========================================================================
    reg        pol_done;
    reg        idle_level;
    reg [31:0] set_cnt;

    always @(posedge aclk) begin
        if (!aresetn) begin
            pol_done   <= 1'b0;
            idle_level <= (BTN_ACTIVE_LOW != 0);
            set_cnt    <= 32'd0;
        end else if (!pol_done) begin
            if (set_cnt >= SET_MAX) begin
                idle_level <= (AUTO_POL != 0) ? btn_db : (BTN_ACTIVE_LOW != 0);
                pol_done   <= 1'b1;
            end else begin
                set_cnt <= set_cnt + 1'b1;
            end
        end
    end

    // ========================================================================
    // 3. 按下沿 -> mode 翻转
    // ========================================================================
    wire btn_active = pol_done && (btn_db != idle_level);

    reg btn_active_d;
    always @(posedge aclk) begin
        if (!aresetn) btn_active_d <= 1'b0;
        else          btn_active_d <= btn_active;
    end

    wire press = btn_active & (~btn_active_d);

    reg mode_r;
    always @(posedge aclk) begin
        if (!aresetn)    mode_r <= 1'b0;      // 默认全处理
        else if (press)  mode_r <= ~mode_r;
    end

    assign mode = mode_r;

    // ========================================================================
    // 4. 数据通路
    // ========================================================================
    // 处理支路入口：无论哪种模式都照常喂给中值（保持 HLS 流水线不断帧）
    assign m_proc_tdata  = s_axis_tdata;
    assign m_proc_tkeep  = s_axis_tkeep;
    assign m_proc_tstrb  = s_axis_tstrb;
    assign m_proc_tlast  = s_axis_tlast;
    assign m_proc_tuser  = s_axis_tuser;
    assign m_proc_tvalid = s_axis_tvalid;

    // 直通支路：1 拍寄存（skid，反压时不丢）
    reg        raw_vld;
    reg [23:0] raw_data;
    reg [2:0]  raw_keep, raw_strb;
    reg        raw_last;
    reg [0:0]  raw_user;

    wire raw_sel  = mode_r;                                   // 1 = 直通
    wire raw_free = (!raw_vld) || m_axis_tready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            raw_vld  <= 1'b0;
            raw_data <= 24'd0;
            raw_keep <= 3'b111;
            raw_strb <= 3'b111;
            raw_last <= 1'b0;
            raw_user <= 1'b0;
        end else if (raw_sel) begin
            if (raw_free && s_axis_tvalid) begin
                raw_vld  <= 1'b1;
                raw_data <= s_axis_tdata;
                raw_keep <= s_axis_tkeep;
                raw_strb <= s_axis_tstrb;
                raw_last <= s_axis_tlast;
                raw_user <= s_axis_tuser;
            end else if (m_axis_tready) begin
                raw_vld  <= 1'b0;                              // 已被取走且本级冻结 -> 清
            end
        end else begin
            raw_vld <= 1'b0;                                   // 处理模式下不使用
        end
    end

    // 入口握手：以中值为节拍源；直通模式下还要保证 raw 寄存器有空
    assign s_axis_tready = m_proc_tready && (raw_sel ? raw_free : 1'b1);

    // 处理支路出口：直通模式下一直取走并丢弃（让中值/Kuwahara 继续跑）
    assign s_proc_tready = raw_sel ? 1'b1 : m_axis_tready;

    // 输出二选一
    assign m_axis_tdata  = raw_sel ? raw_data  : s_proc_tdata;
    assign m_axis_tkeep  = raw_sel ? raw_keep  : s_proc_tkeep;
    assign m_axis_tstrb  = raw_sel ? raw_strb  : s_proc_tstrb;
    assign m_axis_tlast  = raw_sel ? raw_last  : s_proc_tlast;
    assign m_axis_tuser  = raw_sel ? raw_user  : s_proc_tuser;
    assign m_axis_tvalid = raw_sel ? raw_vld   : s_proc_tvalid;

endmodule
