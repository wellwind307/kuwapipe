# -*- coding: utf-8 -*-
"""
gen_gamma_lut.py —— 生成 gamma 查找表 (256x8)，供 video_style.v 的 $readmemh 使用。

与 style_cartoon_640x480.py 的 _build_gamma_lut 完全一致：
    lut[i] = clip(round(255 * (i/255)^g), 0, 255)     g = GAMMA/100

默认 GAMMA=45 -> g=0.45（卡通提亮）。生成的文件：
    ../src/base.srcs/sources_1/new/gamma_lut.mem    （每行一个 2 位十六进制数）

用法（在本目录 sim/ 下运行）：
    python gen_gamma_lut.py [GAMMA]
"""
import os
import sys

OUT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "src", "base.srcs", "sources_1", "new", "gamma_lut.mem"))


def build_gamma_lut(g100):
    g = max(g100, 1) / 100.0
    lut = []
    for i in range(256):
        v = 255.0 * ((i / 255.0) ** g)
        v = round(v)
        v = 0 if v < 0 else (255 if v > 255 else v)
        lut.append(int(v))
    return lut


def main():
    g100 = int(sys.argv[1]) if len(sys.argv) > 1 else 45
    lut = build_gamma_lut(g100)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        for v in lut:
            f.write("%02X\n" % v)
    print("gamma = %.2f  (GAMMA=%d)" % (max(g100, 1) / 100.0, g100))
    print("wrote %d entries -> %s" % (len(lut), OUT))
    print("sample: " + " ".join("%02X" % v for v in lut[0:16]))


if __name__ == "__main__":
    main()
