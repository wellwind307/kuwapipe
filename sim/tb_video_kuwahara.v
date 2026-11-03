`timescale 1ns / 1ps
// ============================================================================
// tb_video_kuwahara.v —— video_kuwahara 自校验 testbench
//
// 两种编译配置（xvlog 加 -d TB_FULL 切换）：
//   默认       : 64x48 小图，2 帧，行间 12 拍消隐（快速回归）
//   TB_FULL    : 640x480 全尺寸，1 帧，完全密集流（最接近硬件里 HLS 中值输
//                出的形态；向量由 verify_kuwahara.py --tb-full 生成）
//
// 做法：
//   * 从 hex 读入 W x H 的 RGB 输入与 RTL 整数模型的期望输出（逐位）
//   * 用真正的 AXI4-Stream Master 方式驱动（遵守 tready）
//   * 下游 m_axis_tready 随机 1/8 概率拉低，验证反压不丢拍/不重发
//   * 逐像素比对 TDATA，并检查 TVALID/TLAST/TUSER 的位置与拍数
//
// 期望结果：captured = NFRAMES*W*H，mismatch = 0，extra = 0，flag_err = 0
// ============================================================================
module tb_video_kuwahara;

`ifdef TB_FULL
    // 上游（HLS 中值）真实几何：800x480，完全密集流
    localparam integer W       = 800;
    localparam integer H       = 480;
    localparam integer NFRAMES = 1;
    localparam integer GAP     = 0;
    localparam integer VGAP    = 6000;
    `define TB_IN  "tb_full_in.hex"
    `define TB_EXP "tb_full_exp.hex"
`else
    localparam integer W       = 64;
    localparam integer H       = 48;
    localparam integer NFRAMES = 2;
    localparam integer GAP     = 12;
    localparam integer VGAP    = 400;
    `define TB_IN  "tb_kw_in.hex"
    `define TB_EXP "tb_kw_exp.hex"
`endif

    localparam integer NPIX = W * H;
    localparam integer NTOT = NFRAMES * NPIX;
    localparam integer DBG  = 0;        // 1 = 打印前 80 个输出拍

    reg aclk    = 1'b0;
    reg aresetn = 1'b0;
    always #5 aclk = ~aclk;                 // 100 MHz

    reg [23:0] in_mem  [0:NPIX-1];
    reg [23:0] exp_mem [0:NPIX-1];

    // ---------------- DUT 连线 ----------------
    wire        s_tready;
    reg  [23:0] s_tdata;
    reg         s_tlast;
    reg         s_tuser;
    reg         s_tvalid;
    wire [23:0] m_tdata;
    wire [2:0]  m_tkeep, m_tstrb;
    wire        m_tlast, m_tvalid;
    wire [0:0]  m_tuser;
    reg         m_tready;

    video_kuwahara #(.W(W), .H(H)) dut (
        .aclk        (aclk),
        .aresetn     (aresetn),
        .s_axis_tdata(s_tdata),
        .s_axis_tkeep(3'b111),
        .s_axis_tstrb(3'b111),
        .s_axis_tlast(s_tlast),
        .s_axis_tuser(s_tuser),
        .s_axis_tvalid(s_tvalid),
        .s_axis_tready(s_tready),
        .m_axis_tdata(m_tdata),
        .m_axis_tkeep(m_tkeep),
        .m_axis_tstrb(m_tstrb),
        .m_axis_tlast(m_tlast),
        .m_axis_tuser(m_tuser),
        .m_axis_tvalid(m_tvalid),
        .m_axis_tready(m_tready)
    );

    // ---------------- 输入驱动（遵守 tready）----------------
    integer in_idx;            // 累计已发像素
    integer gap;
    integer pix;               // 当前帧内像素序号

    wire in_transfer = s_tvalid && s_tready;

    always @(*) begin
        pix      = (in_idx >= NTOT) ? 0 : (in_idx % NPIX);
        s_tvalid = (in_idx <  NTOT) && (gap == 0);
        s_tdata  = in_mem[pix];
        s_tlast  = ((pix % W) == (W - 1));
        s_tuser  = (pix == 0);
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            in_idx <= 0;
            gap    <= 0;
        end else if (in_transfer) begin
            in_idx <= in_idx + 1;
            if ((pix % W) == (W - 1)) begin
                if (pix == NPIX - 1) gap <= VGAP;   // 帧尾 -> 垂直消隐
                else                 gap <= GAP;    // 行尾 -> 水平消隐
            end
        end else if (gap > 0) begin
            gap <= gap - 1;
        end
    end

    // ---------------- 下游随机反压 ----------------
    integer rnd;
    always @(posedge aclk) begin
        if (!aresetn) m_tready <= 1'b1;
        else begin
            rnd = $random;
            m_tready <= ((rnd % 8) != 0);       // 1/8 概率拉低
        end
    end

    // ---------------- 输出检查 ----------------
    integer out_idx;
    integer extra_cnt;
    integer mism_cnt;
    integer flag_cnt;

    wire [23:0] exp_now = exp_mem[out_idx % NPIX];

    always @(posedge aclk) begin
        if (aresetn && m_tvalid && m_tready) begin
            if (out_idx < NTOT) begin
                if (m_tdata !== exp_now) begin
                    mism_cnt <= mism_cnt + 1;
                    if (mism_cnt < 12)
                        $display("MISMATCH idx=%0d (f=%0d y=%0d x=%0d) got %02X%02X%02X exp %02X%02X%02X",
                                 out_idx, out_idx / NPIX,
                                 (out_idx % NPIX) / W, (out_idx % NPIX) % W,
                                 m_tdata[23:16], m_tdata[15:8], m_tdata[7:0],
                                 exp_now[23:16], exp_now[15:8], exp_now[7:0]);
                end
                if (m_tlast !== (((out_idx % NPIX) % W) == (W - 1)))
                    flag_cnt <= flag_cnt + 1;
                if (m_tuser[0] !== ((out_idx % NPIX) == 0))
                    flag_cnt <= flag_cnt + 1;
            end else begin
                extra_cnt <= extra_cnt + 1;
            end
            out_idx <= out_idx + 1;
        end
    end

    // ---------------- 调试打印 ----------------
    always @(posedge aclk) begin
        if (DBG && aresetn && m_tvalid && m_tready && out_idx < 80)
            $display("OUT idx=%0d data=%06X last=%b | core row=%0d col=%0d",
                     out_idx, m_tdata, m_tlast, dut.u_core.row, dut.u_core.col);
    end

    // ---------------- 主流程 ----------------
    integer wait_cnt;
    initial begin
        in_idx    = 0;
        gap       = 0;
        out_idx   = 0;
        extra_cnt = 0;
        mism_cnt  = 0;
        flag_cnt  = 0;
        m_tready  = 1'b1;

        $readmemh(`TB_IN,  in_mem);
        $readmemh(`TB_EXP, exp_mem);

        aresetn = 1'b0;
        #100;
        aresetn = 1'b1;

        wait_cnt = 0;
        while ((out_idx < NTOT) && (wait_cnt < 2000000)) begin
            @(posedge aclk);
            wait_cnt = wait_cnt + 1;
        end
        repeat (300) @(posedge aclk);

        $display("------------------------------------------------------------");
        $display("tb_video_kuwahara  W=%0d H=%0d  grid=%0d x %0d  frames=%0d  GAP=%0d VGAP=%0d",
                 W, H, H + 3, W + 8, NFRAMES, GAP, VGAP);
        $display("captured=%0d / %0d   mismatch=%0d   extra=%0d   flag_err=%0d",
                 out_idx, NTOT, mism_cnt, extra_cnt, flag_cnt);
        if (out_idx == NTOT && mism_cnt == 0 && extra_cnt == 0 && flag_cnt == 0)
            $display("=== PASS ===");
        else
            $display("=== FAIL ===");
        $display("------------------------------------------------------------");
        $finish;
    end

endmodule
