`timescale 1ns / 1ps
// ============================================================================
// video_median_color.v - per-channel (RGB) 3x3 median filter.
//
// Follows the framework of the HLS ov5640_medianBlur IP (AXI-Stream reader ->
// line buffers -> 3x3 window -> 9-point median -> AXI-Stream writer), but
// operates on all 3 channels independently (color median) instead of grayscale.
//
//   * 2 line buffers (shift registers, W deep x 24 bit) form the 3 rows
//   * 2 column taps form the 3 columns -> 3x3 window
//   * border = edge replication (np.pad 'edge')
//   * per-channel 9-point median via median9 (5-stage pipeline)
//   * valid / SOF / EOL are delayed through a clock-cycle shift register so
//     vertical blanking propagates to the output correctly.
//
// Frame format: W pixels per line, H lines per frame; TUSER = SOF (first
// pixel of frame), TLAST = EOL (last pixel of line). Stream is dense within a
// frame (no bubbles between pixels); bubbles only between frames.
// ============================================================================
module video_median_color #(
    parameter integer W = 800,   // pixels per line
    parameter integer H = 480    // lines per frame
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

    // ------------------------------------------------------------------
    // latency budget (valid pixels):
    //   line buffer lb1[W-1]   : W-1
    //   column tap m1          : 1
    //   median9 sort pipeline  : 4
    //   -------------------------------
    //   total                  : W + 4
    // ------------------------------------------------------------------
    localparam integer LATENCY = W + 4;

    wire i_valid = s_axis_tvalid;
    wire [23:0] i_data = s_axis_tdata;
    wire i_last  = s_axis_tlast;
    wire i_sof   = s_axis_tuser[0];

    wire shift = m_axis_tready;
    assign s_axis_tready = shift;

    // pipeline advances only on a real valid pixel AND downstream ready
    wire adv = shift && i_valid;

    // ================= row / col counters (input position) =================
    reg [$clog2(H):0] irow;
    reg [$clog2(W):0] icol;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            irow <= 0;
            icol <= 0;
        end else if (adv) begin
            if (i_sof) begin
                irow <= 0;
                icol <= 1;
            end else if (i_last) begin
                irow <= irow + 1;
                icol <= 0;
            end else begin
                icol <= icol + 1;
            end
        end
    end

    // ================= line buffers (W deep x 24 bit) =================
    reg [23:0] lb1 [0:W-1];
    reg [23:0] lb2 [0:W-1];
    integer k;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (k = 0; k < W; k = k + 1) begin
                lb1[k] <= 24'd0;
                lb2[k] <= 24'd0;
            end
        end else if (adv) begin
            lb1[0] <= i_data;
            for (k = 1; k < W; k = k + 1) lb1[k] <= lb1[k-1];
            lb2[0] <= lb1[W-1];
            for (k = 1; k < W; k = k + 1) lb2[k] <= lb2[k-1];
        end
    end

    // ================= column taps =================
    reg [23:0] b1, b2, m1, m2, t1, t2;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            b1 <= 24'd0; b2 <= 24'd0;
            m1 <= 24'd0; m2 <= 24'd0;
            t1 <= 24'd0; t2 <= 24'd0;
        end else if (adv) begin
            b1 <= i_data;   b2 <= b1;
            m1 <= lb1[W-1]; m2 <= m1;
            t1 <= lb2[W-1]; t2 <= t1;
        end
    end

    wire [23:0] b0 = i_data;
    wire [23:0] m0 = lb1[W-1];
    wire [23:0] t0 = lb2[W-1];

    // ================= edge flags (window center = m1 = (irow-1, icol-1)) =================
    wire left_edge   = (icol == 1);
    wire right_edge  = (icol == 0);
    wire top_edge    = ((irow == 1) && (icol >= 1)) || ((irow == 2) && (icol == 0));
    wire bottom_edge = ((irow == 0) && (icol >= 1)) || ((irow == 1) && (icol == 0));

    // vertical replication
    wire [23:0] et0 = top_edge    ? m0 : t0;
    wire [23:0] et1 = top_edge    ? m1 : t1;
    wire [23:0] et2 = top_edge    ? m2 : t2;
    wire [23:0] em0 = m0;
    wire [23:0] em1 = m1;
    wire [23:0] em2 = m2;
    wire [23:0] eb0 = bottom_edge ? m0 : b0;
    wire [23:0] eb1 = bottom_edge ? m1 : b1;
    wire [23:0] eb2 = bottom_edge ? m2 : b2;

    // horizontal replication -> 3x3 window
    wire [23:0] w00 = left_edge  ? et1 : et2;
    wire [23:0] w01 = et1;
    wire [23:0] w02 = right_edge ? et1 : et0;
    wire [23:0] w10 = left_edge  ? em1 : em2;
    wire [23:0] w11 = em1;
    wire [23:0] w12 = right_edge ? em1 : em0;
    wire [23:0] w20 = left_edge  ? eb1 : eb2;
    wire [23:0] w21 = eb1;
    wire [23:0] w22 = right_edge ? eb1 : eb0;

    // ================= per-channel median (3x median9) =================
    wire [7:0] med_r, med_g, med_b;
    median9 m9r (
        .clk(aclk), .rstn(aresetn), .en(adv),
        .din({ w22[23:16], w21[23:16], w20[23:16],
               w12[23:16], w11[23:16], w10[23:16],
               w02[23:16], w01[23:16], w00[23:16] }),
        .med(med_r)
    );
    median9 m9g (
        .clk(aclk), .rstn(aresetn), .en(adv),
        .din({ w22[15:8], w21[15:8], w20[15:8],
               w12[15:8], w11[15:8], w10[15:8],
               w02[15:8], w01[15:8], w00[15:8] }),
        .med(med_g)
    );
    median9 m9b (
        .clk(aclk), .rstn(aresetn), .en(adv),
        .din({ w22[7:0], w21[7:0], w20[7:0],
               w12[7:0], w11[7:0], w10[7:0],
               w02[7:0], w01[7:0], w00[7:0] }),
        .med(med_b)
    );

    // ================= valid / SOF / EOL delay (clock-cycle, depth LATENCY) =================
    // advanced EVERY clock so vertical blanking propagates to the output.
    reg [0:LATENCY] valid_sr;
    reg [0:LATENCY] sof_sr;
    reg [0:LATENCY] eol_sr;
    integer v;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (v = 0; v <= LATENCY; v = v + 1) begin
                valid_sr[v] <= 1'b0;
                sof_sr[v]   <= 1'b0;
                eol_sr[v]   <= 1'b0;
            end
        end else begin
            valid_sr[0] <= i_valid;
            sof_sr[0]   <= i_sof;
            eol_sr[0]   <= i_last;
            for (v = 1; v <= LATENCY; v = v + 1) begin
                valid_sr[v] <= valid_sr[v-1];
                sof_sr[v]   <= sof_sr[v-1];
                eol_sr[v]   <= eol_sr[v-1];
            end
        end
    end

    // ================= output =================
    assign m_axis_tdata  = {med_r, med_g, med_b};
    assign m_axis_tvalid = valid_sr[LATENCY];
    assign m_axis_tlast  = eol_sr[LATENCY];
    assign m_axis_tuser  = sof_sr[LATENCY];
    assign m_axis_tkeep  = 3'b111;
    assign m_axis_tstrb  = 3'b111;

endmodule
