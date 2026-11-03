
wire kernel_monitor_reset;
wire kernel_monitor_clock;
wire kernel_monitor_report;
assign kernel_monitor_reset = ~ap_rst_n;
assign kernel_monitor_clock = ap_clk;
assign kernel_monitor_report = 1'b0;
wire [3:0] axis_block_sigs;
wire [9:0] inst_idle_sigs;
wire [2:0] inst_block_sigs;
wire kernel_block;

assign axis_block_sigs[0] = ~AXIvideo2xfMat_24_16_480_800_1_2_U0.grp_AXIvideo2xfMat_24_16_480_800_1_2_Pipeline_loop_start_hunt_fu_110.video_in_TDATA_blk_n;
assign axis_block_sigs[1] = ~AXIvideo2xfMat_24_16_480_800_1_2_U0.grp_AXIvideo2xfMat_24_16_480_800_1_2_Pipeline_loop_col_zxi2mat_fu_130.video_in_TDATA_blk_n;
assign axis_block_sigs[2] = ~AXIvideo2xfMat_24_16_480_800_1_2_U0.grp_AXIvideo2xfMat_24_16_480_800_1_2_Pipeline_loop_last_hunt_fu_157.video_in_TDATA_blk_n;
assign axis_block_sigs[3] = ~xfMat2AXIvideo_24_16_480_800_1_2_0_U0.grp_xfMat2AXIvideo_24_16_480_800_1_2_0_Pipeline_loop_col_mat2axi_fu_74.video_out_TDATA_blk_n;

assign inst_idle_sigs[0] = AXIvideo2xfMat_24_16_480_800_1_2_U0.ap_idle;
assign inst_block_sigs[0] = (AXIvideo2xfMat_24_16_480_800_1_2_U0.ap_done & ~AXIvideo2xfMat_24_16_480_800_1_2_U0.ap_continue) | ~AXIvideo2xfMat_24_16_480_800_1_2_U0.grp_AXIvideo2xfMat_24_16_480_800_1_2_Pipeline_loop_col_zxi2mat_fu_130.img_in_data_blk_n;
assign inst_idle_sigs[1] = medianBlur_3_1_16_480_800_1_0_2_2_U0.ap_idle;
assign inst_block_sigs[1] = (medianBlur_3_1_16_480_800_1_0_2_2_U0.ap_done & ~medianBlur_3_1_16_480_800_1_0_2_2_U0.ap_continue) | ~medianBlur_3_1_16_480_800_1_0_2_2_U0.grp_xFMedianNxN_480_800_3_16_1_0_2_2_0_801_3_9_s_fu_16.grp_xFMedianNxN_480_800_3_16_1_0_2_2_0_801_3_9_Pipeline_VITIS_LOOP_431_2_fu_127.img_in_data_blk_n | ~medianBlur_3_1_16_480_800_1_0_2_2_U0.grp_xFMedianNxN_480_800_3_16_1_0_2_2_0_801_3_9_s_fu_16.grp_xFMedianNxN_480_800_3_16_1_0_2_2_0_801_3_9_Pipeline_Col_Loop_fu_145.img_in_data_blk_n | ~medianBlur_3_1_16_480_800_1_0_2_2_U0.grp_xFMedianNxN_480_800_3_16_1_0_2_2_0_801_3_9_s_fu_16.grp_xFMedianNxN_480_800_3_16_1_0_2_2_0_801_3_9_Pipeline_Col_Loop_fu_145.img_out_data_blk_n;
assign inst_idle_sigs[2] = xfMat2AXIvideo_24_16_480_800_1_2_0_U0.ap_idle;
assign inst_block_sigs[2] = (xfMat2AXIvideo_24_16_480_800_1_2_0_U0.ap_done & ~xfMat2AXIvideo_24_16_480_800_1_2_0_U0.ap_continue) | ~xfMat2AXIvideo_24_16_480_800_1_2_0_U0.grp_xfMat2AXIvideo_24_16_480_800_1_2_0_Pipeline_loop_col_mat2axi_fu_74.img_out_data_blk_n;

assign inst_idle_sigs[3] = 1'b0;
assign inst_idle_sigs[4] = AXIvideo2xfMat_24_16_480_800_1_2_U0.ap_idle;
assign inst_idle_sigs[5] = AXIvideo2xfMat_24_16_480_800_1_2_U0.grp_AXIvideo2xfMat_24_16_480_800_1_2_Pipeline_loop_start_hunt_fu_110.ap_idle;
assign inst_idle_sigs[6] = AXIvideo2xfMat_24_16_480_800_1_2_U0.grp_AXIvideo2xfMat_24_16_480_800_1_2_Pipeline_loop_col_zxi2mat_fu_130.ap_idle;
assign inst_idle_sigs[7] = AXIvideo2xfMat_24_16_480_800_1_2_U0.grp_AXIvideo2xfMat_24_16_480_800_1_2_Pipeline_loop_last_hunt_fu_157.ap_idle;
assign inst_idle_sigs[8] = xfMat2AXIvideo_24_16_480_800_1_2_0_U0.ap_idle;
assign inst_idle_sigs[9] = xfMat2AXIvideo_24_16_480_800_1_2_0_U0.grp_xfMat2AXIvideo_24_16_480_800_1_2_0_Pipeline_loop_col_mat2axi_fu_74.ap_idle;

median_blur_color_hls_deadlock_idx0_monitor median_blur_color_hls_deadlock_idx0_monitor_U (
    .clock(kernel_monitor_clock),
    .reset(kernel_monitor_reset),
    .axis_block_sigs(axis_block_sigs),
    .inst_idle_sigs(inst_idle_sigs),
    .inst_block_sigs(inst_block_sigs),
    .block(kernel_block)
);


always @ (kernel_block or kernel_monitor_reset) begin
    if (kernel_block == 1'b1 && kernel_monitor_reset == 1'b0) begin
        find_kernel_block = 1'b1;
    end
    else begin
        find_kernel_block = 1'b0;
    end
end
