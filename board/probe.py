#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""板上诊断：一次试完几种“板端输出到底是什么”的可能，定位比对口径。

用法：
    python3 measure.py probe

会采集两张图（处理模式 / 直通模式），然后打印：
  1. 两张图的通道均值、是否被量化（低 4 位恒为 0）
  2. 四种候选模型中，哪一个与板端输出最接近：
       Kuwahara(median)  /  Kuwahara(median) + 通道反转(R<->B)
       全链路 process()   /  全链路 + 通道反转
"""

import argparse
import os
import time

import numpy as np

from measure import (W, H, BPP, DEFAULT_BIT, load_golden, open_pipeline, grab)


def med_kw(ref, rgb):
    med = np.stack([ref._med3(rgb[..., c].astype(np.int64)) for c in range(3)], axis=-1)
    med_u8 = np.clip(med, 0, 255).astype(np.uint8)
    y = ref._luma_q8(med_u8)
    out = ref._kuwahara(med, int(ref.CFG_DEFAULT["KUWA_R"]), y)
    return np.clip(np.rint(np.asarray(out, dtype=np.float64)), 0, 255).astype(np.int16)


def stat(img, ref, margin=3):
    d = np.abs(img.astype(np.int16) - ref)
    mask = np.zeros((H, W), bool)
    mask[margin:H - margin, margin:W - margin] = True
    dd = d * mask[..., None]
    return int(dd.max()), int((dd.sum(axis=2) > 0).sum()), int(mask.sum())


def quant_ratio(img):
    v = img.reshape(-1)
    return float(np.count_nonzero((v & 0x0F) == 0)) / v.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bit", default=DEFAULT_BIT)
    args = ap.parse_args()

    base, cam, hdmi = open_pipeline(args.bit)
    try:
        print("请确认：画面静止、当前为【处理】模式（LED2 灭）。")
        input(">> 回车抓处理结果 ...")
        proc = grab(cam)
        print("请按 PL_KEY0 切【直通】（LED2 亮）。")
        input(">> 回车抓原始画面 ...")
        raw = grab(cam)
    finally:
        hdmi.stop(); cam.stop()

    print("\n==== 1. 基本统计 ====")
    for name, img in (("raw ", raw), ("proc", proc)):
        m = img.reshape(-1, 3).mean(axis=0)
        print("%s: shape=%s mean(R,G,B)=%.1f,%.1f,%.1f  低4位为0的比例=%.3f"
              % (name, img.shape, m[0], m[1], m[2], quant_ratio(img)))

    print("\n==== 2. 候选模型（内部区域，去掉最外 3 像素）====")
    ref = load_golden()

    cands = {}
    cands["Kuwahara(median)          "] = med_kw(ref, raw)
    cands["Kuwahara(median) + R<->B "] = med_kw(ref, raw[..., ::-1])
    cands["full chain process()      "] = np.clip(
        np.rint(ref.process(raw).astype(np.float64)), 0, 255).astype(np.int16)
    cands["full chain process() +swap"] = np.clip(
        np.rint(ref.process(raw[..., ::-1]).astype(np.float64)), 0, 255).astype(np.int16)

    for name, exp in cands.items():
        mx, npx, tot = stat(exp, proc)
        print("  %s : 最大差 %3d, 差异 %6d / %6d (%.1f%%)"
              % (name, mx, npx, tot, 100.0 * npx / tot))

    print("\n==== 3. raw / proc 直接对比 ====")
    print("  mean|raw-proc| = %.2f" % np.abs(raw.astype(np.int16) - proc.astype(np.int16)).mean())


if __name__ == "__main__":
    main()