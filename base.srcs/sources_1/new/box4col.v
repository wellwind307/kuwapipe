`timescale 1ns / 1ps
// =============================================================================
// box4col.v - 4 列滑动和（Kuwahara 象限的水平分解）
//     h_new = v(c) + v(c-1) + v(c-2) + v(c-3)     窗口右半边（列 x..x+3）
//     h_old = h_new 延迟 3 列                       窗口左半边（列 x-3..x）
// v 为 DW 位，h 为 DW+1 位（4 列和）。
// h_new 与 h_old 都是寄存器输出，同一拍有效，所以 4 个象限可以在同一级比较。
// =============================================================================
module box4col #(
    parameter DW = 18
)(
    input  wire          clk,
    input  wire          rstn,
    input  wire          en,
    input  wire [DW-1:0] v,
    output wire [DW+1:0] h_new,
    output wire [DW+1:0] h_old
);
    reg [DW-1:0] d1, d2, d3, d4;
    reg [DW+2:0] acc;                 // 多 1 位余量
    reg [DW+1:0] od1, od2, od3;

    always @(posedge clk) begin
        if (!rstn) begin
            d1 <= 0; d2 <= 0; d3 <= 0; d4 <= 0;
            acc <= 0;
            od1 <= 0; od2 <= 0; od3 <= 0;
        end else if (en) begin
            {d4, d3, d2, d1} <= {d3, d2, d1, v};
            acc <= acc + {3'b0, v} - {3'b0, d4};
            od1 <= acc[DW+1:0];
            od2 <= od1;
            od3 <= od2;
        end
    end

    assign h_new = acc[DW+1:0];
    assign h_old = od3;

endmodule
