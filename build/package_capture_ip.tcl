# =============================================================================
# package_capture_ip.tcl —— 把 ov5640_capture.v 打包成 IP（user:ip:ov5640_capture:1.0）
#
#   vivado -mode batch -source package_capture_ip.tcl
#
# 输出：<projdir>/ip_repo_local/ov5640_capture/
# 说明：走 IP 打包（而非 module_ref），BD 才会把该单元的 vid_clk 当作时钟源，
#       与原 alientek IP 的行为一致。
# =============================================================================

set projdir [file normalize [file dirname [info script]]/../src]
set src     ${projdir}/base.srcs/sources_1/new/ov5640_capture.v
set repo    ${projdir}/ip_repo_local
set ipdir   ${repo}/ov5640_capture

file mkdir $repo

create_project -in_memory -part xc7z020clg400-2
set_property source_mgmt_mode None [current_project]
add_files -norecurse $src

if {[file exists ${ipdir}/component.xml]} {
    file delete -force $ipdir
}

ipx::package_project -root_dir $ipdir -vendor user -library ip \
    -taxonomy /UserIP -import_files -set_current true

set core [ipx::current_core]
set_property name          ov5640_capture          $core
set_property version       1.0                     $core
set_property display_name  {OV5640 Capture}        $core
set_property description   {OV5640 DVP RGB565 to vid_io RGB888 capture front-end for PYNQ video pipeline} $core
set_property vendor_display_name {Team}            $core

ipx::create_xgui_files   $core
ipx::update_checksums    $core
ipx::check_integrity     $core
ipx::save_core           $core
close_project

puts "== IP packaged at $ipdir"
