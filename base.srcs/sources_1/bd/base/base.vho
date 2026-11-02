-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
-- -------------------------------------------------------------------------------
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
-- DO NOT MODIFY THIS FILE.

-- MODULE VLNV: amd.com:blockdesign:base:1.0

-- The following code must appear in the VHDL architecture header.

-- COMP_TAG     ------ Begin cut for COMPONENT Declaration ------
COMPONENT base
  PORT (
    btns_tri_i : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    DDR_cas_n : INOUT STD_LOGIC;
    DDR_cke : INOUT STD_LOGIC;
    DDR_ck_n : INOUT STD_LOGIC;
    DDR_ck_p : INOUT STD_LOGIC;
    DDR_cs_n : INOUT STD_LOGIC;
    DDR_reset_n : INOUT STD_LOGIC;
    DDR_odt : INOUT STD_LOGIC;
    DDR_ras_n : INOUT STD_LOGIC;
    DDR_we_n : INOUT STD_LOGIC;
    DDR_ba : INOUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    DDR_addr : INOUT STD_LOGIC_VECTOR(14 DOWNTO 0);
    DDR_dm : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    DDR_dq : INOUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    DDR_dqs_n : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    DDR_dqs_p : INOUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    FIXED_IO_mio : INOUT STD_LOGIC_VECTOR(53 DOWNTO 0);
    FIXED_IO_ddr_vrn : INOUT STD_LOGIC;
    FIXED_IO_ddr_vrp : INOUT STD_LOGIC;
    FIXED_IO_ps_srstb : INOUT STD_LOGIC;
    FIXED_IO_ps_clk : INOUT STD_LOGIC;
    FIXED_IO_ps_porb : INOUT STD_LOGIC;
    IIC_1_sda_i : IN STD_LOGIC;
    IIC_1_sda_o : OUT STD_LOGIC;
    IIC_1_sda_t : OUT STD_LOGIC;
    IIC_1_scl_i : IN STD_LOGIC;
    IIC_1_scl_o : OUT STD_LOGIC;
    IIC_1_scl_t : OUT STD_LOGIC;
    Vp_Vn_v_n : IN STD_LOGIC;
    Vp_Vn_v_p : IN STD_LOGIC;
    beep_tri_o : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    cam_iic_scl_i : IN STD_LOGIC;
    cam_iic_scl_o : OUT STD_LOGIC;
    cam_iic_scl_t : OUT STD_LOGIC;
    cam_iic_sda_i : IN STD_LOGIC;
    cam_iic_sda_o : OUT STD_LOGIC;
    cam_iic_sda_t : OUT STD_LOGIC;
    hdmi_ddc_sda_i : IN STD_LOGIC;
    hdmi_ddc_sda_o : OUT STD_LOGIC;
    hdmi_ddc_sda_t : OUT STD_LOGIC;
    hdmi_ddc_scl_i : IN STD_LOGIC;
    hdmi_ddc_scl_o : OUT STD_LOGIC;
    hdmi_ddc_scl_t : OUT STD_LOGIC;
    leds_tri_o : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    touch_tri_i : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    spi_rtl_0_io0_i : IN STD_LOGIC;
    spi_rtl_0_io0_o : OUT STD_LOGIC;
    spi_rtl_0_io0_t : OUT STD_LOGIC;
    spi_rtl_0_io1_i : IN STD_LOGIC;
    spi_rtl_0_io1_o : OUT STD_LOGIC;
    spi_rtl_0_io1_t : OUT STD_LOGIC;
    spi_rtl_0_sck_i : IN STD_LOGIC;
    spi_rtl_0_sck_o : OUT STD_LOGIC;
    spi_rtl_0_sck_t : OUT STD_LOGIC;
    spi_rtl_0_ss_i : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    spi_rtl_0_ss_o : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    spi_rtl_0_ss_t : OUT STD_LOGIC;
    io_0_tri_o : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    io_0_tri_t : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    io_0_tri_i : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    hdmi_hpd_tri_i : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    hdmi_hpd_tri_o : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    hdmi_hpd_tri_t : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    TMDS_clk_p : OUT STD_LOGIC;
    TMDS_clk_n : OUT STD_LOGIC;
    TMDS_data_p : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    TMDS_data_n : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    aud_adcdat : IN STD_LOGIC;
    aud_bclk : OUT STD_LOGIC;
    aud_dacdat : OUT STD_LOGIC;
    aud_lrc : OUT STD_LOGIC;
    cam_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    cam_href : IN STD_LOGIC;
    cam_pclk : IN STD_LOGIC;
    cam_pwdn : OUT STD_LOGIC;
    cam_rst_n : OUT STD_LOGIC;
    cam_vsync : IN STD_LOGIC;
    aud_mclk : OUT STD_LOGIC;
    mode_led : OUT STD_LOGIC
  );
END COMPONENT;
-- COMP_TAG_END ------  End cut for COMPONENT Declaration  ------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

-- INST_TAG     ------ Begin cut for INSTANTIATION Template ------
your_instance_name : base
  PORT MAP (
    btns_tri_i => btns_tri_i,
    DDR_cas_n => DDR_cas_n,
    DDR_cke => DDR_cke,
    DDR_ck_n => DDR_ck_n,
    DDR_ck_p => DDR_ck_p,
    DDR_cs_n => DDR_cs_n,
    DDR_reset_n => DDR_reset_n,
    DDR_odt => DDR_odt,
    DDR_ras_n => DDR_ras_n,
    DDR_we_n => DDR_we_n,
    DDR_ba => DDR_ba,
    DDR_addr => DDR_addr,
    DDR_dm => DDR_dm,
    DDR_dq => DDR_dq,
    DDR_dqs_n => DDR_dqs_n,
    DDR_dqs_p => DDR_dqs_p,
    FIXED_IO_mio => FIXED_IO_mio,
    FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
    FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
    FIXED_IO_ps_clk => FIXED_IO_ps_clk,
    FIXED_IO_ps_porb => FIXED_IO_ps_porb,
    IIC_1_sda_i => IIC_1_sda_i,
    IIC_1_sda_o => IIC_1_sda_o,
    IIC_1_sda_t => IIC_1_sda_t,
    IIC_1_scl_i => IIC_1_scl_i,
    IIC_1_scl_o => IIC_1_scl_o,
    IIC_1_scl_t => IIC_1_scl_t,
    Vp_Vn_v_n => Vp_Vn_v_n,
    Vp_Vn_v_p => Vp_Vn_v_p,
    beep_tri_o => beep_tri_o,
    cam_iic_scl_i => cam_iic_scl_i,
    cam_iic_scl_o => cam_iic_scl_o,
    cam_iic_scl_t => cam_iic_scl_t,
    cam_iic_sda_i => cam_iic_sda_i,
    cam_iic_sda_o => cam_iic_sda_o,
    cam_iic_sda_t => cam_iic_sda_t,
    hdmi_ddc_sda_i => hdmi_ddc_sda_i,
    hdmi_ddc_sda_o => hdmi_ddc_sda_o,
    hdmi_ddc_sda_t => hdmi_ddc_sda_t,
    hdmi_ddc_scl_i => hdmi_ddc_scl_i,
    hdmi_ddc_scl_o => hdmi_ddc_scl_o,
    hdmi_ddc_scl_t => hdmi_ddc_scl_t,
    leds_tri_o => leds_tri_o,
    touch_tri_i => touch_tri_i,
    spi_rtl_0_io0_i => spi_rtl_0_io0_i,
    spi_rtl_0_io0_o => spi_rtl_0_io0_o,
    spi_rtl_0_io0_t => spi_rtl_0_io0_t,
    spi_rtl_0_io1_i => spi_rtl_0_io1_i,
    spi_rtl_0_io1_o => spi_rtl_0_io1_o,
    spi_rtl_0_io1_t => spi_rtl_0_io1_t,
    spi_rtl_0_sck_i => spi_rtl_0_sck_i,
    spi_rtl_0_sck_o => spi_rtl_0_sck_o,
    spi_rtl_0_sck_t => spi_rtl_0_sck_t,
    spi_rtl_0_ss_i => spi_rtl_0_ss_i,
    spi_rtl_0_ss_o => spi_rtl_0_ss_o,
    spi_rtl_0_ss_t => spi_rtl_0_ss_t,
    io_0_tri_o => io_0_tri_o,
    io_0_tri_t => io_0_tri_t,
    io_0_tri_i => io_0_tri_i,
    hdmi_hpd_tri_i => hdmi_hpd_tri_i,
    hdmi_hpd_tri_o => hdmi_hpd_tri_o,
    hdmi_hpd_tri_t => hdmi_hpd_tri_t,
    TMDS_clk_p => TMDS_clk_p,
    TMDS_clk_n => TMDS_clk_n,
    TMDS_data_p => TMDS_data_p,
    TMDS_data_n => TMDS_data_n,
    aud_adcdat => aud_adcdat,
    aud_bclk => aud_bclk,
    aud_dacdat => aud_dacdat,
    aud_lrc => aud_lrc,
    cam_data => cam_data,
    cam_href => cam_href,
    cam_pclk => cam_pclk,
    cam_pwdn => cam_pwdn,
    cam_rst_n => cam_rst_n,
    cam_vsync => cam_vsync,
    aud_mclk => aud_mclk,
    mode_led => mode_led
  );
-- INST_TAG_END ------  End cut for INSTANTIATION Template  ------

-- You must compile the wrapper file base.vhd when simulating
-- the module, base. When compiling the wrapper file, be sure to
-- reference the VHDL simulation library.
