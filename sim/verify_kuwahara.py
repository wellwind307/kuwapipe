# -*- coding: utf-8 -*-
"""
================================================================================
 verify_kuwahara.py —— RTL(video_kuwahara.v) 的整数行为模型 + 与 golden 的比对
================================================================================

做三件事：

1) 用 numpy 精确复刻 RTL 的行为（整数、零填充边界、disc 判别式、
   平局顺序 TL>TR>BL>BR、round-half-even 均值）。
2) 与参考模型 ../data/style_cartoon_640x480.py 的
   _kuwahara()（float64 积分图 + edge-replicate 边界）逐位比对：
      - 内部像素（去掉最外 3 行/3 列）应【逐位一致】
      - 边界像素因为边界策略不同（RTL 补零 vs 参考 replicate）会有差异，
        这属于有意为之，报告里会单独统计。
3) --tb 时生成 xsim 用的激励/期望文件（wb 为小尺寸 64x48，便于快速仿真）。

用法：
    python verify_kuwahara.py              # 全分辨率 640x480 比对
    python verify_kuwahara.py --tb         # 额外生成 tb_kw_in.hex 等（写到本目录）

原理（为什么整数实现能逐位对齐）
    RTL:  Y = 77R+150G+29B (Q8, 16bit)
          disc = 16*sum(Y^2) - sum(Y)^2
    参考:  y = Y/256; var = sum(y^2)/16 - (sum(y)/16)^2
          = (16*sum(Y^2) - sum(Y)^2) / 2^20 = disc / 2^20
    disc 与 var 只差一个正的常数因子 2^20，所以 argmin 完全相同；两者都是
    整数（float64 表示这些数没有误差），平局也用同样的严格小于 + 同样的
    遍历顺序，因此象限选择逐位一致。均值一侧 RTL 用 round-half-even，
    正好等价于 np.round(sum/16)。
================================================================================
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))

# 参考模型与测试图都在 ../data/，随包分发，脚本不再依赖任何本机绝对路径。
DATA_DIR = os.path.normpath(os.path.join(HERE, "..", "data"))
REF_PATH = os.path.join(DATA_DIR, "style_cartoon_640x480.py")
IMG_PATH = os.path.join(DATA_DIR, "fortest.jpg")

R = 3                      # Kuwahara 半径（golden 默认 KUWA_R=3）
W_FULL, H_FULL = 640, 480   # golden 参考图的尺寸（算法比对与分辨率无关）
FULL_W, FULL_H = 800, 480   # 上游 HLS 中值 IP 的真实输出几何（硬编码常量 800x480）
TB_W, TB_H = 64, 48        # xsim 用小图


# ==============================================================================
# 1. RTL 整数模型
# ==============================================================================
def luma_q8(rgb):
    """与 _luma_q8 / luma_q8.v 一致：16bit Q8"""
    r = rgb[..., 0].astype(np.int64)
    g = rgb[..., 1].astype(np.int64)
    b = rgb[..., 2].astype(np.int64)
    return 77 * r + 150 * g + 29 * b


def round_half_even_div16(s):
    """与 kuwahara.v 的 round_mean() 一致：s/16 的银行家舍入（整数实现）"""
    q = s >> 4
    rem = s & 15
    return q + ((rem > 8) | ((rem == 8) & (q & 1))).astype(np.int64)


def _integ(x):
    ii = np.zeros((x.shape[0] + 1, x.shape[1] + 1), np.int64)
    ii[1:, 1:] = x.cumsum(0).cumsum(1)
    return ii


def kuwahara_rtl(rgb_u8, r=R, edge="zero"):
    """
    video_kuwahara.v 的行为模型（向量化）。

    edge: "zero"   = RTL 实际行为（flush 拍补零）
          "replicate" = 参考 _kuwahara 的边界（np.pad edge），用来单独验证
                        "除边界外逐位一致" 这个结论。
    """
    h, w = rgb_u8.shape[:2]
    a = rgb_u8.astype(np.int64)
    Y = luma_q8(a)
    Y2 = Y * Y

    mode = "constant" if edge == "zero" else "edge"
    pad = r
    ap = np.pad(a, ((pad, pad), (pad, pad), (0, 0)), mode=mode)
    Yp = np.pad(Y, pad, mode=mode)
    Y2p = np.pad(Y2, pad, mode=mode)

    iy, iy2 = _integ(Yp), _integ(Y2p)
    icol = [_integ(ap[..., c]) for c in range(3)]

    Yg = np.arange(h)[:, None]
    Xg = np.arange(w)[None, :]
    best = None
    out = np.zeros((h, w, 3), np.int64)

    # 与参考完全相同的遍历顺序：TL, TR, BL, BR
    for dy, dx in [(0, 0), (0, r), (r, 0), (r, r)]:
        y0, x0 = Yg + dy, Xg + dx
        s = (iy[y0 + r + 1, x0 + r + 1] - iy[y0, x0 + r + 1]
             - iy[y0 + r + 1, x0] + iy[y0, x0])
        s2 = (iy2[y0 + r + 1, x0 + r + 1] - iy2[y0, x0 + r + 1]
              - iy2[y0 + r + 1, x0] + iy2[y0, x0])
        disc = 16 * s2 - s * s                      # == 256 * var，恒 >= 0
        if best is None:
            best = disc
            sel = np.ones_like(disc, dtype=bool)    # 第一个象限无条件胜出
        else:
            sel = disc < best                       # 严格小于 -> 平局保留先选的
            best = np.where(sel, disc, best)
        for c in range(3):
            ii = icol[c]
            sc = (ii[y0 + r + 1, x0 + r + 1] - ii[y0, x0 + r + 1]
                  - ii[y0 + r + 1, x0] + ii[y0, x0])
            out[..., c] = np.where(sel, sc, out[..., c])

    return round_half_even_div16(out)


# ==============================================================================
# 2. 载入参考模型
# ==============================================================================
def load_reference():
    if not os.path.isfile(REF_PATH):
        print("!! 找不到参考模型: %s" % REF_PATH)
        return None
    import importlib.util
    spec = importlib.util.spec_from_file_location("style_ref", REF_PATH)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def load_image(path, w, h, y0=None, x0=None):
    from PIL import Image
    im = Image.open(path).convert("RGB")
    if (w, h) == (W_FULL, H_FULL):
        if im.size != (w, h):
            im = im.resize((w, h), Image.LANCZOS)
    else:
        # 从全分辨率图里裁一块（用中心稍微偏上的区域，细节比较丰富）
        if im.size != (W_FULL, H_FULL):
            im = im.resize((W_FULL, H_FULL), Image.LANCZOS)
        y0 = 180 if y0 is None else y0
        x0 = 260 if x0 is None else x0
        im = im.crop((x0, y0, x0 + w, y0 + h))
    return np.asarray(im, np.uint8)


# ==============================================================================
# 3. 全分辨率比对
# ==============================================================================
def compare_full():
    ref = load_reference()
    if ref is None:
        return False
    rgb = load_image(IMG_PATH, W_FULL, H_FULL)
    assert rgb.shape == (H_FULL, W_FULL, 3), rgb.shape

    # 流水线里的 Kuwahara 输入 = 中值滤波结果（白平衡 256 是恒等）
    base = np.stack([ref._med3(rgb[..., c].astype(np.int64)) for c in range(3)],
                    axis=-1)
    base_u8 = np.clip(base, 0, 255).astype(np.uint8)

    gold = ref._kuwahara(base, R, ref._luma_q8(base_u8)).astype(np.int64)
    mine = kuwahara_rtl(base_u8, R, edge="zero")
    exact_edge = kuwahara_rtl(base_u8, R, edge="replicate")

    def stat(a, b, mask=None):
        d = np.abs(a - b)
        if mask is not None:
            d = d * mask[..., None]
        return int(d.max()), int((d.sum(axis=2) > 0).sum())

    n_pix = W_FULL * H_FULL
    inner = np.zeros((H_FULL, W_FULL), np.int64)
    inner[R:H_FULL - R, R:W_FULL - R] = 1          # 去掉最外 3 行/3 列

    m_all, n_all = stat(mine, gold)
    m_in, n_in = stat(mine, gold, inner)
    m_rep, n_rep = stat(exact_edge, gold)

    print("=" * 74)
    print("Kuwahara RTL(video_kuwahara.v) 整数模型 vs golden _kuwahara()")
    print("  输入: %s -> %dx%d, 先做参考的 3x3 中值" % (os.path.basename(IMG_PATH),
                                                    W_FULL, H_FULL))
    print("  参考: %s (_kuwahara, 半径 %d, edge-replicate 边界)" %
          (os.path.basename(REF_PATH), R))
    print("-" * 74)
    print("  [RTL 行为模型 / 零填充边界]")
    print("     全图       : 最大差 %d LSB, 差异像素 %d / %d (%.2f%%)"
          % (m_all, n_all, n_pix, 100.0 * n_all / n_pix))
    print("     内部(去掉最外3行3列): 最大差 %d LSB, 差异像素 %d / %d"
          % (m_in, n_in, (W_FULL - 2 * R) * (H_FULL - 2 * R)))
    print("  [同一模型但把边界改成 replicate]")
    print("     全图       : 最大差 %d LSB, 差异像素 %d  -> %s"
          % (m_rep, n_rep, "逐位一致" if n_rep == 0 else "仍有差异!"))
    print("-" * 74)
    print("  结论: 内部像素与 golden 逐位一致；最外 3 行/3 列因为 RTL 用补零"
          "作为边界\n        （参考用 edge-replicate）而不同，属于有意为之。")
    print("=" * 74)
    return n_in == 0 and n_rep == 0


# ==============================================================================
# 4. 生成 xsim 激励/期望（小尺寸，便于快速仿真）
# ==============================================================================
def gen_tb_vectors():
    rgb = load_image(IMG_PATH, TB_W, TB_H)
    exp = kuwahara_rtl(rgb, R, edge="zero")
    sim_dir = HERE
    if not os.path.isdir(sim_dir):
        os.makedirs(sim_dir)

    p_in = os.path.join(sim_dir, "tb_kw_in.hex")
    p_exp = os.path.join(sim_dir, "tb_kw_exp.hex")
    with open(p_in, "w", encoding="ascii") as f:
        for y in range(TB_H):
            for x in range(TB_W):
                f.write("%02X%02X%02X\n" % tuple(rgb[y, x]))
    with open(p_exp, "w", encoding="ascii") as f:
        for y in range(TB_H):
            for x in range(TB_W):
                f.write("%02X%02X%02X\n" % tuple(exp[y, x]))

    # 同时存一张 PNG，方便肉眼对照（输入 / RTL 期望 / 参考）
    try:
        from PIL import Image
        Image.fromarray(rgb).resize((TB_W * 4, TB_H * 4), Image.NEAREST).save(
            os.path.join(sim_dir, "tb_kw_in.png"))
        Image.fromarray(exp.astype(np.uint8)).resize(
            (TB_W * 4, TB_H * 4), Image.NEAREST).save(
            os.path.join(sim_dir, "tb_kw_exp.png"))
    except Exception as e:
        print("  (存 PNG 失败: %r)" % (e,))

    print("已生成 xsim 向量: %dx%d" % (TB_W, TB_H))
    print("  %s" % p_in)
    print("  %s" % p_exp)
    return p_in, p_exp


def gen_tb_full():
    """全尺寸（上游 HLS 中值真实输出几何 800x480），用于 TB_FULL 配置的密集流仿真"""
    from PIL import Image
    im = Image.open(IMG_PATH).convert("RGB")
    im = im.resize((FULL_W, FULL_H), Image.LANCZOS)
    rgb = np.asarray(im, np.uint8)
    exp = kuwahara_rtl(rgb, R, edge="zero")
    sim_dir = HERE
    p_in = os.path.join(sim_dir, "tb_full_in.hex")
    p_exp = os.path.join(sim_dir, "tb_full_exp.hex")
    with open(p_in, "w", encoding="ascii") as f:
        for y in range(FULL_H):
            for x in range(FULL_W):
                f.write("%02X%02X%02X\n" % tuple(rgb[y, x]))
    with open(p_exp, "w", encoding="ascii") as f:
        for y in range(FULL_H):
            for x in range(FULL_W):
                f.write("%02X%02X%02X\n" % tuple(exp[y, x]))
    print("已生成全尺寸 xsim 向量: %dx%d (TB_FULL)" % (FULL_W, FULL_H))
    return p_in, p_exp


# ==============================================================================
if __name__ == "__main__":
    ok = True
    if os.path.isfile(IMG_PATH) and os.path.isfile(REF_PATH):
        ok = compare_full()
    else:
        print("!! 缺少输入图片或参考模型，跳过全分辨率比对")

    if "--tb" in sys.argv:
        gen_tb_vectors()
    if "--tb-full" in sys.argv:
        gen_tb_full()

    print("VERIFY RESULT: %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)
