# -*- coding: utf-8 -*-
"""生成等价性仿真用的参考副本（仅仿真，不参与综合、不随提交包分发）。

原厂参考文件是 GBK 编码且没有 timescale，xsim 直接编译会报
"Module ... doesn't have a timescale"，所以这里转成 UTF-8 并补一行 timescale。

用法（在本目录 sim\\ 下运行）：
    python prepare_capture_ref.py

原厂文件不在本仓库（无再分发许可），需本机已装开发板资料盘；
也可以用环境变量 KW_CAPTURE_REF_SRC 指定路径。

产物：
    sim/_ref/cmos_capture_data_ref.v
"""
import os

# 正点原子资料盘里的原始文件（仅本机存在，可用环境变量覆盖）
SRC = os.environ.get(
    "KW_CAPTURE_REF_SRC",
    r"D:\my_big_file\FPGA\ip_repo\cmos_sensor\SRC\cmos_capture_data.v",
)

HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.path.normpath(os.path.join(HERE, "_ref", "cmos_capture_data_ref.v"))


def main():
    if not os.path.isfile(SRC):
        raise SystemExit(
            "找不到原厂参考文件：\n  %s\n"
            "该文件不随本工程分发（无再分发许可），请确认本机已安装开发板资料盘，"
            "或用环境变量 KW_CAPTURE_REF_SRC 指定路径。" % SRC
        )
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    with open(SRC, encoding="gb18030") as f:
        text = f.read()
    with open(DST, "w", encoding="utf-8", newline="\n") as f:
        f.write("`timescale 1ns / 1ps\n" + text)
    print("generated: %s" % DST)


if __name__ == "__main__":
    main()
