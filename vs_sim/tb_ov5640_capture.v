`timescale 1ns / 1ps
// =============================================================================
// tb_ov5640_capture.v —— 等价性协同仿真
//
// 目的：证明 ov5640_capture.v 与设计中原采集 IP（cmos_capture_data）在
//       【相同激励下逐拍输出完全一致】，而不是"看起来能出图"。
//
// 做法：并排例化两个模块，同一组 cam_pclk / cam_vsync / cam_href / cam_data，
//       从双方均放行之后开始，每拍用 !== 比较全部输出（含 X 检测）。
//
// 激励覆盖：
//   A. 上电复位 → 释放 → 30 帧，每帧 12 行（首行为 1600 字节，模拟 800 像素宽），
//      行/场消隐随机抖动，数据为 LFSR 伪随机；
//   B. 运行中复位 10 拍 → 释放 → 再跑 15 帧（验证复位后重新对齐）；
//   C. 帧末随机空闲拍（考验 phase 在 href 下降沿的复位）。
//
// 复位瞬态（1~2 拍）不参与比较：原 IP 的第二级复位同步器未复位（X→0 边沿
// 才触发下游复位），被试模块则直接异步复位到 0。二者在复位释放后的稳态
// 行为必须一致，这正是本 TB 要证明的。
//
// 运行（Vivado xsim，注意不要加 -debug，本机该模式会崩）：
//   xvlog ../_ref/cmos_capture_data_ref.v ../base.srcs/sources_1/new/ov5640_capture.v tb_ov5640_capture.v
//   xelab tb_ov5640_capture -s sim
//   xsim sim -R
// =============================================================================
module tb_ov5640_capture;

    // ---------------- 时钟 / 复位 ----------------
    reg cam_pclk = 1'b0;
    always #5 cam_pclk = ~cam_pclk;          // 100 MHz

    reg rst_n = 1'b0;

    // ---------------- 激励 ----------------
    reg        cam_vsync = 1'b0;
    reg        cam_href  = 1'b0;
    reg  [7:0] cam_data  = 8'h00;

    // ---------------- 输出 ----------------
    wire        v_clk, v_ce, v_vs, v_hs, v_av, v_rstn, v_pwdn;
    wire [23:0] v_data;
    wire        d_clk, d_ce, d_vs, d_hs, d_av, d_rstn, d_pwdn;
    wire [23:0] d_data;

    cmos_capture_data u_ref (
        .rst_n            (rst_n),
        .cam_pclk         (cam_pclk),
        .cam_vsync        (cam_vsync),
        .cam_href         (cam_href),
        .cam_data         (cam_data),
        .cam_rst_n        (v_rstn),
        .cam_pwdn         (v_pwdn),
        .cmos_frame_clk   (v_clk),
        .cmos_frame_ce    (v_ce),
        .cmos_frame_vsync (v_vs),
        .cmos_frame_href  (v_hs),
        .cmos_active_video(v_av),
        .cmos_frame_data  (v_data)
    );

    ov5640_capture u_dut (
        .rst_n   (rst_n),
        .cam_pclk(cam_pclk),
        .cam_vsync(cam_vsync),
        .cam_href(cam_href),
        .cam_data(cam_data),
        .cam_rst_n(d_rstn),
        .cam_pwdn (d_pwdn),
        .vid_clk  (d_clk),
        .vid_ce   (d_ce),
        .vid_vsync(d_vs),
        .vid_href (d_hs),
        .vid_active(d_av),
        .vid_data (d_data)
    );

    // ---------------- 比较使能 ----------------
    integer vsync_cnt = 0;
    reg     vsync_q   = 1'b0;
    reg     cmp_en    = 1'b0;
    reg     cmp_hold  = 1'b0;      // 复位瞬态期间挂起比较

    always @(posedge cam_pclk) begin
        if (cam_vsync && !vsync_q)
            vsync_cnt <= vsync_cnt + 1;
        vsync_q <= cam_vsync;
        if (vsync_cnt >= 11)
            cmp_en <= 1'b1;
    end

    // ---------------- 逐拍比较 ----------------
    integer chk_cnt = 0;
    integer err_cnt = 0;

    always @(posedge cam_pclk) begin
        if (cmp_en && !cmp_hold) begin
            chk_cnt = chk_cnt + 1;
            if ({v_rstn, v_pwdn, v_vs, v_hs, v_av, v_ce, v_data} !==
                {d_rstn, d_pwdn, d_vs, d_hs, d_av, d_ce, d_data}) begin
                err_cnt = err_cnt + 1;
                if (err_cnt <= 8) begin
                    $display("[%0t] MISMATCH #%0d: ref={rstn=%b pwdn=%b vs=%b hs=%b av=%b ce=%b data=%h} dut={rstn=%b pwdn=%b vs=%b hs=%b av=%b ce=%b data=%h}",
                             $time, err_cnt,
                             v_rstn, v_pwdn, v_vs, v_hs, v_av, v_ce, v_data,
                             d_rstn, d_pwdn, d_vs, d_hs, d_av, d_ce, d_data);
                end
            end
        end
    end

    // ---------------- 激励产生 ----------------
    reg [7:0] lfsr = 8'hA5;
    function [7:0] next_byte;
        input [7:0] s;
        begin
            next_byte = {s[6:0], s[7] ^ s[5] ^ s[4] ^ s[3]};
        end
    endfunction

    integer f, l, b, g;

    // 一帧：场同步 + 场消隐 + nline 行有效数据（首行宽 1600 字节）
    task do_frame;
        input integer nline;
        input integer nbyte;
        integer line_byte;
        begin
            @(negedge cam_pclk); cam_vsync = 1'b1;
            repeat (3) @(negedge cam_pclk);
            @(negedge cam_pclk); cam_vsync = 1'b0; cam_href = 1'b0; cam_data = 8'h00;

            g = 5 + ($random % 11);
            if (g < 0) g = 0;
            repeat (g) @(negedge cam_pclk);

            for (l = 0; l < nline; l = l + 1) begin
                line_byte = (l == 0) ? 1600 : nbyte;
                @(negedge cam_pclk); cam_href = 1'b1;
                for (b = 0; b < line_byte; b = b + 1) begin
                    lfsr     = next_byte(lfsr);
                    cam_data = lfsr;
                    @(negedge cam_pclk);
                end
                @(negedge cam_pclk); cam_href = 1'b0; cam_data = 8'h00;

                g = ($random % 7);
                if (g < 0) g = 0;
                repeat (g) @(negedge cam_pclk);
            end

            g = 2 + ($random % 9);
            if (g < 0) g = 0;
            repeat (g) @(negedge cam_pclk);
        end
    endtask

    initial begin
        repeat (5) @(negedge cam_pclk);
        rst_n = 1'b1;

        // ---------------- 阶段 A：上电后 30 帧 ----------------
        for (f = 0; f < 30; f = f + 1)
            do_frame(12, 192);

        // ---------------- 阶段 B：运行中复位再恢复 ----------------
        cmp_hold = 1'b1;
        @(negedge cam_pclk);
        rst_n = 1'b0; cam_vsync = 1'b0; cam_href = 1'b0; cam_data = 8'h00;
        repeat (10) @(negedge cam_pclk);
        @(negedge cam_pclk); rst_n = 1'b1;
        vsync_cnt = 0; cmp_en = 1'b0;
        repeat (3) @(negedge cam_pclk);
        cmp_hold = 1'b0;

        for (f = 0; f < 15; f = f + 1)
            do_frame(10, 160);

        repeat (300) @(negedge cam_pclk);

        $display("------------------------------------------------------------");
        $display("compared cycles : %0d", chk_cnt);
        $display("mismatches      : %0d", err_cnt);
        $display("RESULT          : %s", (err_cnt == 0 && chk_cnt > 50000) ? "PASS" : "FAIL");
        $display("------------------------------------------------------------");
        $finish;
    end

    initial begin
        #50_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
