`timescale 1ns / 1ps
// ============================================================================
// video_style_bypass.v —— 输出端风格化处理模块（卡通化精简版）
//
// 只实现 style_cartoon_640x480.py 中的三个逐像素算子（按参考顺序）：
//
//     1) gamma 提亮         ：256x8 查找表（$readmemh 加载 gamma_lut.mem）
//     2) 饱和度混合          ：out = luma + sat*(rgb - luma)，sat 为 Q8 定点
//     3) 色彩量化 (posterize)：屏蔽低位 + Bayer 有序抖动（消除暗部色带 banding）
//
// 这是纯点运算（无行缓存、无全图统计、无反馈），因此用一条 4 级流水线即可：
//
//     d0 (输入寄存) -> [gamma LUT] -> g0 -> [luma] -> {g1, ly}
//                       -> [饱和度 + 量化] -> d3 (输出寄存)
//
//   latency = 4 个时钟周期。valid / SOF(TUSER) / EOL(TLAST) 用同一深度的移位
//   寄存器同步延迟，保证 AXI4-Stream 时序一致；背压安全（下游 ready 才移位）。
//
// 数据格式：24-bit RGB888（与 color_convert/stream_out_24 -> v_axi4s_vid_out
//   完全一致）。三个通道用同一张 gamma 表、同一套系数。
//
// 参数（在 BD 里以 module 参数固定，无需 AXI 配置口）：
//   ENABLE        = 1      1 = 风格化，0 = 直通（同样 4 周期延迟）
//   GAMMA         = 45     gamma x100（仅作注释；实际曲线由 gamma_lut.mem 决定）
//   SAT_Q8        = 256    饱和度 Q8（256 = 1.0 不额外拉伸；320 = 1.25；384 = 1.5）
//   POSTER_LEVELS = 16     量化级数（2 的幂：4 / 8 / 16 / 32）
// ============================================================================
module video_style_bypass #(
    parameter integer ENABLE        = 1,    // 总开关
    parameter integer GAMMA         = 45,   // gamma x100（与 gamma_lut.mem 对应）
    parameter integer SAT_Q8        = 256,  // 饱和度 Q8
    parameter integer POSTER_LEVELS = 16    // 量化级数（2 的幂）
)(
    input  wire        aclk,
    input  wire        aresetn,      // active-low reset
    input  wire        bypass,       // 运行期旁路：1 = 直通（gamma/饱和度/量化 全不做）

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

    localparam integer LATENCY = 4;
    localparam integer SAT     = SAT_Q8;

    // ------------------------------------------------------------------
    // 运行期旁路（按键切换用）：bypass 来自 100 MHz 域的 camera_in，
    // 这里在 142 MHz 域做 2 级同步。旁路时输出走 raw3（同样的 4 拍延迟），
    // 所以切换不会造成拍数错位。
    // ------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg bp_meta;   // 跨时钟域同步器（100MHz -> 142MHz）
    (* ASYNC_REG = "TRUE" *) reg bp_sync;
    always @(posedge aclk) begin
        if (!aresetn) begin
            bp_meta <= 1'b0;
            bp_sync <= 1'b0;
        end else begin
            bp_meta <= bypass;
            bp_sync <= bp_meta;
        end
    end

    // 1 = 做风格化；0 = 直通
    wire sel_proc = (ENABLE != 0) && (!bp_sync);

    // 量化掩码：levels=16 -> 0xF0, 8 -> 0xE0, 4 -> 0xC0, 32 -> 0xE0
    localparam [7:0] PMASK = 8'hFF & (~(POSTER_LEVELS - 1));

    // 抖动量化：DITHER_EN=1 用 Bayer 有序抖动消除暗部色带；=0 退化为原纯屏蔽低位。
    localparam integer DITHER_EN = 1;
    localparam [7:0]  Q_STEP    = 256 / POSTER_LEVELS;   // 量化步长（2 的幂）

    // ------------------------------------------------------------------
    // gamma 查找表（256x8）。gamma_lut.mem 必须与本文件同目录并被加入工程。
    // 由 gen_gamma_lut.py 生成（GAMMA=45 -> gamma 0.45）。
    // ------------------------------------------------------------------
    reg [7:0] g_lut [0:255];
    initial begin
        $readmemh("gamma_lut.mem", g_lut);
    end

    // ------------------------------------------------------------------
    // 背压：本模块固定 4 拍延迟、永远能吸收 1 拍，因此 ready 直通。
    // 整条流水线（数据 + 标志）只在 shift 时前进一步 —— 与 video_delay_mux
    // 相同，可正确处理流内的气泡（TVALID=0）。
    // ------------------------------------------------------------------
    wire shift = m_axis_tready;
    assign s_axis_tready = m_axis_tready;

    // ================= 流水线寄存器（数据 + 标志） =================
    reg [23:0] d0;                      // stage 0：原始输入
    reg        v0, l0, u0;

    reg [7:0]  g0r, g0g, g0b;           // stage 1：gamma 后的 RGB
    reg        v1, l1, u1;

    reg [7:0]  g1r, g1g, g1b, ly;       // stage 2：gamma RGB + 亮度
    reg        v2, l2, u2;

    reg [23:0] d3;                      // stage 3：最终输出
    reg        v3, l3, u3;

    // 直通（ENABLE=0）用的原始数据延迟链
    reg [23:0] raw1, raw2, raw3;

    // ---- 像素坐标（mod 8）与 Bayer 抖动 ----
    reg [2:0] dcol, drow;                 // 输入像素坐标 mod 8
    reg [2:0] dx0, dx1, dx2, dx3;         // 列坐标延迟 4 拍（与数据流水线对齐）
    reg [2:0] dy0, dy1, dy2, dy3;         // 行坐标延迟 4 拍

    // Bayer 8x8 有序抖动矩阵（0..63）。bayer8(x=列, y=行)。
    function [5:0] bayer8;
        input [2:0] x;
        input [2:0] y;
        case (y)
            3'd0: case (x)
                3'd0: bayer8 = 6'd0;  3'd1: bayer8 = 6'd32; 3'd2: bayer8 = 6'd8;
                3'd3: bayer8 = 6'd40; 3'd4: bayer8 = 6'd2;  3'd5: bayer8 = 6'd34;
                3'd6: bayer8 = 6'd10; 3'd7: bayer8 = 6'd42;
            endcase
            3'd1: case (x)
                3'd0: bayer8 = 6'd48; 3'd1: bayer8 = 6'd16; 3'd2: bayer8 = 6'd56;
                3'd3: bayer8 = 6'd24; 3'd4: bayer8 = 6'd50; 3'd5: bayer8 = 6'd18;
                3'd6: bayer8 = 6'd58; 3'd7: bayer8 = 6'd26;
            endcase
            3'd2: case (x)
                3'd0: bayer8 = 6'd12; 3'd1: bayer8 = 6'd44; 3'd2: bayer8 = 6'd4;
                3'd3: bayer8 = 6'd36; 3'd4: bayer8 = 6'd14; 3'd5: bayer8 = 6'd46;
                3'd6: bayer8 = 6'd6;  3'd7: bayer8 = 6'd38;
            endcase
            3'd3: case (x)
                3'd0: bayer8 = 6'd60; 3'd1: bayer8 = 6'd28; 3'd2: bayer8 = 6'd52;
                3'd3: bayer8 = 6'd20; 3'd4: bayer8 = 6'd62; 3'd5: bayer8 = 6'd30;
                3'd6: bayer8 = 6'd54; 3'd7: bayer8 = 6'd22;
            endcase
            3'd4: case (x)
                3'd0: bayer8 = 6'd3;  3'd1: bayer8 = 6'd35; 3'd2: bayer8 = 6'd11;
                3'd3: bayer8 = 6'd43; 3'd4: bayer8 = 6'd1;  3'd5: bayer8 = 6'd33;
                3'd6: bayer8 = 6'd9;  3'd7: bayer8 = 6'd41;
            endcase
            3'd5: case (x)
                3'd0: bayer8 = 6'd51; 3'd1: bayer8 = 6'd19; 3'd2: bayer8 = 6'd59;
                3'd3: bayer8 = 6'd27; 3'd4: bayer8 = 6'd49; 3'd5: bayer8 = 6'd17;
                3'd6: bayer8 = 6'd57; 3'd7: bayer8 = 6'd25;
            endcase
            3'd6: case (x)
                3'd0: bayer8 = 6'd15; 3'd1: bayer8 = 6'd47; 3'd2: bayer8 = 6'd7;
                3'd3: bayer8 = 6'd39; 3'd4: bayer8 = 6'd13; 3'd5: bayer8 = 6'd45;
                3'd6: bayer8 = 6'd5;  3'd7: bayer8 = 6'd37;
            endcase
            default: case (x)
                3'd0: bayer8 = 6'd63; 3'd1: bayer8 = 6'd31; 3'd2: bayer8 = 6'd55;
                3'd3: bayer8 = 6'd23; 3'd4: bayer8 = 6'd61; 3'd5: bayer8 = 6'd29;
                3'd6: bayer8 = 6'd53; 3'd7: bayer8 = 6'd21;
            endcase
        endcase
    endfunction

    // ================= 组合逻辑：gamma LUT 读（3 端口） =================
    wire [7:0] gl_r = g_lut[d0[23:16]];
    wire [7:0] gl_g = g_lut[d0[15: 8]];
    wire [7:0] gl_b = g_lut[d0[ 7: 0]];

    // ================= 组合逻辑：亮度（Q8 系数，与参考一致） =================
    //   ly = (77*R + 150*G + 29*B) >> 8
    wire [16:0] luma_sum = (16'd77 * g0r) + (16'd150 * g0g) + (16'd29 * g0b);
    wire [7:0]  luma     = luma_sum[15:8];

    // ================= 组合逻辑：饱和度混合（Q8 定点） =================
    //   diff = rgb - ly   (signed)
    //   out  = ly + (SAT * diff) >> 8   ，再饱和截断到 [0,255]
    wire signed [8:0] dr = $signed({1'b0, g1r}) - $signed({1'b0, ly});
    wire signed [8:0] dg = $signed({1'b0, g1g}) - $signed({1'b0, ly});
    wire signed [8:0] db = $signed({1'b0, g1b}) - $signed({1'b0, ly});

    wire signed [17:0] pr = $signed(SAT) * dr;
    wire signed [17:0] pg = $signed(SAT) * dg;
    wire signed [17:0] pb = $signed(SAT) * db;

    wire signed [9:0] sr = pr >>> 8;
    wire signed [9:0] sg = pg >>> 8;
    wire signed [9:0] sb = pb >>> 8;

    // 先把两个操作数都符号扩展到 11 位再相加，避免 10 位加法溢出
    wire signed [10:0] ly_11 = $signed({1'b0, ly});   // 0..255
    wire signed [10:0] sr_11 = sr;                    // 符号扩展 10 -> 11
    wire signed [10:0] sg_11 = sg;
    wire signed [10:0] sb_11 = sb;

    wire signed [10:0] or_r = ly_11 + sr_11;
    wire signed [10:0] or_g = ly_11 + sg_11;
    wire signed [10:0] or_b = ly_11 + sb_11;

    wire [7:0] cr = (or_r < 0) ? 8'd0 : ((or_r > 255) ? 8'd255 : or_r[7:0]);
    wire [7:0] cg = (or_g < 0) ? 8'd0 : ((or_g > 255) ? 8'd255 : or_g[7:0]);
    wire [7:0] cb = (or_b < 0) ? 8'd0 : ((or_b > 255) ? 8'd255 : or_b[7:0]);

    // ================= 组合逻辑：色彩量化（屏蔽低位 + Bayer 有序抖动） =================
    // 把 cr 加一个与像素位置相关的 [0, Q_STEP) 抖动量再截断，使 8x8 邻域内
    // 输出电平的均值 = 原值，从而把暗部渐变的 banding 转成不可见的细噪声。
    wire [5:0]  bayer_val   = bayer8(dx3, dy3);
    wire [12:0] dith_scaled = bayer_val * Q_STEP;      // 6-bit x 步长，值 <= 63*64
    wire [6:0]  dith        = dith_scaled[12:6];       // >> 6 -> [0, Q_STEP-1]

    wire [8:0] qsum_r = {1'b0, cr} + {2'b0, dith};
    wire [8:0] qsum_g = {1'b0, cg} + {2'b0, dith};
    wire [8:0] qsum_b = {1'b0, cb} + {2'b0, dith};
    wire [7:0] qclip_r = qsum_r[8] ? 8'hFF : qsum_r[7:0];
    wire [7:0] qclip_g = qsum_g[8] ? 8'hFF : qsum_g[7:0];
    wire [7:0] qclip_b = qsum_b[8] ? 8'hFF : qsum_b[7:0];

    wire [7:0] out_r = DITHER_EN ? (qclip_r & PMASK) : (cr & PMASK);
    wire [7:0] out_g = DITHER_EN ? (qclip_g & PMASK) : (cg & PMASK);
    wire [7:0] out_b = DITHER_EN ? (qclip_b & PMASK) : (cb & PMASK);

    // ================= 像素坐标计数器（mod 8，Bayer 抖动用） =================
    // 与数据同拍推进、逐帧复位，保证抖动图案逐帧一致（图案相位偏移不影响效果）。
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            dcol <= 3'd0;
            drow <= 3'd0;
        end else if (shift && s_axis_tvalid) begin
            if (s_axis_tuser[0])   begin dcol <= 3'd1; drow <= 3'd0; end       // SOF: 下一像素 col=1
            else if (s_axis_tlast) begin dcol <= 3'd0; drow <= drow + 1'b1; end // EOL
            else                   dcol <= dcol + 1'b1;
        end
    end

    // ================= 流水线推进 =================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            d0 <= 24'd0; v0 <= 1'b0; l0 <= 1'b0; u0 <= 1'b0;
            {g0r, g0g, g0b} <= 24'd0; v1 <= 1'b0; l1 <= 1'b0; u1 <= 1'b0;
            {g1r, g1g, g1b, ly} <= 32'd0; v2 <= 1'b0; l2 <= 1'b0; u2 <= 1'b0;
            d3 <= 24'd0; v3 <= 1'b0; l3 <= 1'b0; u3 <= 1'b0;
            raw1 <= 24'd0; raw2 <= 24'd0; raw3 <= 24'd0;
            dx0 <= 3'd0; dx1 <= 3'd0; dx2 <= 3'd0; dx3 <= 3'd0;
            dy0 <= 3'd0; dy1 <= 3'd0; dy2 <= 3'd0; dy3 <= 3'd0;
        end else if (shift) begin
            // stage 0
            d0 <= s_axis_tdata;
            v0 <= s_axis_tvalid;
            l0 <= s_axis_tlast;
            u0 <= s_axis_tuser[0];

            // stage 1（gamma 结果来自 d0 的组合读）
            {g0r, g0g, g0b} <= {gl_r, gl_g, gl_b};
            v1 <= v0; l1 <= l0; u1 <= u0;

            // stage 2（gamma RGB 顺延一拍 + 亮度）
            {g1r, g1g, g1b} <= {g0r, g0g, g0b};
            ly              <= luma;
            v2 <= v1; l2 <= l1; u2 <= u1;

            // stage 3（饱和度 + 量化结果）
            d3 <= {out_r, out_g, out_b};
            v3 <= v2; l3 <= l2; u3 <= u2;

            // 直通原始数据延迟链
            raw1 <= d0;
            raw2 <= raw1;
            raw3 <= raw2;

            // 坐标延迟链（与数据同拍，供输出级 Bayer 抖动）
            dx0 <= dcol; dy0 <= drow;
            dx1 <= dx0;  dy1 <= dy0;
            dx2 <= dx1;  dy2 <= dy1;
            dx3 <= dx2;  dy3 <= dy2;
        end
    end

    // ================= 输出 =================
    // sel_proc=1 走风格化结果 d3；=0 走同样 4 拍延迟的原始数据 raw3（直通）
    assign m_axis_tdata  = sel_proc ? d3 : raw3;
    assign m_axis_tvalid = v3;
    assign m_axis_tlast  = l3;
    assign m_axis_tuser  = u3;
    assign m_axis_tkeep  = 3'b111;
    assign m_axis_tstrb  = 3'b111;

endmodule
