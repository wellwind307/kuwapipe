//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Sun Nov  1 14:20:53 2026
//Host        : e running 64-bit major release  (build 9200)
//Command     : generate_target base_wrapper.bd
//Design      : base_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module base_wrapper
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    IIC_1_scl_io,
    IIC_1_sda_io,
    TMDS_clk_n,
    TMDS_clk_p,
    TMDS_data_n,
    TMDS_data_p,
    Vp_Vn_v_n,
    Vp_Vn_v_p,
    aud_adcdat,
    aud_bclk,
    aud_dacdat,
    aud_lrc,
    aud_mclk,
    beep_tri_o,
    btns_tri_i,
    cam_data,
    cam_href,
    cam_iic_scl_io,
    cam_iic_sda_io,
    cam_pclk,
    cam_pwdn,
    cam_rst_n,
    cam_vsync,
    hdmi_ddc_scl_io,
    hdmi_ddc_sda_io,
    hdmi_hpd_tri_io,
    io_0_tri_io,
    leds_tri_o,
    mode_led,
    spi_rtl_0_io0_io,
    spi_rtl_0_io1_io,
    spi_rtl_0_sck_io,
    spi_rtl_0_ss_io,
    touch_tri_i);
  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;
  inout IIC_1_scl_io;
  inout IIC_1_sda_io;
  output TMDS_clk_n;
  output TMDS_clk_p;
  output [2:0]TMDS_data_n;
  output [2:0]TMDS_data_p;
  input Vp_Vn_v_n;
  input Vp_Vn_v_p;
  input aud_adcdat;
  output aud_bclk;
  output aud_dacdat;
  output aud_lrc;
  output aud_mclk;
  output [0:0]beep_tri_o;
  input [1:0]btns_tri_i;
  input [7:0]cam_data;
  input cam_href;
  inout cam_iic_scl_io;
  inout cam_iic_sda_io;
  input cam_pclk;
  output cam_pwdn;
  output cam_rst_n;
  input cam_vsync;
  inout hdmi_ddc_scl_io;
  inout hdmi_ddc_sda_io;
  inout [0:0]hdmi_hpd_tri_io;
  inout [3:0]io_0_tri_io;
  output [1:0]leds_tri_o;
  output mode_led;
  inout spi_rtl_0_io0_io;
  inout spi_rtl_0_io1_io;
  inout spi_rtl_0_sck_io;
  inout [0:0]spi_rtl_0_ss_io;
  input [0:0]touch_tri_i;

  wire [14:0]DDR_addr;
  wire [2:0]DDR_ba;
  wire DDR_cas_n;
  wire DDR_ck_n;
  wire DDR_ck_p;
  wire DDR_cke;
  wire DDR_cs_n;
  wire [3:0]DDR_dm;
  wire [31:0]DDR_dq;
  wire [3:0]DDR_dqs_n;
  wire [3:0]DDR_dqs_p;
  wire DDR_odt;
  wire DDR_ras_n;
  wire DDR_reset_n;
  wire DDR_we_n;
  wire FIXED_IO_ddr_vrn;
  wire FIXED_IO_ddr_vrp;
  wire [53:0]FIXED_IO_mio;
  wire FIXED_IO_ps_clk;
  wire FIXED_IO_ps_porb;
  wire FIXED_IO_ps_srstb;
  wire IIC_1_scl_i;
  wire IIC_1_scl_io;
  wire IIC_1_scl_o;
  wire IIC_1_scl_t;
  wire IIC_1_sda_i;
  wire IIC_1_sda_io;
  wire IIC_1_sda_o;
  wire IIC_1_sda_t;
  wire TMDS_clk_n;
  wire TMDS_clk_p;
  wire [2:0]TMDS_data_n;
  wire [2:0]TMDS_data_p;
  wire Vp_Vn_v_n;
  wire Vp_Vn_v_p;
  wire aud_adcdat;
  wire aud_bclk;
  wire aud_dacdat;
  wire aud_lrc;
  wire aud_mclk;
  wire [0:0]beep_tri_o;
  wire [1:0]btns_tri_i;
  wire [7:0]cam_data;
  wire cam_href;
  wire cam_iic_scl_i;
  wire cam_iic_scl_io;
  wire cam_iic_scl_o;
  wire cam_iic_scl_t;
  wire cam_iic_sda_i;
  wire cam_iic_sda_io;
  wire cam_iic_sda_o;
  wire cam_iic_sda_t;
  wire cam_pclk;
  wire cam_pwdn;
  wire cam_rst_n;
  wire cam_vsync;
  wire hdmi_ddc_scl_i;
  wire hdmi_ddc_scl_io;
  wire hdmi_ddc_scl_o;
  wire hdmi_ddc_scl_t;
  wire hdmi_ddc_sda_i;
  wire hdmi_ddc_sda_io;
  wire hdmi_ddc_sda_o;
  wire hdmi_ddc_sda_t;
  wire [0:0]hdmi_hpd_tri_i_0;
  wire [0:0]hdmi_hpd_tri_io_0;
  wire [0:0]hdmi_hpd_tri_o_0;
  wire [0:0]hdmi_hpd_tri_t_0;
  wire [0:0]io_0_tri_i_0;
  wire [1:1]io_0_tri_i_1;
  wire [2:2]io_0_tri_i_2;
  wire [3:3]io_0_tri_i_3;
  wire [0:0]io_0_tri_io_0;
  wire [1:1]io_0_tri_io_1;
  wire [2:2]io_0_tri_io_2;
  wire [3:3]io_0_tri_io_3;
  wire [0:0]io_0_tri_o_0;
  wire [1:1]io_0_tri_o_1;
  wire [2:2]io_0_tri_o_2;
  wire [3:3]io_0_tri_o_3;
  wire [0:0]io_0_tri_t_0;
  wire [1:1]io_0_tri_t_1;
  wire [2:2]io_0_tri_t_2;
  wire [3:3]io_0_tri_t_3;
  wire [1:0]leds_tri_o;
  wire mode_led;
  wire spi_rtl_0_io0_i;
  wire spi_rtl_0_io0_io;
  wire spi_rtl_0_io0_o;
  wire spi_rtl_0_io0_t;
  wire spi_rtl_0_io1_i;
  wire spi_rtl_0_io1_io;
  wire spi_rtl_0_io1_o;
  wire spi_rtl_0_io1_t;
  wire spi_rtl_0_sck_i;
  wire spi_rtl_0_sck_io;
  wire spi_rtl_0_sck_o;
  wire spi_rtl_0_sck_t;
  wire [0:0]spi_rtl_0_ss_i_0;
  wire [0:0]spi_rtl_0_ss_io_0;
  wire [0:0]spi_rtl_0_ss_o_0;
  wire spi_rtl_0_ss_t;
  wire [0:0]touch_tri_i;

  IOBUF IIC_1_scl_iobuf
       (.I(IIC_1_scl_o),
        .IO(IIC_1_scl_io),
        .O(IIC_1_scl_i),
        .T(IIC_1_scl_t));
  IOBUF IIC_1_sda_iobuf
       (.I(IIC_1_sda_o),
        .IO(IIC_1_sda_io),
        .O(IIC_1_sda_i),
        .T(IIC_1_sda_t));
  base base_i
       (.DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .IIC_1_scl_i(IIC_1_scl_i),
        .IIC_1_scl_o(IIC_1_scl_o),
        .IIC_1_scl_t(IIC_1_scl_t),
        .IIC_1_sda_i(IIC_1_sda_i),
        .IIC_1_sda_o(IIC_1_sda_o),
        .IIC_1_sda_t(IIC_1_sda_t),
        .TMDS_clk_n(TMDS_clk_n),
        .TMDS_clk_p(TMDS_clk_p),
        .TMDS_data_n(TMDS_data_n),
        .TMDS_data_p(TMDS_data_p),
        .Vp_Vn_v_n(Vp_Vn_v_n),
        .Vp_Vn_v_p(Vp_Vn_v_p),
        .aud_adcdat(aud_adcdat),
        .aud_bclk(aud_bclk),
        .aud_dacdat(aud_dacdat),
        .aud_lrc(aud_lrc),
        .aud_mclk(aud_mclk),
        .beep_tri_o(beep_tri_o),
        .btns_tri_i(btns_tri_i),
        .cam_data(cam_data),
        .cam_href(cam_href),
        .cam_iic_scl_i(cam_iic_scl_i),
        .cam_iic_scl_o(cam_iic_scl_o),
        .cam_iic_scl_t(cam_iic_scl_t),
        .cam_iic_sda_i(cam_iic_sda_i),
        .cam_iic_sda_o(cam_iic_sda_o),
        .cam_iic_sda_t(cam_iic_sda_t),
        .cam_pclk(cam_pclk),
        .cam_pwdn(cam_pwdn),
        .cam_rst_n(cam_rst_n),
        .cam_vsync(cam_vsync),
        .hdmi_ddc_scl_i(hdmi_ddc_scl_i),
        .hdmi_ddc_scl_o(hdmi_ddc_scl_o),
        .hdmi_ddc_scl_t(hdmi_ddc_scl_t),
        .hdmi_ddc_sda_i(hdmi_ddc_sda_i),
        .hdmi_ddc_sda_o(hdmi_ddc_sda_o),
        .hdmi_ddc_sda_t(hdmi_ddc_sda_t),
        .hdmi_hpd_tri_i(hdmi_hpd_tri_i_0),
        .hdmi_hpd_tri_o(hdmi_hpd_tri_o_0),
        .hdmi_hpd_tri_t(hdmi_hpd_tri_t_0),
        .io_0_tri_i({io_0_tri_i_3,io_0_tri_i_2,io_0_tri_i_1,io_0_tri_i_0}),
        .io_0_tri_o({io_0_tri_o_3,io_0_tri_o_2,io_0_tri_o_1,io_0_tri_o_0}),
        .io_0_tri_t({io_0_tri_t_3,io_0_tri_t_2,io_0_tri_t_1,io_0_tri_t_0}),
        .leds_tri_o(leds_tri_o),
        .mode_led(mode_led),
        .spi_rtl_0_io0_i(spi_rtl_0_io0_i),
        .spi_rtl_0_io0_o(spi_rtl_0_io0_o),
        .spi_rtl_0_io0_t(spi_rtl_0_io0_t),
        .spi_rtl_0_io1_i(spi_rtl_0_io1_i),
        .spi_rtl_0_io1_o(spi_rtl_0_io1_o),
        .spi_rtl_0_io1_t(spi_rtl_0_io1_t),
        .spi_rtl_0_sck_i(spi_rtl_0_sck_i),
        .spi_rtl_0_sck_o(spi_rtl_0_sck_o),
        .spi_rtl_0_sck_t(spi_rtl_0_sck_t),
        .spi_rtl_0_ss_i(spi_rtl_0_ss_i_0),
        .spi_rtl_0_ss_o(spi_rtl_0_ss_o_0),
        .spi_rtl_0_ss_t(spi_rtl_0_ss_t),
        .touch_tri_i(touch_tri_i));
  IOBUF cam_iic_scl_iobuf
       (.I(cam_iic_scl_o),
        .IO(cam_iic_scl_io),
        .O(cam_iic_scl_i),
        .T(cam_iic_scl_t));
  IOBUF cam_iic_sda_iobuf
       (.I(cam_iic_sda_o),
        .IO(cam_iic_sda_io),
        .O(cam_iic_sda_i),
        .T(cam_iic_sda_t));
  IOBUF hdmi_ddc_scl_iobuf
       (.I(hdmi_ddc_scl_o),
        .IO(hdmi_ddc_scl_io),
        .O(hdmi_ddc_scl_i),
        .T(hdmi_ddc_scl_t));
  IOBUF hdmi_ddc_sda_iobuf
       (.I(hdmi_ddc_sda_o),
        .IO(hdmi_ddc_sda_io),
        .O(hdmi_ddc_sda_i),
        .T(hdmi_ddc_sda_t));
  IOBUF hdmi_hpd_tri_iobuf_0
       (.I(hdmi_hpd_tri_o_0),
        .IO(hdmi_hpd_tri_io[0]),
        .O(hdmi_hpd_tri_i_0),
        .T(hdmi_hpd_tri_t_0));
  IOBUF io_0_tri_iobuf_0
       (.I(io_0_tri_o_0),
        .IO(io_0_tri_io[0]),
        .O(io_0_tri_i_0),
        .T(io_0_tri_t_0));
  IOBUF io_0_tri_iobuf_1
       (.I(io_0_tri_o_1),
        .IO(io_0_tri_io[1]),
        .O(io_0_tri_i_1),
        .T(io_0_tri_t_1));
  IOBUF io_0_tri_iobuf_2
       (.I(io_0_tri_o_2),
        .IO(io_0_tri_io[2]),
        .O(io_0_tri_i_2),
        .T(io_0_tri_t_2));
  IOBUF io_0_tri_iobuf_3
       (.I(io_0_tri_o_3),
        .IO(io_0_tri_io[3]),
        .O(io_0_tri_i_3),
        .T(io_0_tri_t_3));
  IOBUF spi_rtl_0_io0_iobuf
       (.I(spi_rtl_0_io0_o),
        .IO(spi_rtl_0_io0_io),
        .O(spi_rtl_0_io0_i),
        .T(spi_rtl_0_io0_t));
  IOBUF spi_rtl_0_io1_iobuf
       (.I(spi_rtl_0_io1_o),
        .IO(spi_rtl_0_io1_io),
        .O(spi_rtl_0_io1_i),
        .T(spi_rtl_0_io1_t));
  IOBUF spi_rtl_0_sck_iobuf
       (.I(spi_rtl_0_sck_o),
        .IO(spi_rtl_0_sck_io),
        .O(spi_rtl_0_sck_i),
        .T(spi_rtl_0_sck_t));
  IOBUF spi_rtl_0_ss_iobuf_0
       (.I(spi_rtl_0_ss_o_0),
        .IO(spi_rtl_0_ss_io[0]),
        .O(spi_rtl_0_ss_i_0),
        .T(spi_rtl_0_ss_t));
endmodule
