`timescale 1ns / 1ps
// =============================================================================
// luma_q8.v - 亮度 Q8：luma = 77R + 150G + 29B（16 bit，低 8 位是小数）
// 与 style_cartoon_640x480.py 的 _luma_q8() 完全一致。
// rgb = {R[23:16], G[15:8], B[7:0]}。乘法强制用 DSP。
// =============================================================================
module luma_q8 (
    input  wire [23:0] rgb,
    output wire [15:0] luma
);
    (* use_dsp = "yes" *) wire [15:0] t0 = 8'd77  * rgb[23:16];
    (* use_dsp = "yes" *) wire [15:0] t1 = 8'd150 * rgb[15:8];
    (* use_dsp = "yes" *) wire [15:0] t2 = 6'd29  * rgb[7:0];

    assign luma = t0 + t1 + t2;

endmodule
