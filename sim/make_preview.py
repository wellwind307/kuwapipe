# -*- coding: utf-8 -*-
"""
================================================================================
 make_preview.py —— 生成 Kuwahara 的对比图（给报告/答辩用）
================================================================================
输出 preview_kuwahara.png（2 行 3 列）：

  上排：① 输入原图          ② 3x3 中值后        ③ Kuwahara 输出(RTL 整数模型)
  下排：④ Kuwahara(golden)  ⑤ 卡通化最终输出(RTL 全链路)  ⑥ ③ 与 ④ 的差异图(x8)

说明：
  * ③④ 用同一张"中值后"的图作为输入，只比 Kuwahara 这一步；
  * ⑤ 是 RTL 链路：Kuwahara -> gamma(45) -> 饱和度(1.00) -> 屏蔽低 4 位量化
    （video_style 的 DITHER_EN=0 版本，便于和 golden 对比）；
  * ⑥ 可见差异只出现在最外 3 行/3 列（RTL 补零边界 vs golden replicate 边界），
    内部像素完全一致。

用法： python make_preview.py      （输出写到 ../data/）
================================================================================
"""
import os

import numpy as np
from PIL import Image

import verify_kuwahara as V

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "data"))


def brighten(rgb, g100=45, sat_q8=256):
    """video_style.v 的 gamma LUT + 饱和度混合（Q8 定点，与 RTL 一致）"""
    i = np.arange(256, dtype=np.float64) / 255.0
    g = max(g100, 1) / 100.0
    lut = np.clip(np.round(255.0 * (i ** g)), 0, 255).astype(np.int64)
    x = lut[rgb.astype(np.int64)]
    ly = ((77 * x[..., 0] + 150 * x[..., 1] + 29 * x[..., 2]) >> 8)[..., None]
    # out = ly + (sat_q8 * (x - ly)) >> 8
    return np.clip(ly + ((sat_q8 * (x - ly)) >> 8), 0, 255).astype(np.int64)


def posterize(x, levels=16):
    """屏蔽低位（视频里还叠了 Bayer 抖动，这里为便于对比用纯屏蔽）"""
    mask = 0xFF & (~(levels - 1))
    return (x.astype(np.int64) & mask)


def label(img, text):
    """在图片左上角画一个简单的白色底标签块（避免引入新依赖，用 PIL 默认字体）"""
    from PIL import ImageDraw
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGB")
    d = ImageDraw.Draw(im)
    tb = d.textbbox((0, 0), text)
    w, h = tb[2] - tb[0] + 8, tb[3] - tb[1] + 6
    d.rectangle([0, 0, w, h], fill=(0, 0, 0))
    d.text((4, 3), text, fill=(255, 255, 0))
    return im


def main():
    ref = V.load_reference()
    rgb = V.load_image(V.IMG_PATH, V.W_FULL, V.H_FULL)

    base = np.stack([ref._med3(rgb[..., c].astype(np.int64)) for c in range(3)],
                    axis=-1)
    base_u8 = np.clip(base, 0, 255).astype(np.uint8)

    gold_kw = ref._kuwahara(base, V.R, ref._luma_q8(base_u8)).astype(np.int64)
    rtl_kw = V.kuwahara_rtl(base_u8, V.R, edge="zero")

    final_rtl = posterize(brighten(rtl_kw))
    final_gold = ref.process(rgb)          # 参考全链路（含中值+量化）

    diff = np.abs(rtl_kw - gold_kw)
    diff_show = np.clip(diff * 8, 0, 255)

    panels = [
        ("1) input %dx%d" % (V.W_FULL, V.H_FULL), rgb),
        ("2) after 3x3 median", base_u8),
        ("3) Kuwahara r=3 (RTL int model)", rtl_kw),
        ("4) Kuwahara r=3 (golden float)", gold_kw),
        ("5) RTL full chain: kuw+cgamma+sat+quant", final_rtl),
        ("6) |(3)-(4)| x8 (border only)", diff_show),
    ]

    ims = [label(img, txt) for txt, img in panels]
    W, H = V.W_FULL, V.H_FULL
    sheet = Image.new("RGB", (W * 3, H * 2), (32, 32, 32))
    for k, im in enumerate(ims):
        sheet.paste(im, ((k % 3) * W, (k // 3) * H))

    out1 = os.path.join(OUT_DIR, "preview_kuwahara.png")
    sheet.save(out1)
    print("saved %s  (%dx%d)" % (out1, sheet.size[0], sheet.size[1]))

    # 细节裁剪：同一块 240x160 区域，看保边效果
    y0, x0, cw, ch = 200, 200, 240, 160
    crops = [rgb, base_u8, rtl_kw, final_rtl]
    titles = ["input", "median", "kuwahara(RTL)", "full RTL chain"]
    sheet2 = Image.new("RGB", (cw * 4, ch), (32, 32, 32))
    for k, (img, t) in enumerate(zip(crops, titles)):
        c = img[y0:y0 + ch, x0:x0 + cw]
        sheet2.paste(label(c, t), (k * cw, 0))
    out2 = os.path.join(OUT_DIR, "preview_kuwahara_crop.png")
    sheet2.save(out2)
    print("saved %s" % out2)

    # 数值摘要
    d = np.abs(final_rtl - final_gold.astype(np.int64))
    print("RTL 全链路 vs golden process(): 最大差 %d, 差异像素 %d / %d (%.2f%%)"
          % (int(d.max()), int((d.sum(axis=2) > 0).sum()), W * H,
             100.0 * (d.sum(axis=2) > 0).sum() / (W * H)))


if __name__ == "__main__":
    main()
