# =============================================================================
# modify_btn.tcl —— 给 Kuwahara 工程加"按键在 直通 / 全处理 之间切换"
#
# 改动：
#   1) /video/camera_in 插入 video_mode_switch_0：
#        axis_register_slice_0/M_AXIS -> switch/s_axis
#        switch/m_proc                -> median_blur_color_0/video_in
#        video_kuwahara_0/m_axis      -> switch/s_proc
#        switch/m_axis                -> pixel_pack/stream_in_24
#   2) 按键 PL_KEY0 (btns_tri_i[0]) -> xlslice 取 bit0 -> /video/btn -> camera_in/btn
#   3) /video/mode -> hdmi_out/bypass（video_style 运行期旁路）
#                     -> 顶层新端口 mode_led（PL_LED2 物理引脚 L15 指示 raw 模式）
#   4) hdmi_out 里把 video_style_0 换成带 bypass 端口的新 cell（video_style_bp_0）
#   5) leds_gpio 从 3 bit 改 2 bit（PS 仍控 LED0/LED1；LED2 让给 PL）
#
# 可重复执行（已连过的都跳过）。
# 用法： vivado -mode batch -source modify_btn.tcl
# =============================================================================

set projdir [file normalize [file dirname [info script]]/../src]
set logfile "${projdir}/../build/modify_btn.log"

set fh [open $logfile w]
proc p {args} {
    global fh
    set line [join $args " "]
    puts $fh $line
    puts $line
    flush $fh
}
proc pp {args} { puts [join $args " "] }

# 幂等：只有还没连才连
proc cnet {a b} {
    set pa [get_bd_pins -quiet $a]
    set pb [get_bd_pins -quiet $b]
    if {[llength $pa] == 0 || [llength $pb] == 0} { pp "  !! pin not found: $a / $b"; return }
    if {[llength [get_bd_nets -quiet -of_objects $pa]] == 0} {
        connect_bd_net $pa $pb
        pp "  net  $a <- $b"
    } else { pp "  net  $a (exists)" }
}
proc cintf {a b} {
    set pa [get_bd_intf_pins -quiet $a]
    set pb [get_bd_intf_pins -quiet $b]
    if {[llength $pa] == 0 || [llength $pb] == 0} { pp "  !! intf not found: $a / $b"; return }
    if {[llength [get_bd_intf_nets -quiet -of_objects $pa]] == 0} {
        connect_bd_intf_net $pa $pb
        pp "  intf $a <-> $b"
    } else { pp "  intf $a (exists)" }
}

p "===== modify_btn start ====="
open_project ${projdir}/base.xpr
p "project opened"

# ---------------------------------------------------------------- 1) RTL
add_files -norecurse [list ${projdir}/base.srcs/sources_1/new/video_mode_switch.v ]
update_compile_order -fileset sources_1
p "added video_mode_switch.v"

open_bd_design [get_files *.bd]
p "bd opened"

# ================================================================ 2) camera_in
current_bd_instance /video/camera_in

if {[llength [get_bd_cells -quiet video_mode_switch_0]] == 0} {
    create_bd_cell -type module -reference video_mode_switch video_mode_switch_0
    p "created video_mode_switch_0"
} else { p "video_mode_switch_0 exists" }
set_property -dict [list CONFIG.CLK_HZ {100000000} CONFIG.DEBOUNCE_MS {20} \
                         CONFIG.SETTLE_MS {100} CONFIG.AUTO_POL {1}] \
                    [get_bd_cells video_mode_switch_0]

foreach n {axis_register_slice_0_M_AXIS video_kuwahara_0_m_axis} {
    if {[get_bd_intf_nets -quiet $n] ne ""} {
        delete_bd_objs [get_bd_intf_nets $n]
        p "deleted intf net $n"
    }
}
cintf axis_register_slice_0/M_AXIS video_mode_switch_0/s_axis
cintf video_mode_switch_0/m_proc   median_blur_color_0/video_in
cintf video_kuwahara_0/m_axis      video_mode_switch_0/s_proc
cintf video_mode_switch_0/m_axis   pixel_pack/stream_in_24
p "camera_in axis chain rewired"

cnet video_mode_switch_0/aclk    median_blur_color_0/ap_clk
cnet video_mode_switch_0/aresetn median_blur_color_0/ap_rst_n

if {[llength [get_bd_pins -quiet btn]] == 0} {
    create_bd_pin -dir I -type data btn
    p "created pin camera_in/btn"
}
cnet btn video_mode_switch_0/btn

if {[llength [get_bd_pins -quiet mode]] == 0} {
    create_bd_pin -dir O -type data mode
    p "created pin camera_in/mode"
}
cnet video_mode_switch_0/mode mode

# ================================================================ 3) /video
current_bd_instance /video

if {[llength [get_bd_pins -quiet btn]] == 0}  { create_bd_pin -dir I -type data btn }
if {[llength [get_bd_pins -quiet mode]] == 0} { create_bd_pin -dir O -type data mode }
cnet btn  camera_in/btn
cnet mode camera_in/mode
p "/video pins btn/mode routed"

# ================================================================ 4) hdmi_out
current_bd_instance /video/hdmi_out

if {[llength [get_bd_pins -quiet bypass]] == 0} {
    create_bd_pin -dir I -type data bypass
    p "created pin hdmi_out/bypass"
}

if {[llength [get_bd_cells -quiet video_style_bp_0]] == 0} {
    foreach n {color_convert_stream_out_24 video_style_0_m_axis} {
        if {[get_bd_intf_nets -quiet $n] ne ""} {
            delete_bd_objs [get_bd_intf_nets $n]
            p "deleted intf net $n"
        }
    }
    if {[llength [get_bd_cells -quiet video_style_0]] > 0} {
        delete_bd_objs [get_bd_cells video_style_0]
        p "deleted old video_style_0"
    }
    create_bd_cell -type module -reference video_style video_style_bp_0
    set_property -dict [list CONFIG.ENABLE {1} CONFIG.GAMMA {45} \
                             CONFIG.SAT_Q8 {256} CONFIG.POSTER_LEVELS {16}] \
                        [get_bd_cells video_style_bp_0]
    p "created video_style_bp_0 (with bypass port)"
} else { p "video_style_bp_0 exists" }

cintf color_convert/stream_out_24 video_style_bp_0/s_axis
cintf video_style_bp_0/m_axis     frontend/video_in
cnet  video_style_bp_0/aclk      color_convert/ap_clk
cnet  video_style_bp_0/aresetn   color_convert/ap_rst_n
cnet  bypass                     video_style_bp_0/bypass

# ================================================================ 5) 顶层
current_bd_instance /

if {[llength [get_bd_cells -quiet btn_sl]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 btn_sl
    set_property -dict [list CONFIG.DIN_WIDTH {2} CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0}] \
                        [get_bd_cells btn_sl]
    p "created btn_sl"
}
if {[llength [get_bd_nets -quiet -of_objects [get_bd_ports btns_tri_i]]] == 0} {
    connect_bd_net [get_bd_ports btns_tri_i] [get_bd_pins /btn_sl/Din]
    p "btns_tri_i -> btn_sl/Din"
}
cnet /btn_sl/Dout /video/btn

if {[llength [get_bd_ports -quiet mode_led]] == 0} {
    create_bd_port -dir O mode_led
    p "created port mode_led"
}
if {[llength [get_bd_nets -quiet -of_objects [get_bd_ports mode_led]]] == 0} {
    connect_bd_net [get_bd_pins /video/mode] [get_bd_ports mode_led]
    p "/video/mode -> mode_led"
}
cnet /video/mode /video/hdmi_out/bypass

# ================================================================ 6) LED 让出 LED2
set_property CONFIG.C_GPIO_WIDTH {2} [get_bd_cells leds_gpio]
p "leds_gpio width -> 2 (PS keeps LED0/LED1; LED2 = mode_led)"

# ================================================================ 7) validate/save/gen
p "===== validate ====="
set rc [catch {validate_bd_design -force} vmsg]
p "validate_bd_design rc=$rc"
p $vmsg

if {$rc == 0} {
    save_bd_design
    p "BD saved"
    set g [catch {generate_target all [get_files *.bd]} gmsg]
    p "generate_target rc=$g"
    if {$g != 0} { p $gmsg }
}
p "===== modify_btn done ====="
close $fh
close_project
