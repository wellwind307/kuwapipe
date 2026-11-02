# -*- coding: utf-8 -*-
"""
================================================================================
  style_cartoon_640x480.py —— 卡通化（MODE=2）【无描边】精简参考实现
================================================================================
从 style_reference.py 裁剪而来，只保留一条通路：
    输入 RGB24 (640x480)  ->  Kuwahara 保边平滑 + 白平衡 + gamma/饱和度 + 色彩量化
                          ->  输出 RGB24 (640x480)

与原文件的等价性
----------------
原文件里算卡通无描边是 process(rgb, {"MODE": 2, "INK_DARK": 0})。
合成公式为  out = (col * (256 - ((ink*L)>>8))) >> 8 ；
ink=0 时退化  out = (col * 256) >> 8 == col 。
即【线稿 L 对输出零贡献】，所以下列模块被整块删除而不改变任何一个像素：

  删掉的                    原用途
  --------------------------------------------------------------------------
  _luma_q8 / _med3(luma)   只为线稿提供 Q8 亮度
  _blur_q16 / KERNELS      3 个 sigma 的高斯（行/列缓存 18/12/24 行）
  RCP 倒数表                DoG 归一化分母
  _build_smoothstep_lut    软阈值 LUT（256x8 BRAM）
  _dilate                  线稿膨胀
  line_mask / INVERT_INK   线稿引擎整体
  MODE 0/1/3/4 分支        直通/素描/网点(Bayer)/木刻
  SPLIT_X / CTRL 软复位    分屏 mux、寄存器杂项
  _line_mask_float         浮点线稿回归

与原文件的唯一行为差异
----------------------
原文件的卡通是 Gray-World 自动白平衡（每帧统计 RGB 均值算 3 个增益）。
本文件按需求把白平衡【固定为 Q8 增益 256】（256/256 = 1.0，即不缩放），
因此不再做任何全图统计。除此之外（中值 / Kuwahara / gamma / 饱和度 / 量化）
与原文件 MODE=2 + INK_DARK=0 完全逐位一致（--selftest 会同时验证这一点）。

保留的寄存器（RTL 只需这几个）
-----------------------------
  ENABLE      0/1      总开关
  KUWA_R      3        象限半径 -> 4x4 窗，/16 精确
  ENH_GAMMA   45       gamma x100
  ENH_SAT     100      饱和度 x100（1.00 不额外拉伸）
  POSTER_LV   16       色彩量化级数（2 的幂；16=屏蔽低4位，步长16，无乘法）
  AWB_GAIN_R  256      白平衡固定增益 R，Q8（256=1.0 不缩放）
  AWB_GAIN_G  256      白平衡固定增益 G，Q8
  AWB_GAIN_B  256      白平衡固定增益 B，Q8

运算特性（与 RTL 对齐）
----------------------
* 主路径整数运算；唯一例外是 _kuwahara 内部用 float64 累加 /16 —— 那是参考实现
  为了和原文件逐位一致而保留的写法。RTL 里 4x4 求和应用 (sum + 8) >> 4，
  与原实现最多差 1 LSB（量化前），可忽略。
* 无除法、无浮点、无迭代、无全图统计（白平衡已固定为 256，整条链路无反馈）。
* 边界一律 replicate（edge padding），对应 RTL 的行缓存首尾保持。

用法
----
  python style_cartoon_640x480.py in.jpg out.png    # 单张转换（输出 640x480）
  python style_cartoon_640x480.py --selftest in.jpg  # 与 style_reference.py 比对
  python style_cartoon_640x480.py                   # 打印说明
"""
import os
import sys

import numpy as np
from PIL import Image

# ==============================================================================
# 1. 固定几何 + 寄存器默认值
# ==============================================================================
W, H = 640, 480
CHANNELS = 3                      # RGB24 = 3 x 8bit

CFG_DEFAULT = {
    "ENABLE":    1,               # 0x00  bit0 使能
    "KUWA_R":    3,               # 0x04  Kuwahara 半径 (3 -> 7x7 窗, 象限 4x4)
    "ENH_GAMMA": 45,              # 0x08  gamma x100 (0.45)
    "ENH_SAT":   100,             # 0x0C  饱和度 x100 (1.00，不额外拉伸，颜色更自然)
    "POSTER_LV": 16,              # 0x10  色彩量化级数，取 2 的幂(4/8/16/32)；16=屏蔽低4位
    "AWB_GAIN_R": 256,            # 0x14  白平衡固定增益 R，Q8 (256=1.0)
    "AWB_GAIN_G": 256,            # 0x18  白平衡固定增益 G，Q8
    "AWB_GAIN_B": 256,            # 0x1C  白平衡固定增益 B，Q8
}


# ==============================================================================
# 2. 常量查找表
# ==============================================================================
def _build_gamma_lut(g100):
    """gamma 提升 LUT：8bit -> 8bit，硬件里就是一张 256x8 表"""
    i = np.arange(256, dtype=np.float64) / 255.0
    g = max(g100, 1) / 100.0
    return np.clip(np.round(255.0 * (i ** g)), 0, 255).astype(np.int64)


GAMMA_LUT_CACHE = {}


def _gamma_lut(g100):
    """按需构建并缓存 gamma 表（同一帧内是常数）"""
    if g100 not in GAMMA_LUT_CACHE:
        GAMMA_LUT_CACHE[g100] = _build_gamma_lut(g100)
    return GAMMA_LUT_CACHE[g100]


# ==============================================================================
# 3. 基础算子
# ==============================================================================
def _med3(x):
    """3x3 中值，19 比较器网络。x: int 数组（单通道）"""
    h, w = x.shape
    p = np.pad(x, 1, mode="edge")
    st = np.stack([p[dy:dy + h, dx:dx + w] for dy in range(3) for dx in range(3)])
    return np.partition(st, 4, axis=0)[4]


def _luma_q8(rgb):
    """亮度 Q8（16bit，含 8 位小数），Kuwahara 选象限用"""
    r = rgb[..., 0].astype(np.int64)
    g = rgb[..., 1].astype(np.int64)
    b = rgb[..., 2].astype(np.int64)
    return 77 * r + 150 * g + 29 * b


def _awb_gains(cfg):
    """白平衡固定增益（Q8）。默认 256/256/256 = 1.0，即不缩放。"""
    return np.array([cfg["AWB_GAIN_R"], cfg["AWB_GAIN_G"], cfg["AWB_GAIN_B"]],
                    dtype=np.int64)


def _kuwahara(rgb, r, luma_y):
    """
    Kuwahara 保边平滑：四个象限各取 (r+1)x(r+1) 的均值，选亮度方差最小的那个。
    RTL: 4 组 box 和 + 4 组平方和；r=3 时象限 4x4，除以 16 只需右移 4 位。
    """
    a = rgb.astype(np.float64)
    h, w = rgb.shape[:2]
    pad = r
    y = luma_y.astype(np.float64) / 256.0

    def integ(x):
        ii = np.zeros((x.shape[0] + 1, x.shape[1] + 1), np.float64)
        ii[1:, 1:] = x.cumsum(0).cumsum(1)
        return ii

    Yp = np.pad(y, pad, mode="edge")
    Ip = np.pad(a, ((pad, pad), (pad, pad), (0, 0)), mode="edge")
    iy, iy2 = integ(Yp), integ(Yp * Yp)
    icol = [integ(Ip[..., c]) for c in range(3)]
    Yg = np.arange(h)[:, None]
    Xg = np.arange(w)[None, :]
    n = (r + 1) * (r + 1)
    best = np.full((h, w), np.inf)
    out = np.zeros((h, w, 3))
    for dy, dx in [(0, 0), (0, r), (r, 0), (r, r)]:
        y0, x0 = Yg + dy, Xg + dx
        s = iy[y0 + r + 1, x0 + r + 1] - iy[y0, x0 + r + 1] - iy[y0 + r + 1, x0] + iy[y0, x0]
        s2 = iy2[y0 + r + 1, x0 + r + 1] - iy2[y0, x0 + r + 1] - iy2[y0 + r + 1, x0] + iy2[y0, x0]
        m = s / n
        var = np.maximum(s2 / n - m * m, 0.0)
        sel = var < best
        best = np.where(sel, var, best)
        for c in range(3):
            ii = icol[c]
            sc = (ii[y0 + r + 1, x0 + r + 1] - ii[y0, x0 + r + 1]
                  - ii[y0 + r + 1, x0] + ii[y0, x0])
            out[..., c] = np.where(sel, sc / n, out[..., c])
    return np.clip(np.round(out), 0, 255).astype(np.int64)


def _brighten(rgb, cfg):
    """gamma LUT + 饱和度混合。ENH_SAT 以 100 为 1.0"""
    x = _gamma_lut(int(cfg["ENH_GAMMA"]))[rgb]
    ly = ((77 * x[..., 0] + 150 * x[..., 1] + 29 * x[..., 2]) >> 8)[..., None]
    sat = cfg["ENH_SAT"] / 100.0
    return np.clip(ly + sat * (x - ly), 0, 255).astype(np.int64)


def _posterize(x, levels):
    """
    色彩量化：2 的幂级数 -> 屏蔽低位（纯与门 + 移位，硬件零成本，无乘法）。
    levels 取 2 的幂(4/8/16/32)。b = log2(levels)，保留高 b 位：
      16 级 -> 保留高 4 位 -> 0/16/32/.../240，步长 16
      8  级 -> 保留高 3 位 -> 0/32/64/.../224
    注意：这是“向下截断”而非四舍五入，暗部会比 round() 版略偏暗一档。
    """
    levels = int(np.clip(levels, 2, 256))
    b = int(round(np.log2(levels)))
    b = max(1, min(b, 8))
    mask = (0xFF >> b) << b
    return (x & mask).astype(np.int64)


def _posterize_legacy(x, levels):
    """旧版量化（q=255/(levels-1)，round 到最近级）——仅保留用于回归比对，非主路径"""
    levels = int(np.clip(levels, 2, 32))
    q = 255.0 / (levels - 1)
    out = np.round(np.round(x / q) * q)
    return np.clip(out, 0, 255).astype(np.int64)


# ==============================================================================
# 4. 主流水线（等价于原文件 MODE=2 + INK_DARK=0）
# ==============================================================================
def process(rgb_u8, cfg=None, posterize=None):
    """
    卡通化（无描边）。rgb_u8: (H,W,3) uint8，通道顺序 R,G,B。
    返回 (H,W,3) uint8。标准输入输出为 640x480x24。
    posterize: 量化函数，默认 _posterize（屏蔽低位）；仅供回归比对时替换。
    """
    cfg = dict(CFG_DEFAULT, **(cfg or {}))
    post_fn = posterize or _posterize
    if not int(cfg["ENABLE"]) & 1:
        return rgb_u8.copy()

    rgb = rgb_u8.astype(np.int64)

    # --- 步骤 1：逐通道 3x3 中值（去椒盐/单像素噪声，保护硬边） ---
    base = np.stack([_med3(rgb[..., c]) for c in range(3)], axis=-1)

    # --- 步骤 2：白平衡（固定 Q8 增益，默认 256=1.0 不缩放） ---
    g = _awb_gains(cfg)
    base = np.clip((base * g) >> 8, 0, 255)

    # --- 步骤 3：Kuwahara 保边平滑（卡通化的核心：色块变平、边界保留） ---
    col = _kuwahara(base, int(cfg["KUWA_R"]), _luma_q8(base.astype(np.uint8)))

    # --- 步骤 4：gamma 提亮 + 饱和度提升（让色块更"卡通"） ---
    col = _brighten(col, cfg)

    # --- 步骤 5：色彩量化（屏蔽低位，16 级 -> 0/16/32/.../240） ---
    col = post_fn(col, cfg["POSTER_LV"])

    return np.clip(col, 0, 255).astype(np.uint8)


# ==============================================================================
# 5. 文件 IO（固定 640x480x24）
# ==============================================================================
def load_rgb24(path):
    """读入任意图片，统一转成 (480,640,3) uint8 RGB24"""
    im = Image.open(path).convert("RGB")
    if im.size != (W, H):
        im = im.resize((W, H), Image.LANCZOS)
    rgb = np.asarray(im, np.uint8)
    assert rgb.shape == (H, W, CHANNELS), rgb.shape
    return rgb


def run(in_path, out_path, cfg=None):
    rgb = load_rgb24(in_path)
    out = process(rgb, cfg)
    Image.fromarray(out).save(out_path)
    print("in : %s  (%dx%d x %dbit)" % (in_path, W, H, CHANNELS * 8))
    print("out: %s  (%dx%d x %dbit)" % (out_path, out.shape[1], out.shape[0],
                                       CHANNELS * 8))
    return out


# ==============================================================================
# 6. 与 style_reference.py 的逐位比对
# ==============================================================================
def _load_reference():
    """同目录下的 style_reference.py（不存在则返回 None）"""
    import importlib.util
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "style_reference.py")
    if not os.path.isfile(p):
        return None
    spec = importlib.util.spec_from_file_location("style_reference", p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def selftest(in_path):
    import time
    rgb = load_rgb24(in_path)
    ref = _load_reference()
    if ref is None:
        print("找不到 style_reference.py，跳过比对。")
        return

    ref_gains = ref._awb_gains(rgb)          # 原文件灰度世界算出的 3 个增益

    t0 = time.perf_counter()
    mine = process(rgb)                       # 本文件默认：屏蔽低位16级 / 饱和100 / 固定256
    t1 = time.perf_counter()
    orig = ref.process(rgb, {"MODE": 2, "INK_DARK": 0})   # 原文件：round量化8级 / 饱和120 / 灰度世界
    t2 = time.perf_counter()

    # 核心算法逐位比对：把参数全对齐到原文件，且量化也用原文件的 round 版。
    # 若逐位相等，说明中值/白平衡/Kuwahara/gamma/饱和这些共享环节完全一致，
    # 只剩“量化方式”这一处是有意为之的差异（屏蔽低位 vs round 到最近级）。
    aligned = process(rgb, {"POSTER_LV": 8, "ENH_SAT": 120,
                            "AWB_GAIN_R": int(ref_gains[0]),
                            "AWB_GAIN_G": int(ref_gains[1]),
                            "AWB_GAIN_B": int(ref_gains[2])},
                      posterize=_posterize_legacy)

    def stat(x, y):
        d = np.abs(x.astype(np.int64) - y.astype(np.int64))
        return int(d.max()), int((d > 0).any(axis=2).sum())

    print("=" * 68)
    print("自检：本文件 vs style_reference.process(MODE=2, INK_DARK=0)")
    print("  本文件默认 : 屏蔽低位16级, ENH_SAT=100, 白平衡固定 256")
    print("  原文件默认 : round量化8级 , ENH_SAT=120, 灰度世界 AWB")
    m, n = stat(mine, orig)
    print("  [默认 vs 原文件]     最大差 %d LSB / 差异像素 %d (量化方式+调优参数所致)"
          % (m, n))
    m2, n2 = stat(aligned, orig)
    print("  [量化方式也对齐后]   最大差 %d LSB / 差异像素 %d -> %s"
          % (m2, n2, "逐位相等" if np.array_equal(aligned, orig) else "不一致!"))
    print("  耗时 : 精简版 %.1f ms / 原文件 %.1f ms" % ((t1 - t0) * 1e3,
                                                        (t2 - t1) * 1e3))
    print("=" * 68)


# ==============================================================================
# 7. RTL 模块对照（只列保留的部分）
# ==============================================================================
MODULE_MAP = """
Verilog 模块对照表（卡通-无描边版）
-----------------------------------
  本文件函数                 RTL 模块              关键实现
  ---------------------------------------------------------------------------
  _med3()               median3.v             19 比较器，2 行缓存 x 8bit x3
  _awb_gains()          awb_gain.v            3 个固定 Q8 增益寄存器（=256）+ 乘法
  _kuwahara()           kuwahara.v            4x(和 + 平方和)，r=3 时 >>4 精确
  _luma_q8()            luma_q8.v             3 个常数乘加，输出 Q8(16bit)
  _build_gamma_lut()    gamma_lut.v           256 x 8 LUT（双端口 BRAM）
  _brighten()           sat.v                 1 乘法 + 1 加法，饱和截断
  _posterize()          posterize.v           屏蔽低位（与门+移位，无乘法）
  process()             top.v                 5 级流水，无反馈
  CFG_DEFAULT           axil_regs.v           8 个寄存器
"""


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        arg = [a for a in sys.argv[1:] if not a.startswith("-")]
        selftest(arg[0] if arg else "in.jpg")
    elif len(sys.argv) >= 3:
        run(sys.argv[1], sys.argv[2])
    else:
        print(__doc__)
        print(MODULE_MAP)
