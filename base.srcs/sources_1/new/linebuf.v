`timescale 1ns / 1ps
// =============================================================================
// linebuf.v - 行缓存：对有效 beat 精确延迟 W 拍（正好一行），与当前像素对齐。
//
// 写法：环形 BRAM，写指针 wp、读指针 rp = wp + 1（"读前一拍"），正好抵消
// 寄存器读带来的 +1 拍，级联时不会有额外的列偏移。综合出来是 BRAM
// （W*(DW) 位，深度 W）。
//
// mem 的 initial 清零只在仿真/上电首帧起作用；帧边界由上层补零逻辑覆盖。
// =============================================================================
module linebuf #(
    parameter integer W  = 645,   // 每行 beat 数（行宽）
    parameter integer DW = 24     // 数据位宽
)(
    input  wire          clk,
    input  wire          rstn,     // 低有效
    input  wire          en,       // 有效 beat 时推进
    input  wire [DW-1:0] din,
    output reg  [DW-1:0] dout      // = W 拍之前的 din（上一行同列）
);
    reg [DW-1:0] mem [0:W-1];
    reg [$clog2(W)-1:0] wp, rp;

    integer i;
    initial for (i = 0; i < W; i = i + 1) mem[i] = {DW{1'b0}};

    always @(posedge clk) begin
        if (!rstn) begin
            wp   <= 0;
            rp   <= 1;
            dout <= {DW{1'b0}};
        end else if (en) begin
            mem[wp] <= din;
            dout    <= mem[rp];
            wp      <= (wp == W-1) ? 0 : wp + 1'b1;
            rp      <= (rp == W-1) ? 0 : rp + 1'b1;
        end
    end

endmodule
