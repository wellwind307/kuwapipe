#HDMI
set_property IOSTANDARD TMDS_33 [get_ports TMDS_clk_p]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_n[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_n[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {TMDS_data_n[2]}]
set_property -dict { PACKAGE_PIN L19   IOSTANDARD LVCMOS33} [get_ports hdmi_hpd_tri_io]
set_property -dict { PACKAGE_PIN J20   IOSTANDARD TMDS_33 } [get_ports {TMDS_data_p[2]}]
set_property -dict { PACKAGE_PIN K19   IOSTANDARD TMDS_33 } [get_ports {TMDS_data_p[1]}]
set_property -dict { PACKAGE_PIN G19   IOSTANDARD TMDS_33 } [get_ports {TMDS_data_p[0]}]
set_property -dict { PACKAGE_PIN J18   IOSTANDARD TMDS_33 } [get_ports TMDS_clk_p]
# -------------------------GPIO-------------------
#PL_KEY 
#  btns_tri_i[0]=PL_KEY0 用作"直通 / 全处理"切换键（内部上拉，极性上电自动识别）
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { btns_tri_i[0] }]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { btns_tri_i[1] }]
#TPAG 
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports { touch_tri_i }]
#BEEP  
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { beep_tri_o }]
#PL_LED 54-56
#  leds_tri_o[0]=J16 / [1]=H15 仍由 PS 的 leds_gpio 控制（leds_gpio 已改成 2 bit）
#  LED2(L15) 改成 PL 端口 mode_led：raw 直通模式下点亮
set_property -dict { PACKAGE_PIN J16 IOSTANDARD LVCMOS33 } [get_ports { leds_tri_o[0] }]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports { leds_tri_o[1] }]
set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports { mode_led }]
#----------------------HDMI DDC---------------------------
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports { hdmi_ddc_scl_io}]
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports { hdmi_ddc_sda_io}]  
#----------------------IIC1---------------------------
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { IIC_1_scl_io }]
set_property -dict { PACKAGE_PIN F17 IOSTANDARD LVCMOS33 } [get_ports { IIC_1_sda_io }]
#---------------------audio---------------------------
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports aud_adcdat]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 } [get_ports aud_lrc]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports aud_bclk]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports aud_mclk]
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports aud_dacdat]

#----------------------camera---------------------------
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports cam_href]
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports cam_pclk]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports cam_vsync]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports cam_rst_n]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports cam_pwdn]

set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {cam_data[0]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {cam_data[1]}]
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {cam_data[2]}]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {cam_data[3]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {cam_data[4]}]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {cam_data[5]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {cam_data[6]}]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports {cam_data[7]}]

#cam_scl:
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {cam_iic_scl_io}]
#cam_sda:
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {cam_iic_sda_io}] 
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]

#----------------------iop_audrino---------------------------
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {io_0_tri_io[0]}]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports {io_0_tri_io[1]}]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports {io_0_tri_io[2]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {io_0_tri_io[3]}]

set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports spi_rtl_0_io0_io]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports spi_rtl_0_io1_io]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports spi_rtl_0_sck_io]
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports spi_rtl_0_ss_io ]

#----------------------跨时钟域：模式切换信号---------------------------
# mode 是准静态控制信号（按键触发），100MHz(camera_in) -> 142MHz(hdmi_out)，
# 接收侧 video_style_bypass 里有 2 级 ASYNC_REG 同步器 -> 按 false path 处理。
set_false_path \
  -from [get_cells -hier -filter {NAME =~ "*video_mode_switch_0*mode_r_reg*"}] \
  -to   [get_cells -hier -filter {NAME =~ "*video_style_byp_0*bp_*"}]


