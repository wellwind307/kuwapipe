`timescale 1ns / 1ps
// ============================================================================
// tb_video_style.v —— video_style 抖动量化的自检 testbench
//
// 验证点：
//   1) 输入 8x8 恒值灰度块，输出 64 拍都落在量化级上（POSTER_LEVELS=16 -> 16 的倍数）
//   2) 8x8 邻域内输出均值 == gamma(输入值)（即抖动量化逐块无偏，消除了 banding）
// ============================================================================
module tb_video_style;

reg         aclk         = 0;
reg         aresetn      = 0;
reg  [23:0] s_axis_tdata = 0;
reg  [2:0]  s_axis_tkeep = 3'b111;
reg  [2:0]  s_axis_tstrb = 3'b111;
reg         s_axis_tlast = 0;
reg         s_axis_tuser = 0;
reg         s_axis_tvalid= 0;
reg         m_axis_tready= 1;

wire        s_axis_tready;
wire [23:0] m_axis_tdata;
wire        m_axis_tvalid;

video_style #(
    .ENABLE        (1),
    .GAMMA         (45),
    .SAT_Q8        (256),
    .POSTER_LEVELS (16)
) dut (
    .aclk         (aclk),
    .aresetn      (aresetn),
    .s_axis_tdata (s_axis_tdata),
    .s_axis_tkeep (s_axis_tkeep),
    .s_axis_tstrb (s_axis_tstrb),
    .s_axis_tlast (s_axis_tlast),
    .s_axis_tuser (s_axis_tuser),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tkeep (),
    .m_axis_tstrb (),
    .m_axis_tlast (),
    .m_axis_tuser (),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready)
);

// ---- 加载与 DUT 相同的 gamma LUT（用于计算期望值） ----
reg [7:0] lut [0:255];
initial $readmemh("gamma_lut.mem", lut);

always #5 aclk = ~aclk;   // 100 MHz

// ---- 捕获输出（R 通道） ----
reg [7:0] cap_r [0:127];
integer   cap_n = 0;
always @(posedge aclk) begin
    if (aresetn && m_axis_tvalid && cap_n < 128) begin
        cap_r[cap_n] = m_axis_tdata[23:16];
        cap_n = cap_n + 1;
    end
end

integer  row, col;
integer  i, sum, lerr;
reg [7:0] V = 8'd100;

initial begin
    aresetn = 0;
    #30;                 // 保持复位（在 negedge 释放）
    aresetn = 1;
    @(negedge aclk);     // 同步到 negedge

    // 发送 8 行 x 8 列 = 64 个恒值灰度像素
    for (row = 0; row < 8; row = row + 1) begin
        for (col = 0; col < 8; col = col + 1) begin
            s_axis_tvalid = 1'b1;
            s_axis_tdata  = {V, V, V};
            s_axis_tuser  = (row == 0 && col == 0);   // SOF
            s_axis_tlast  = (col == 7);               // EOL
            #10;          // 输入在下一个 posedge 被采样
        end
    end
    s_axis_tvalid = 1'b0;
    s_axis_tuser  = 1'b0;
    s_axis_tlast  = 1'b0;

    #300;   // 等待流水线排空

    // ---- 检查 ----
    sum = 0; lerr = 0;
    for (i = 0; i < cap_n; i = i + 1) begin
        if ((cap_r[i] & 8'h0F) != 0) lerr = lerr + 1;   // 应都是 16 的倍数
        sum = sum + cap_r[i];
    end
    $display("captured=%0d  expected_cr(gamma(%0d))=%0d  avg_R=%0d  level_errors=%0d",
             cap_n, V, lut[V], (cap_n > 0 ? sum / cap_n : -1), lerr);

    if (cap_n == 64 && lerr == 0 && sum == 64 * lut[V])
        $display("=== PASS ===");
    else
        $display("=== FAIL ===");

    $finish;
end

endmodule
