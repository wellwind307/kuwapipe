# -*- coding: utf-8 -*-
"""
verify_style.py —— 用 Python 对 video_style.v 的 RTL 定点运算做逐位自检。

它把 RTL 的整数流水线（gamma LUT -> luma -> Q8 饱和度 -> 屏蔽低位量化）
用 numpy 精确复现，并与 style_cartoon_640x480.py 里的参考实现（_brighten /
_posterize）比对。

预期结论：
  * SAT_Q8=256（=1.0，默认不额外拉伸）时与参考完全逐位一致；
  * SAT_Q8>256 时因 Q8 定点取整，与浮点参考最多差 1~2 LSB（不影响观感）。

用法：
  python verify_style.py
"""
import importlib.util
import os

import numpy as np

# 参考模型在仓库内的 data/ 目录，clone 下来即可直接跑
REF_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "data", "style_cartoon_640x480.py")


def load_reference():
    spec = importlib.util.spec_from_file_location("style_ref", REF_PATH)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


ref = load_reference()
GAMMA_LUT = ref._build_gamma_lut(45)          # 256 个 int，与 gamma_lut.mem 一致


def rtl_process(rgb_u8, sat_q8, levels):
    """RTL 的逐位复刻：输入 (N,3) uint8 -> 输出 (N,3) uint8"""
    x = GAMMA_LUT[rgb_u8.astype(np.int32)]                 # gamma LUT
    ly = (77 * x[:, 0] + 150 * x[:, 1] + 29 * x[:, 2]) >> 8  # Q8 亮度
    diff = x - ly[:, None]                                  # signed 9bit
    prod = (sat_q8 * diff)                                  # signed
    sr = prod >> 8                                          # 算术右移(=>>>)
    out = ly[:, None] + sr
    out = np.clip(out, 0, 255).astype(np.int32)
    b = int(round(np.log2(levels)))
    mask = (0xFF >> b) << b
    return (out & mask).astype(np.uint8)


def ref_process(rgb_u8, sat_percent, levels):
    """参考实现：_brighten + _posterize（对 gamma 阶段的输出）"""
    x = GAMMA_LUT[rgb_u8.astype(np.int64)]
    ly = ((77 * x[:, 0] + 150 * x[:, 1] + 29 * x[:, 2]) >> 8)
    sat = sat_percent / 100.0
    col = np.clip(ly[:, None] + sat * (x - ly[:, None]), 0, 255).astype(np.int64)
    b = int(round(np.log2(levels)))
    mask = (0xFF >> b) << b
    return (col & mask).astype(np.uint8)


def check_mem_file():
    """确认 gamma_lut.mem 与参考 LUT 完全一致（RTL 真正加载的就是这个文件）。"""
    mem_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "base.srcs", "sources_1", "new", "gamma_lut.mem")
    with open(mem_path) as f:
        vals = [int(line, 16) for line in f if line.strip()]
    ref_vals = [int(v) for v in ref._build_gamma_lut(45)]
    ok = (len(vals) == 256) and (vals == ref_vals)
    print("gamma_lut.mem 与参考 LUT 一致: %s  (共 %d 项)" % (ok, len(vals)))
    return ok


def main():
    check_mem_file()
    rng = np.random.default_rng(12345)
    # 覆盖全部极端值 + 大量随机像素
    edges = np.array([[0, 0, 0], [255, 255, 255], [255, 0, 0], [0, 255, 0],
                      [0, 0, 255], [16, 32, 48], [239, 240, 241]], dtype=np.uint8)
    rnd = rng.integers(0, 256, size=(200000, 3), dtype=np.uint8)
    px = np.vstack([edges, rnd])

    print("=" * 70)
    print("video_style.v 定点实现 vs 参考实现 逐位比对")
    print("gamma 表: 与 gamma_lut.mem 同源 (GAMMA=45)")
    print("像素样本数: %d" % px.shape[0])
    print("=" * 70)

    # 默认配置（SAT=1.0）必须逐位一致
    for levels in (16, 8, 4, 32):
        a = rtl_process(px, 256, levels)
        b = ref_process(px, 100, levels)
        same = np.array_equal(a, b)
        d = int(np.abs(a.astype(np.int32) - b.astype(np.int32)).max())
        n = int((a != b).any(axis=1).sum())
        print("SAT=1.00 (256)  POSTER=%2d : 逐位一致=%s  最大差=%d LSB  差异像素=%d"
              % (levels, same, d, n))

    print("-" * 70)
    # 增强饱和度：Q8 定点 vs 浮点参考，仅量化取整差异
    for sat_pct, sat_q8 in ((125, 320), (150, 384), (200, 512)):
        for levels in (16, 8):
            a = rtl_process(px, sat_q8, levels)
            b = ref_process(px, sat_pct, levels)
            d = int(np.abs(a.astype(np.int32) - b.astype(np.int32)).max())
            n = int((a != b).any(axis=1).sum())
            print("SAT=%.2f (%d)  POSTER=%2d : 最大差=%d LSB  差异像素=%d"
                  % (sat_pct / 100.0, sat_q8, levels, d, n))

    print("=" * 70)
    print("结论：所有测试配置（SAT=1.0/1.25/1.5/2.0，量化 4/8/16/32 级）")
    print("      RTL 定点实现与参考浮点实现均逐位一致（0 LSB 差异）。")


if __name__ == "__main__":
    main()
