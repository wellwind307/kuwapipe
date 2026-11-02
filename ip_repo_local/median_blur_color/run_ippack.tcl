# ==============================================================
# Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2025.2 (64-bit)
# Tool Version Limit: 2025.11
# Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
# Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
# 
# ==============================================================
# 说明：本文件由 Vitis HLS 自动生成，用于把 median_blur_color 重新打包成 IP。
#       原文件里写死了作者机器的路径，这里改成由变量提供；
#       仓库里 ip_repo_local/median_blur_color/ 已经含打包好的成品，
#       只有你自己改了 HLS 源码、想重新打包时才需要运行它。
#
# 用法（先按本机情况改下面三行）：
#   set VITIS_IPXHLS "C:/Xilinx/Vitis/<版本>/common/scripts/ipxhls.tcl"
#   set ip_out_dir   "<你的 HLS 工程>/solution1/impl/ip"
#   set data_file    "<你的 HLS 工程>/solution1/solution1_data.json"

source -notrace $VITIS_IPXHLS
set src_dir [file dir $data_file]
set ip_types {vitis sysgen}
set ippack_opts_dict {}
if { [catch {::ipx::utils::package_hls_ip $ip_out_dir $data_file $ip_types $src_dir $ippack_opts_dict} res] } {
  puts "Caught error:\n$::errorInfo"
  error $res
}
