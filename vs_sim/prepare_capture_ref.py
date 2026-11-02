# -*- coding: utf-8 -*-
"""生成等价性仿真用的参考副本（仅仿真，不参与综合、不随提交包分发）。

原厂参考文件是 GBK 编码且没有 timescale，xsim 直接编译会报
"Module ... doesn't have a timescale"，所以这里转成 UTF-8 并补一行 timescale。

用法：
    set CMOS_CAPTURE_SRC=D:\path\to\cmos_capture_data.v
    python vs_sim/prepare_capture_ref.py
    :: 或直接给参数
    python vs_sim/prepare_capture_ref.py D:\path\to\cmos_capture_data.v

产物：
    _ref/cmos_capture_data_ref.v
"""
import os
import sys

# 正点原子资料盘里的原始文件（专有代码，不随仓库分发，只在本机存在）。
# 路径由环境变量 CMOS_CAPTURE_SRC 或命令行第一个参数提供。
SRC = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("CMOS_CAPTURE_SRC", "")

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.normpath(os.path.join(HERE, "..", "_ref", "cmos_capture_data_ref.v"))


def main():
    if not SRC:
        raise SystemExit(
            "未指定原厂参考文件路径。\n"
            "该文件是开发板资料盘里的专有代码，不随本仓库分发，需要你在本机指定：\n"
            "  set CMOS_CAPTURE_SRC=D:\\path\\to\\cmos_capture_data.v\n"
            "  python vs_sim/prepare_capture_ref.py\n"
            "（没有这个文件也不影响复现，它只用于 vs_sim 的采集 IP 等价性仿真。）"
        )
    if not os.path.isfile(SRC):
        raise SystemExit("找不到原厂参考文件：\n  %s" % SRC)
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    text = open(SRC, encoding="gb18030").read()
    with open(DST, "w", encoding="utf-8", newline="\n") as f:
        f.write("`timescale 1ns / 1ps\n" + text)
    print("generated: %s" % DST)


if __name__ == "__main__":
    main()