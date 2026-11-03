`timescale 1ns / 1ps
// =============================================================================
// kuwahara.v - Kuwahara 保边平滑 (r=3)：7x7 窗口，4 个 4x4 象限，取方差最小的
// 象限的 RGB 均值。整数实现，与 style_cartoon_640x480.py 的 _kuwahara 逐位一致
// （边界除外，见下）。
//
// 数学（与 Python 参考完全对应）
//     Y    = 77R + 150G + 29B            Q8 亮度，16 bit（参考里的 _luma_q8）
//     disc = 16*sum(Y^2) - sum(Y)^2      == 256 * var，恒 >= 0
//            （2^8 是正常数因子，所以 argmin(disc) == argmin(var)，
//              与参考里 float64 算出的方差排序、平局结果完全一致）
//     象限和 = (4 行竖直和) 再做 (4 列滑动和)
//     选象限：disc 最小者；平局顺序 TL > TR > BL > BR（对应参考的遍历顺序
//              [(0,0),(0,r),(r,0),(r,r)] + 严格小于比较）
//     输出均值：round-half-even（对应 np.round 的银行家舍入，参考逐位一致）
//
// 窗口几何（r=3）
//     输出像素 (y,x) 的窗口 = 行 y-3..y+3、列 x-3..x+3（4 个 4x4 象限重叠于
//     中间行/列），与参考的积分图一致。
//
// 流水线与"扩展网格"
//     输出像素 (y,x) 在输入走到 (row=y+3, col=x+3) 时才产生，所以每帧需要多
//     喂 3 行、每行多喂 8 拍的"flush 拍"（3 拍给右边界，5 拍给流水排空）。
//     这些 flush 拍用补零（zero padding）作为边界数据，并且**不消耗输入**：
//       - 真实位置 (row<H && col<W)：i_ready=1，靠 i_valid 推进；
//       - flush 位置：i_ready=0，adv 自己走（正好占用水平/垂直消隐的那些拍）。
//     好处：输出正好 H*W 个像素、SOF/EOL 自己生成、帧几何不变、不丢像素。
//
//     代价：边界 3 行的上象限 / 3 列的左象限会包含补零数据。因为最终只取
//     "方差最小"象限的均值，补零象限方差极大，实际几乎总会被排除，所以边界
//     表现接近"取最近的真实象限"，不会出现黑边。与参考的 edge-replicate
//     相比，最外 3 行/3 列会有少量像素差（内部像素逐位一致，见 README）。
//
// 延迟（相对输入 beat）
//     stage A (1) -> stage B 平方/竖直和 (1) -> box4col 累加 (1)
//     -> disc 判别式寄存 (1) -> 输出寄存 (1)  =>  LATENCY = 5 beats
//     加上竖直 3 行 + 水平 3 列的窗口延迟，整帧延迟约 3*(W+8)+3+5 拍。
//
// 流控（关键！）
//     输出侧有一级 skid 寄存器(out_vld/out_data)，全局只有在
//         out_free = !out_vld || m_ready
//     时才推进。这样：
//       * 下游反压(m_ready=0) -> 整条流水暂停，数据保持，不丢不重；
//       * 输入侧出现气泡(i_valid=0) -> 流水暂停，已算好的输出被下游取走后
//         就清空 out_vld，**不会**被下游重复接收（组合输出不加这一级会在
//         这里重复发同一个像素）。
// =============================================================================
module kuwahara #(
    parameter integer W = 800,   // 每行有效像素数（必须与实际流一致！）
    parameter integer H = 480    // 每帧有效行数（必须与实际流一致！）
)(
    input  wire        clk,
    input  wire        rstn,        // 低有效复位
    input  wire        i_valid,
    input  wire [23:0] i_data,      // {R[23:16], G[15:8], B[7:0]}
    input  wire        i_sof,       // 帧首像素（TUSER）
    input  wire        m_ready,     // 下游 ready（AXI TREADY）
    output wire        i_ready,
    output wire        o_valid,
    output wire [23:0] o_data,
    output wire        o_last,      // 行尾（TLAST），每行一个
    output wire        o_sof        // 帧首（TUSER），每帧一个
);

    // 扩展行长度：每行多 8 拍
    //   * 3 拍用于右边界（输出最后一列 x=W-1 需要 col 到 W+2）
    //   * 5 拍用于把最后 4 级流水 + 1 级 skid 寄存器"排空"，这样最后一行的
    //     最后一个输出像素能在本行内走完，不需要额外的排空拍（多一拍就会
    //     破坏行缓存"一行 = LW 拍"的对齐，导致帧间漂移）
    localparam integer LW  = W + 8;          // 扩展行长度（beat 数）
    localparam integer CW  = $clog2(LW);     // 列计数器位宽
    localparam integer CH  = $clog2(H + 3);  // 行计数器位宽

    // =========================================================================
    // 1. 位置计数器（扩展网格：(H+3) 行 x LW 列）
    // =========================================================================
    reg        in_frame;
    reg [CH:0] row;
    reg [CW:0] col;

    wire pos_is_real = (row < H) && (col < W);

    // ---- 流控：输出 skid 寄存器是否可接收 ----
    reg        out_vld;
    reg [23:0] out_data;
    reg        out_last;
    reg        out_sof;

    wire out_free = (!out_vld) || m_ready;

    wire adv = out_free && ( in_frame ? (pos_is_real ? i_valid : 1'b1)
                                     : (i_valid && i_sof) );
    assign i_ready = out_free && ( in_frame ? pos_is_real : 1'b1 );

    always @(posedge clk) begin
        if (!rstn) begin
            in_frame <= 1'b0;
            row      <= 0;
            col      <= 0;
        end else if (adv) begin
            if (!in_frame) begin
                in_frame <= 1'b1;
                row      <= 0;
                col      <= 1'b1;              // 本拍就是 col=0
            end else if (col == LW - 1) begin
                col <= 0;
                if (row == H + 2) begin
                    in_frame <= 1'b0;          // 本帧 flush 结束
                    row      <= 0;
                end else begin
                    row <= row + 1'b1;
                end
            end else begin
                col <= col + 1'b1;
            end
        end
    end

    // =========================================================================
    // 2. 边界补零 + 亮度
    // =========================================================================
    wire [23:0] din_rgb  = ((row >= H) || (col >= W)) ? 24'd0 : i_data;
    wire [15:0] luma_c;
    luma_q8 u_luma (.rgb(din_rgb), .luma(luma_c));

    // ---- stage A：输入寄存（把 3 乘 + 平方 的长组合路径切开）----
    reg [23:0] rgb_a;
    reg [15:0] luma_a;
    always @(posedge clk) begin
        if (!rstn) begin
            rgb_a  <= 24'd0;
            luma_a <= 16'd0;
        end else if (adv) begin
            rgb_a  <= din_rgb;
            luma_a <= luma_c;
        end
    end

    // =========================================================================
    // 3. 6 级行缓存（RGB 24bit + 亮度 16bit），每级延迟正好一行（LW 拍）
    // =========================================================================
    wire [23:0] r1, r2, r3, r4, r5, r6;
    wire [15:0] y1, y2, y3, y4, y5, y6;

    linebuf #(.W(LW), .DW(24)) u_lr1 (.clk(clk), .rstn(rstn), .en(adv), .din(rgb_a),  .dout(r1));
    linebuf #(.W(LW), .DW(24)) u_lr2 (.clk(clk), .rstn(rstn), .en(adv), .din(r1),     .dout(r2));
    linebuf #(.W(LW), .DW(24)) u_lr3 (.clk(clk), .rstn(rstn), .en(adv), .din(r2),     .dout(r3));
    linebuf #(.W(LW), .DW(24)) u_lr4 (.clk(clk), .rstn(rstn), .en(adv), .din(r3),     .dout(r4));
    linebuf #(.W(LW), .DW(24)) u_lr5 (.clk(clk), .rstn(rstn), .en(adv), .din(r4),     .dout(r5));
    linebuf #(.W(LW), .DW(24)) u_lr6 (.clk(clk), .rstn(rstn), .en(adv), .din(r5),     .dout(r6));

    linebuf #(.W(LW), .DW(16)) u_ly1 (.clk(clk), .rstn(rstn), .en(adv), .din(luma_a), .dout(y1));
    linebuf #(.W(LW), .DW(16)) u_ly2 (.clk(clk), .rstn(rstn), .en(adv), .din(y1),     .dout(y2));
    linebuf #(.W(LW), .DW(16)) u_ly3 (.clk(clk), .rstn(rstn), .en(adv), .din(y2),     .dout(y3));
    linebuf #(.W(LW), .DW(16)) u_ly4 (.clk(clk), .rstn(rstn), .en(adv), .din(y3),     .dout(y4));
    linebuf #(.W(LW), .DW(16)) u_ly5 (.clk(clk), .rstn(rstn), .en(adv), .din(y4),     .dout(y5));
    linebuf #(.W(LW), .DW(16)) u_ly6 (.clk(clk), .rstn(rstn), .en(adv), .din(y5),     .dout(y6));

    // =========================================================================
    // 4. stage B：7 行亮度平方 + 4 行竖直和
    //    dst 窗口行序（新 -> 旧）：r0=luma_a, r1..r6 = y1..y6
    //    下象限 = r0..r3，上象限 = r3..r6
    // =========================================================================
    (* use_dsp = "yes" *) wire [31:0] sq0 = luma_a * luma_a;
    (* use_dsp = "yes" *) wire [31:0] sq1 = y1 * y1;
    (* use_dsp = "yes" *) wire [31:0] sq2 = y2 * y2;
    (* use_dsp = "yes" *) wire [31:0] sq3 = y3 * y3;
    (* use_dsp = "yes" *) wire [31:0] sq4 = y4 * y4;
    (* use_dsp = "yes" *) wire [31:0] sq5 = y5 * y5;
    (* use_dsp = "yes" *) wire [31:0] sq6 = y6 * y6;

    reg [31:0] sq0r, sq1r, sq2r, sq3r, sq4r, sq5r, sq6r;

    // 4 行竖直和（未寄存）
    wire [17:0] vY_new = {2'b0, luma_a} + {2'b0, y1} + {2'b0, y2} + {2'b0, y3};
    wire [17:0] vY_old = {2'b0, y3} + {2'b0, y4} + {2'b0, y5} + {2'b0, y6};

    wire [9:0] vR_new = {2'b0, rgb_a[23:16]} + {2'b0, r1[23:16]} + {2'b0, r2[23:16]} + {2'b0, r3[23:16]};
    wire [9:0] vR_old = {2'b0, r3[23:16]} + {2'b0, r4[23:16]} + {2'b0, r5[23:16]} + {2'b0, r6[23:16]};
    wire [9:0] vG_new = {2'b0, rgb_a[15:8]}  + {2'b0, r1[15:8]}  + {2'b0, r2[15:8]}  + {2'b0, r3[15:8]};
    wire [9:0] vG_old = {2'b0, r3[15:8]}     + {2'b0, r4[15:8]}  + {2'b0, r5[15:8]}  + {2'b0, r6[15:8]};
    wire [9:0] vB_new = {2'b0, rgb_a[7:0]}   + {2'b0, r1[7:0]}   + {2'b0, r2[7:0]}   + {2'b0, r3[7:0]};
    wire [9:0] vB_old = {2'b0, r3[7:0]}      + {2'b0, r4[7:0]}   + {2'b0, r5[7:0]}   + {2'b0, r6[7:0]};

    reg [17:0] vY_new_r, vY_old_r;
    reg [9:0]  vR_new_r, vR_old_r, vG_new_r, vG_old_r, vB_new_r, vB_old_r;

    always @(posedge clk) begin
        if (!rstn) begin
            sq0r <= 0; sq1r <= 0; sq2r <= 0; sq3r <= 0;
            sq4r <= 0; sq5r <= 0; sq6r <= 0;
            vY_new_r <= 0; vY_old_r <= 0;
            vR_new_r <= 0; vR_old_r <= 0;
            vG_new_r <= 0; vG_old_r <= 0;
            vB_new_r <= 0; vB_old_r <= 0;
        end else if (adv) begin
            sq0r <= sq0; sq1r <= sq1; sq2r <= sq2; sq3r <= sq3;
            sq4r <= sq4; sq5r <= sq5; sq6r <= sq6;
            vY_new_r <= vY_new; vY_old_r <= vY_old;
            vR_new_r <= vR_new; vR_old_r <= vR_old;
            vG_new_r <= vG_new; vG_old_r <= vG_old;
            vB_new_r <= vB_new; vB_old_r <= vB_old;
        end
    end

    // =========================================================================
    // 5. 水平 4 列滑动和：h_new = v(c)+v(c-1)+v(c-2)+v(c-3)，h_old = 延迟 3 列
    // =========================================================================
    wire [33:0] vS_new = {2'b0, sq0r} + {2'b0, sq1r} + {2'b0, sq2r} + {2'b0, sq3r};
    wire [33:0] vS_old = {2'b0, sq3r} + {2'b0, sq4r} + {2'b0, sq5r} + {2'b0, sq6r};

    wire [19:0] ynew_n, ynew_o, yold_n, yold_o;
    wire [35:0] snew_n, snew_o, sold_n, sold_o;
    wire [11:0] rnew_n, rnew_o, rold_n, rold_o;
    wire [11:0] gnew_n, gnew_o, gold_n, gold_o;
    wire [11:0] bnew_n, bnew_o, bold_n, bold_o;

    box4col #(.DW(18)) by_new (.clk(clk), .rstn(rstn), .en(adv), .v(vY_new_r), .h_new(ynew_n), .h_old(ynew_o));
    box4col #(.DW(18)) by_old (.clk(clk), .rstn(rstn), .en(adv), .v(vY_old_r), .h_new(yold_n), .h_old(yold_o));
    box4col #(.DW(34)) bs_new (.clk(clk), .rstn(rstn), .en(adv), .v(vS_new),   .h_new(snew_n), .h_old(snew_o));
    box4col #(.DW(34)) bs_old (.clk(clk), .rstn(rstn), .en(adv), .v(vS_old),   .h_new(sold_n), .h_old(sold_o));
    box4col #(.DW(10)) br_new (.clk(clk), .rstn(rstn), .en(adv), .v(vR_new_r), .h_new(rnew_n), .h_old(rnew_o));
    box4col #(.DW(10)) br_old (.clk(clk), .rstn(rstn), .en(adv), .v(vR_old_r), .h_new(rold_n), .h_old(rold_o));
    box4col #(.DW(10)) bg_new (.clk(clk), .rstn(rstn), .en(adv), .v(vG_new_r), .h_new(gnew_n), .h_old(gnew_o));
    box4col #(.DW(10)) bg_old (.clk(clk), .rstn(rstn), .en(adv), .v(vG_old_r), .h_new(gold_n), .h_old(gold_o));
    box4col #(.DW(10)) bb_new (.clk(clk), .rstn(rstn), .en(adv), .v(vB_new_r), .h_new(bnew_n), .h_old(bnew_o));
    box4col #(.DW(10)) bb_old (.clk(clk), .rstn(rstn), .en(adv), .v(vB_old_r), .h_new(bold_n), .h_old(bold_o));

    // ---- 4 个象限的 (Y 和, Y^2 和, R/G/B 和) ----
    //   TL = 上4行 x 左4列；TR = 上4行 x 右4列；BL = 下4行 x 左4列；BR = 右下
    wire [19:0] q_tl_y = yold_o, q_tr_y = yold_n, q_bl_y = ynew_o, q_br_y = ynew_n;
    wire [35:0] q_tl_s = sold_o, q_tr_s = sold_n, q_bl_s = snew_o, q_br_s = snew_n;

    // =========================================================================
    // 6. stage C：判别式 disc = (16*sumY2) - sumY^2 寄存（判断与输出用下一级）
    // =========================================================================
    (* use_dsp = "yes" *) wire [39:0] p_tl = q_tl_y * q_tl_y;
    (* use_dsp = "yes" *) wire [39:0] p_tr = q_tr_y * q_tr_y;
    (* use_dsp = "yes" *) wire [39:0] p_bl = q_bl_y * q_bl_y;
    (* use_dsp = "yes" *) wire [39:0] p_br = q_br_y * q_br_y;

    wire [39:0] d_tl = (q_tl_s << 4) - p_tl;
    wire [39:0] d_tr = (q_tr_s << 4) - p_tr;
    wire [39:0] d_bl = (q_bl_s << 4) - p_bl;
    wire [39:0] d_br = (q_br_s << 4) - p_br;

    reg [39:0] d_tl_r, d_tr_r, d_bl_r, d_br_r;
    reg [11:0] tl_r, tl_g, tl_b, tr_r, tr_g, tr_b;
    reg [11:0] bl_r, bl_g, bl_b, br_r, br_g, br_b;

    always @(posedge clk) begin
        if (!rstn) begin
            d_tl_r <= 0; d_tr_r <= 0; d_bl_r <= 0; d_br_r <= 0;
            tl_r <= 0; tl_g <= 0; tl_b <= 0;
            tr_r <= 0; tr_g <= 0; tr_b <= 0;
            bl_r <= 0; bl_g <= 0; bl_b <= 0;
            br_r <= 0; br_g <= 0; br_b <= 0;
        end else if (adv) begin
            d_tl_r <= d_tl; d_tr_r <= d_tr; d_bl_r <= d_bl; d_br_r <= d_br;
            tl_r <= rold_o; tl_g <= gold_o; tl_b <= bold_o;
            tr_r <= rold_n; tr_g <= gold_n; tr_b <= bold_n;
            bl_r <= rnew_o; bl_g <= gnew_o; bl_b <= bnew_o;
            br_r <= rnew_n; br_g <= gnew_n; br_b <= bnew_n;
        end
    end

    // =========================================================================
    // 7. stage D（组合）：选方差最小象限 + round-half-even 均值
    //    平局优先级 TL > TR > BL > BR，与参考遍历顺序 + 严格小于一致
    // =========================================================================
    wire use_tl = (d_tl_r <= d_tr_r) && (d_tl_r <= d_bl_r) && (d_tl_r <= d_br_r);
    wire use_tr = !use_tl && (d_tr_r <= d_bl_r) && (d_tr_r <= d_br_r);
    wire use_bl = !use_tl && !use_tr && (d_bl_r <= d_br_r);

    wire [11:0] sr = use_tl ? tl_r : use_tr ? tr_r : use_bl ? bl_r : br_r;
    wire [11:0] sg = use_tl ? tl_g : use_tr ? tr_g : use_bl ? bl_g : br_g;
    wire [11:0] sb = use_tl ? tl_b : use_tr ? tr_b : use_bl ? bl_b : br_b;

    // round-half-even：q = s>>4，余数 r=s&15，>8 进位、(==8 且 q 为奇) 进位
    function [7:0] round_mean;
        input [11:0] s;
        begin
            round_mean = s[11:4] + {7'd0, ((s[3:0] > 4'd8) || ((s[3:0] == 4'd8) && s[4]))};
        end
    endfunction

    // ---- stage D 输出（组合）----
    wire [23:0] int_data = {round_mean(sr), round_mean(sg), round_mean(sb)};

    // =========================================================================
    // 8. 输出帧同步：位置 -> 4 级延迟（stage A / B / box4col / stage C）
    //    TUSER：每帧第一个像素；TLAST：每行最后一个像素（col == W+2）
    // =========================================================================
    reg f_v1, f_v2, f_v3, f_v4;
    reg f_s1, f_s2, f_s3, f_s4;
    reg f_l1, f_l2, f_l3, f_l4;

    always @(posedge clk) begin
        if (!rstn) begin
            f_v1 <= 0; f_v2 <= 0; f_v3 <= 0; f_v4 <= 0;
            f_s1 <= 0; f_s2 <= 0; f_s3 <= 0; f_s4 <= 0;
            f_l1 <= 0; f_l2 <= 0; f_l3 <= 0; f_l4 <= 0;
        end else if (adv) begin
            f_v1 <= (row >= 3) && (row <= H + 2) && (col >= 3) && (col <= W + 2);
            f_s1 <= (row == 3) && (col == 3);
            f_l1 <= (row >= 3) && (row <= H + 2) && (col == W + 2);
            f_v2 <= f_v1;  f_v3 <= f_v2;  f_v4 <= f_v3;
            f_s2 <= f_s1;  f_s3 <= f_s2;  f_s4 <= f_s3;
            f_l2 <= f_l1;  f_l3 <= f_l2;  f_l4 <= f_l3;
        end
    end

    wire int_valid = f_v4;
    wire int_sof   = f_s4;
    wire int_last  = f_l4;

    // =========================================================================
    // 9. 输出 skid 寄存器（一级），保证反压/输入气泡下不丢拍、不重发
    // =========================================================================
    always @(posedge clk) begin
        if (!rstn) begin
            out_vld  <= 1'b0;
            out_data <= 24'd0;
            out_last <= 1'b0;
            out_sof  <= 1'b0;
        end else if (adv) begin
            out_vld  <= int_valid;
            out_data <= int_data;
            out_last <= int_last;
            out_sof  <= int_sof;
        end else if (m_ready) begin
            out_vld  <= 1'b0;         // 已被下游取走，且本级冻结 -> 清掉，避免重发
        end
    end

    assign o_valid = out_vld;
    assign o_data  = out_data;
    assign o_last  = out_last;
    assign o_sof   = out_sof;

endmodule
