# =============================================================================
# modify_capture.tcl —— 用自研 ov5640_capture 替换 alientek cmos_capture_data
#
#   vivado -mode batch -source modify_capture.tcl
#
# 做法：记录旧单元每个引脚的对端 -> 删除旧单元 -> 新建 module_ref 单元
#       -> 按原对端接回（含 cmos_rgb 接口与 PixelClk/vid_io_in_clk 共网）
# 可重复执行：若已存在 ov5640_capture_0 则先删掉重建。
# =============================================================================

set projdir [file normalize [file dirname [info script]]]
set new_src ${projdir}/base.srcs/sources_1/new/ov5640_capture.v
set local_repo ${projdir}/ip_repo_local

open_project ${projdir}/base.xpr

# ---- 0. IP 仓库：保留原有仓库，追加本地仓库 ----
set repos [get_property ip_repo_paths [current_project]]
if {[lsearch -exact $repos $local_repo] < 0} {
    set repos [concat $repos [list $local_repo]]
    set_property ip_repo_paths $repos [current_project]
}
update_ip_catalog -rebuild
puts "== ip repos: [get_property ip_repo_paths [current_project]]"

# ---- 1. 源码入库 ----
if {[llength [get_files -quiet $new_src]] == 0} {
    add_files -norecurse $new_src
    puts "== source added"
} else {
    puts "== source already in project"
}
update_compile_order -fileset sources_1

# ---- 2. 打开 BD ----
open_bd_design [get_files base.bd]

set hier /video/camera_in/frontend
set old  ${hier}/cmos_capture_data_0
set new  ${hier}/ov5640_capture_0

# ---- 3. 记录旧单元连接关系 ----
set old_cell [get_bd_cells $old]
if {[llength $old_cell] == 0} {
    error "old cell not found: $old"
}

array set peers {}
foreach p [get_bd_pins -of_objects $old_cell] {
    set nm [get_property NAME $p]
    set n  [get_bd_nets -quiet -of_objects $p]
    set lst {}
    if {$n ne ""} {
        foreach q [get_bd_pins -quiet -of_objects $n] {
            if {[get_property NAME $q] ne $nm} { lappend lst $q }
        }
    }
    set peers($nm) $lst
    puts "== old pin [get_property NAME $p] -> $lst"
}

set old_intf [get_bd_intf_pins -quiet ${old}/cmos_rgb]
set intf_peer {}
if {$old_intf ne ""} {
    set inet [get_bd_intf_nets -quiet -of_objects $old_intf]
    if {$inet ne ""} {
        foreach q [get_bd_intf_pins -quiet -of_objects $inet] {
            if {[get_property NAME $q] ne [get_property NAME $old_intf]} { lappend intf_peer $q }
        }
    }
}
puts "== old interface peer: $intf_peer"

# ---- 4. 删除旧单元 ----
delete_bd_objs $old_cell
set new_cell [get_bd_cells -quiet $new]
if {[llength $new_cell]} {
    delete_bd_objs $new_cell
}
puts "== old cell removed"

# ---- 5. 新建单元（在 frontend 层次内）----
current_bd_instance ${hier}
create_bd_cell -type ip -vlnv user:ip:ov5640_capture:1.0 ov5640_capture_0
current_bd_instance /
puts "== new cell created: $new"

# ---- 6. 接线 ----
proc safe_net {peer_list pin_path} {
    set pin [get_bd_pins -quiet $pin_path]
    if {[llength $pin] == 0} {
        puts "   (no such pin) $pin_path"
        return
    }
    if {[llength $peer_list] == 0} {
        puts "   (skip, no peer) $pin_path"
        return
    }
    connect_bd_net {*}$peer_list $pin
    puts "   connected [get_property NAME $pin] <- $peer_list"
}

safe_net $peers(cam_pclk)   ${new}/cam_pclk
safe_net $peers(cam_vsync)  ${new}/cam_vsync
safe_net $peers(cam_href)   ${new}/cam_href
safe_net $peers(cam_data)   ${new}/cam_data
safe_net $peers(cam_rst_n)  ${new}/cam_rst_n
safe_net $peers(cam_pwdn)   ${new}/cam_pwdn
safe_net $peers(rst_n)      ${new}/rst_n
safe_net $peers(cmos_frame_clk) ${new}/vid_clk
safe_net $peers(cmos_frame_ce)  ${new}/vid_ce

if {[llength $intf_peer]} {
    connect_bd_intf_net [get_bd_intf_pins ${new}/cmos_rgb] {*}$intf_peer
    puts "== cmos_rgb connected to $intf_peer"
} else {
    error "interface peer not found"
}

# ---- 7. 校验并保存 ----
if {[catch {validate_bd_design} msg]} {
    puts "!! VALIDATE FAILED: $msg"
    puts "!! BD 未保存，工程保持原样"
    close_project
    exit 1
}
save_bd_design
puts "== bd saved"

# ---- 8. 移除旧 IP 的 xci 登记（文件保留在磁盘，可回退）----
set old_xci [get_files -quiet *base_cmos_capture_data_0_1.xci]
if {[llength $old_xci]} {
    remove_files $old_xci
    puts "== old IP xci removed from project: $old_xci"
}
update_compile_order -fileset sources_1

close_project
puts "== DONE"
