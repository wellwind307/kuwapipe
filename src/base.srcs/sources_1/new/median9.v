`timescale 1ns / 1ps
// ============================================================================
// median9.v - 9-point median (single 8-bit channel).
//
// Odd-even transposition sorting network, 9 passes, registered after every
// 2 passes -> 4 register stages + 1 final combinational pass. Critical path
// per stage is only 2 compare-swap levels, so it meets 100 MHz comfortably.
// After 9 passes the 9 values are fully sorted ascending; median = element 4.
//
// din is packed {d8,d7,d6,d5,d4,d3,d2,d1,d0} (72 bits).
// ============================================================================
module median9 (
    input  wire        clk,
    input  wire        rstn,    // active-low reset
    input  wire        en,      // advance (valid pixel)
    input  wire [71:0] din,
    output wire [7:0]  med
);

    // ---- one odd-even pass (compare-swap adjacent pairs) ----
    // par = 0 : even pairs (0,1)(2,3)(4,5)(6,7)
    // par = 1 : odd  pairs (1,2)(3,4)(5,6)(7,8)
    function [71:0] sort_pass;
        input [71:0] d;
        input        par;
        reg [7:0] v [0:8];
        reg [7:0] t;
        integer i;
        begin
            for (i = 0; i < 9; i = i + 1) v[i] = d[i*8 +: 8];
            if (par == 1'b0) begin
                for (i = 0; i < 8; i = i + 2) begin
                    if (v[i] > v[i+1]) begin t = v[i]; v[i] = v[i+1]; v[i+1] = t; end
                end
            end else begin
                for (i = 1; i < 8; i = i + 2) begin
                    if (v[i] > v[i+1]) begin t = v[i]; v[i] = v[i+1]; v[i+1] = t; end
                end
            end
            sort_pass = {v[8], v[7], v[6], v[5], v[4], v[3], v[2], v[1], v[0]};
        end
    endfunction

    // ---- stage 1: passes 0-1 (combinational) -> register ----
    wire [71:0] s1 = sort_pass(sort_pass(din, 1'b0), 1'b1);
    reg  [71:0] r1;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) r1 <= 72'd0; else if (en) r1 <= s1;
    end

    // ---- stage 2: passes 2-3 -> register ----
    wire [71:0] s2 = sort_pass(sort_pass(r1, 1'b0), 1'b1);
    reg  [71:0] r2;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) r2 <= 72'd0; else if (en) r2 <= s2;
    end

    // ---- stage 3: passes 4-5 -> register ----
    wire [71:0] s3 = sort_pass(sort_pass(r2, 1'b0), 1'b1);
    reg  [71:0] r3;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) r3 <= 72'd0; else if (en) r3 <= s3;
    end

    // ---- stage 4: passes 6-7 -> register ----
    wire [71:0] s4 = sort_pass(sort_pass(r3, 1'b0), 1'b1);
    reg  [71:0] r4;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) r4 <= 72'd0; else if (en) r4 <= s4;
    end

    // ---- stage 5: pass 8 (combinational) -> median = element 4 ----
    wire [71:0] s5 = sort_pass(r4, 1'b0);
    assign med = s5[8*4 +: 8];

endmodule
