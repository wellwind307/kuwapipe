`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
// video_delay_mux.v
//
// 2-way selector for the camera input AXI4-Stream path (PYNQ base overlay).
//
//   sel = 0 : pass-through (combinational, 0 latency)  -> original behaviour
//   sel = 1 : pipeline delay by DELAY_CYCLES clock cycles
//
// The delayed path delays the DATA and ALL control qualifiers
// (TVALID / TLAST / TUSER / TKEEP) by exactly the same number of clock cycles so
// the stream stays coherent. The downstream VDMA therefore receives a frame that is
// bit-identical to the input, only DELAY_CYCLES cycles later -> the image still
// displays correctly.
//
// Backpressure-safe implementation:
//   * the delay line advances ONLY when the downstream accepts a beat
//     (m_axis_tready = 1), so no beat is ever dropped or duplicated;
//   * s_axis_tready = m_axis_tready;
//   * bubbles (TVALID = 0, e.g. horizontal blanking) propagate through the delay
//     line unchanged, so blanking intervals are preserved exactly.
//
// The delay line is always running (even while sel = 0), so it is kept "primed";
// switching sel 0 -> 1 produces a valid delayed stream immediately.
////////////////////////////////////////////////////////////////////////////////////
module video_delay_mux #(
    parameter integer DATA_WIDTH   = 32,   // TDATA width
    parameter integer USER_WIDTH   = 1,    // TUSER (start-of-frame) width
    parameter integer DELAY_CYCLES = 8     // pipeline depth (>= 1)
)(
    input  wire                     aclk,
    input  wire                     aresetn,   // active-low reset
    input  wire                     sel,       // 0 = pass-through, 1 = delayed

    // ---- AXI4-Stream slave (input) ----
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axis_tkeep,
    input  wire                     s_axis_tlast,
    input  wire [USER_WIDTH-1:0]    s_axis_tuser,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,

    // ---- AXI4-Stream master (output) ----
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [DATA_WIDTH/8-1:0]  m_axis_tkeep,
    output wire                     m_axis_tlast,
    output wire [USER_WIDTH-1:0]    m_axis_tuser,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready
);

    localparam integer KEEP_WIDTH = DATA_WIDTH/8;

    // ---- select synchronizer (2 FF, metastability safe) ----
    reg sel_meta, sel_sync;
    always @(posedge aclk) begin
        if (!aresetn) begin sel_meta <= 1'b0; sel_sync <= 1'b0; end
        else          begin sel_meta <= sel;   sel_sync <= sel_meta; end
    end

    // ---- delay-line advance (backpressure safe) ----
    wire shift = m_axis_tready;
    assign s_axis_tready = m_axis_tready;

    // ---- N-stage shift registers for the delayed path ----
    reg                  valid_sr [0:DELAY_CYCLES-1];
    reg [DATA_WIDTH-1:0] data_sr  [0:DELAY_CYCLES-1];
    reg [KEEP_WIDTH-1:0] keep_sr  [0:DELAY_CYCLES-1];
    reg [USER_WIDTH-1:0] user_sr  [0:DELAY_CYCLES-1];
    reg                  last_sr  [0:DELAY_CYCLES-1];

    integer i;
    always @(posedge aclk) begin
        if (!aresetn) begin
            for (i = 0; i < DELAY_CYCLES; i = i + 1) begin
                valid_sr[i] <= 1'b0;
                data_sr[i]  <= {DATA_WIDTH{1'b0}};
                keep_sr[i]  <= {KEEP_WIDTH{1'b0}};
                user_sr[i]  <= {USER_WIDTH{1'b0}};
                last_sr[i]  <= 1'b0;
            end
        end else if (shift) begin
            valid_sr[0] <= s_axis_tvalid;
            data_sr[0]  <= s_axis_tdata;
            keep_sr[0]  <= s_axis_tkeep;
            user_sr[0]  <= s_axis_tuser;
            last_sr[0]  <= s_axis_tlast;
            for (i = 1; i < DELAY_CYCLES; i = i + 1) begin
                valid_sr[i] <= valid_sr[i-1];
                data_sr[i]  <= data_sr[i-1];
                keep_sr[i]  <= keep_sr[i-1];
                user_sr[i]  <= user_sr[i-1];
                last_sr[i]  <= last_sr[i-1];
            end
        end
    end

    // ---- output mux ----
    assign m_axis_tvalid = sel_sync ? valid_sr[DELAY_CYCLES-1] : s_axis_tvalid;
    assign m_axis_tdata  = sel_sync ? data_sr[DELAY_CYCLES-1]  : s_axis_tdata;
    assign m_axis_tkeep  = sel_sync ? keep_sr[DELAY_CYCLES-1]  : s_axis_tkeep;
    assign m_axis_tuser  = sel_sync ? user_sr[DELAY_CYCLES-1]  : s_axis_tuser;
    assign m_axis_tlast  = sel_sync ? last_sr[DELAY_CYCLES-1]  : s_axis_tlast;

endmodule
