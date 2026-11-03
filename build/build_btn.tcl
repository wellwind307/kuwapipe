# =============================================================================
# build_btn.tcl —— 综合 + 实现 + 生成 bitstream（按键切换版工程）
#
#   用法（在 build/ 目录下运行）：
#     cd build
#     vivado -mode batch -source build_btn.tcl
#
#   工程位置：../src（projdir 由本脚本位置自动推导，可随提交包整体搬移）
#   产物：综合/实现报告写到 ../build/，bit/hwh 复制到 ../board/bitstream/
#   （综合报告写 synth_utilization.rpt，实现报告写 impl_*.rpt）
# =============================================================================

set projdir [file normalize [file dirname [info script]]/../src]
set rptdir  [file normalize [file dirname [info script]]]
open_project ${projdir}/base.xpr

reset_run synth_1
reset_run impl_1

launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "SYNTH STATUS: [get_property STATUS [get_runs synth_1]]"

open_run synth_1
report_utilization -file ${rptdir}/synth_utilization.rpt
close_design

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "IMPL STATUS: [get_property STATUS [get_runs impl_1]]"

open_run impl_1
report_utilization    -file ${rptdir}/impl_utilization.rpt
report_timing_summary -file ${rptdir}/impl_timing_summary.rpt -max_paths 10

set bit_src ${projdir}/base.runs/impl_1/base_wrapper.bit
set hwh_src ${projdir}/base.srcs/sources_1/bd/base/hw_handoff/base.hwh
# 只保留一对 base.bit + base.hwh（PYNQ 按同名成对加载）；
# Vivado 生成的 base_wrapper.bit 只是文件名不同，内容完全一致，不再复制第二份。
if {[file exists $bit_src]} {
  file copy -force $bit_src ${projdir}/../board/bitstream/base.bit
  puts "bit copied -> board/bitstream/base.bit"
}
if {[file exists $hwh_src]} {
  file copy -force $hwh_src ${projdir}/../board/bitstream/base.hwh
  puts "hwh copied -> board/bitstream/base.hwh"
}
puts "BUILD DONE"
close_project
