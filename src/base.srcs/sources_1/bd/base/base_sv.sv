// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
// DO NOT MODIFY THIS FILE.

// MODULE VLNV: amd.com:blockdesign:base:1.0

`timescale 1ps / 1ps

`include "vivado_interfaces.svh"

module base_sv (
  (* X_INTERFACE_IGNORE = "true" *)
  input wire [1:0] btns_tri_i,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_cas_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_cke,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_ck_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_ck_p,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_cs_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_reset_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_odt,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_ras_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire DDR_we_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [2:0] DDR_ba,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [14:0] DDR_addr,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [3:0] DDR_dm,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [31:0] DDR_dq,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [3:0] DDR_dqs_n,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [3:0] DDR_dqs_p,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire [53:0] FIXED_IO_mio,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire FIXED_IO_ddr_vrn,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire FIXED_IO_ddr_vrp,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire FIXED_IO_ps_srstb,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire FIXED_IO_ps_clk,
  (* X_INTERFACE_IGNORE = "true" *)
  inout wire FIXED_IO_ps_porb,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire IIC_1_sda_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire IIC_1_sda_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire IIC_1_sda_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire IIC_1_scl_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire IIC_1_scl_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire IIC_1_scl_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire Vp_Vn_v_n,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire Vp_Vn_v_p,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] beep_tri_o,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire cam_iic_scl_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire cam_iic_scl_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire cam_iic_scl_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire cam_iic_sda_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire cam_iic_sda_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire cam_iic_sda_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire hdmi_ddc_sda_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire hdmi_ddc_sda_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire hdmi_ddc_sda_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire hdmi_ddc_scl_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire hdmi_ddc_scl_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire hdmi_ddc_scl_t,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [1:0] leds_tri_o,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire [0:0] touch_tri_i,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire spi_rtl_0_io0_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire spi_rtl_0_io0_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire spi_rtl_0_io0_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire spi_rtl_0_io1_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire spi_rtl_0_io1_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire spi_rtl_0_io1_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire spi_rtl_0_sck_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire spi_rtl_0_sck_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire spi_rtl_0_sck_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire [0:0] spi_rtl_0_ss_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] spi_rtl_0_ss_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire spi_rtl_0_ss_t,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [3:0] io_0_tri_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [3:0] io_0_tri_t,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire [3:0] io_0_tri_i,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire [0:0] hdmi_hpd_tri_i,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] hdmi_hpd_tri_o,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [0:0] hdmi_hpd_tri_t,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire TMDS_clk_p,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire TMDS_clk_n,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [2:0] TMDS_data_p,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire [2:0] TMDS_data_n,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire aud_adcdat,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire aud_bclk,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire aud_dacdat,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire aud_lrc,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire [7:0] cam_data,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire cam_href,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire cam_pclk,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire cam_pwdn,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire cam_rst_n,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire cam_vsync,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire aud_mclk,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire mode_led
);

  base inst (
    .btns_tri_i(btns_tri_i),
    .DDR_cas_n(DDR_cas_n),
    .DDR_cke(DDR_cke),
    .DDR_ck_n(DDR_ck_n),
    .DDR_ck_p(DDR_ck_p),
    .DDR_cs_n(DDR_cs_n),
    .DDR_reset_n(DDR_reset_n),
    .DDR_odt(DDR_odt),
    .DDR_ras_n(DDR_ras_n),
    .DDR_we_n(DDR_we_n),
    .DDR_ba(DDR_ba),
    .DDR_addr(DDR_addr),
    .DDR_dm(DDR_dm),
    .DDR_dq(DDR_dq),
    .DDR_dqs_n(DDR_dqs_n),
    .DDR_dqs_p(DDR_dqs_p),
    .FIXED_IO_mio(FIXED_IO_mio),
    .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
    .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
    .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
    .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
    .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
    .IIC_1_sda_i(IIC_1_sda_i),
    .IIC_1_sda_o(IIC_1_sda_o),
    .IIC_1_sda_t(IIC_1_sda_t),
    .IIC_1_scl_i(IIC_1_scl_i),
    .IIC_1_scl_o(IIC_1_scl_o),
    .IIC_1_scl_t(IIC_1_scl_t),
    .Vp_Vn_v_n(Vp_Vn_v_n),
    .Vp_Vn_v_p(Vp_Vn_v_p),
    .beep_tri_o(beep_tri_o),
    .cam_iic_scl_i(cam_iic_scl_i),
    .cam_iic_scl_o(cam_iic_scl_o),
    .cam_iic_scl_t(cam_iic_scl_t),
    .cam_iic_sda_i(cam_iic_sda_i),
    .cam_iic_sda_o(cam_iic_sda_o),
    .cam_iic_sda_t(cam_iic_sda_t),
    .hdmi_ddc_sda_i(hdmi_ddc_sda_i),
    .hdmi_ddc_sda_o(hdmi_ddc_sda_o),
    .hdmi_ddc_sda_t(hdmi_ddc_sda_t),
    .hdmi_ddc_scl_i(hdmi_ddc_scl_i),
    .hdmi_ddc_scl_o(hdmi_ddc_scl_o),
    .hdmi_ddc_scl_t(hdmi_ddc_scl_t),
    .leds_tri_o(leds_tri_o),
    .touch_tri_i(touch_tri_i),
    .spi_rtl_0_io0_i(spi_rtl_0_io0_i),
    .spi_rtl_0_io0_o(spi_rtl_0_io0_o),
    .spi_rtl_0_io0_t(spi_rtl_0_io0_t),
    .spi_rtl_0_io1_i(spi_rtl_0_io1_i),
    .spi_rtl_0_io1_o(spi_rtl_0_io1_o),
    .spi_rtl_0_io1_t(spi_rtl_0_io1_t),
    .spi_rtl_0_sck_i(spi_rtl_0_sck_i),
    .spi_rtl_0_sck_o(spi_rtl_0_sck_o),
    .spi_rtl_0_sck_t(spi_rtl_0_sck_t),
    .spi_rtl_0_ss_i(spi_rtl_0_ss_i),
    .spi_rtl_0_ss_o(spi_rtl_0_ss_o),
    .spi_rtl_0_ss_t(spi_rtl_0_ss_t),
    .io_0_tri_o(io_0_tri_o),
    .io_0_tri_t(io_0_tri_t),
    .io_0_tri_i(io_0_tri_i),
    .hdmi_hpd_tri_i(hdmi_hpd_tri_i),
    .hdmi_hpd_tri_o(hdmi_hpd_tri_o),
    .hdmi_hpd_tri_t(hdmi_hpd_tri_t),
    .TMDS_clk_p(TMDS_clk_p),
    .TMDS_clk_n(TMDS_clk_n),
    .TMDS_data_p(TMDS_data_p),
    .TMDS_data_n(TMDS_data_n),
    .aud_adcdat(aud_adcdat),
    .aud_bclk(aud_bclk),
    .aud_dacdat(aud_dacdat),
    .aud_lrc(aud_lrc),
    .cam_data(cam_data),
    .cam_href(cam_href),
    .cam_pclk(cam_pclk),
    .cam_pwdn(cam_pwdn),
    .cam_rst_n(cam_rst_n),
    .cam_vsync(cam_vsync),
    .aud_mclk(aud_mclk),
    .mode_led(mode_led)
  );

endmodule
