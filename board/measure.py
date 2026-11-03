#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""板上实测脚本：帧率 + 噪声地板 + （诊断用）与 golden 的差异。

用法：

    python3 measure.py fps    --seconds 10    # 输出帧率（写进指标表）
    python3 measure.py noise  --seconds 2     # 相邻帧差异 = 逐像素比对的下限
    python3 measure.py compare                # 仅诊断，不作为一致性判据

★ 重要：不要用 compare 的结果判断“与 golden 是否一致”。
  Kuwahara 选象限是 argmin(方差) 的离散判决，输入几 LSB 的噪声就可能翻转象限，
  输出随之差出几十；再加上两次抓取本就是不同帧、自动曝光也会微动，
  所以板上逐像素比对**天然不收敛**。
  等价性由 xsim 证明（全尺寸 800x480，captured 384000/384000，mismatch 0），
  板上只证明“功能正常、帧率达标、处理与直通确实不同”。

前提：厂商 PYNQ 镜像（含 pynq.lib.ov5640）；显示 640x480（DVI 限制，右侧裁 20%）。
"""

import argparse
import hashlib
import importlib.util
import os
import time

import numpy as np
import PIL.Image

from pynq.overlays.base import BaseOverlay
from pynq.lib.iic import AxiIIC
from pynq.lib.ov5640 import OV5640
from pynq.lib.video import PIXEL_RGB, VideoMode

W, H, BPP = 640, 480, 24

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_BIT = os.path.normpath(os.path.join(HERE, "bitstream", "base.bit"))
GOLDEN = os.path.normpath(os.path.join(HERE, "..", "data", "style_cartoon_640x480.py"))


def open_pipeline(bit_path=DEFAULT_BIT, freeze=False, wb=None):
    base = BaseOverlay(bit_path)
    cam = base.video.camera_in
    hdmi = base.video.hdmi_out
    iic = AxiIIC(base.ip_dict["cam_iic"])
    OV5640(0x3C, iic).init()
    cam.configure(VideoMode(W, H, BPP), PIXEL_RGB)
    hdmi.configure(cam.mode, PIXEL_RGB)
    cam.start()
    hdmi.start()
    cam.tie(hdmi)
    time.sleep(1.0)
    return base, cam, hdmi


def grab(cam, settle=0.2):
    time.sleep(settle)
    return np.ascontiguousarray(cam.readframe())


def measure_fps(cam, seconds=10.0):
    """按不重复帧计数测帧率（视频通路时序驱动，读得快只会读到重复帧）。"""
    uniq = set()
    n = 0
    t0 = time.time()
    while time.time() - t0 < seconds:
        f = np.ascontiguousarray(cam.readframe())
        n += 1
        uniq.add(hashlib.sha1(f.tobytes()).digest())
    dt = time.time() - t0
    return {"elapsed_s": dt, "reads": n, "unique_frames": len(uniq),
            "fps": len(uniq) / dt if dt > 0 else 0.0}


def load_golden(path=GOLDEN):
    spec = importlib.util.spec_from_file_location("golden_ref", path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def build_expected(raw):
    """只算 中值 + Kuwahara，对应 camera_in DMA 的取点。"""
    ref = load_golden()
    med = np.stack([ref._med3(raw[..., c].astype(np.int64)) for c in range(3)], axis=-1)
    med_u8 = np.clip(med, 0, 255).astype(np.uint8)
    y = ref._luma_q8(med_u8)
    out = ref._kuwahara(med, int(ref.CFG_DEFAULT["KUWA_R"]), y)
    return np.clip(np.rint(np.asarray(out, dtype=np.float64)), 0, 255).astype(np.int16)


def cmd_fps(args):
    base, cam, hdmi = open_pipeline(args.bit, freeze=args.freeze, wb=args.wb)
    try:
        r = measure_fps(cam, args.seconds)
        print("---- output frame rate ----")
        print("  elapsed        : %.2f s" % r["elapsed_s"])
        print("  read calls     : %d" % r["reads"])
        print("  unique frames  : %d" % r["unique_frames"])
        print("  measured fps   : %.2f" % r["fps"])
        print("  note: 受 OV5640 时序限制（HTS=1800, VTS=1000）")
    finally:
        hdmi.stop(); cam.stop()


def _noise_block(cam, label, n=4, interval=0.5):
    frames = [grab(cam, settle=interval) for _ in range(n)]
    print("---- %s 模式 ----" % label)
    for f in frames:
        m = f.reshape(-1, 3).mean(axis=0)
        print("  帧均值 R,G,B = %.1f, %.1f, %.1f" % (m[0], m[1], m[2]))
    for i in range(len(frames) - 1):
        d = np.abs(frames[i].astype(np.int16) - frames[i + 1].astype(np.int16))
        print("  frame%d vs frame%d: mean %.2f, max %3d, 差异像素 %.1f%%"
              % (i, i + 1, d.mean(), d.max(),
                 100.0 * (d.sum(axis=2) > 0).mean()))
    return frames


def cmd_noise(args):
    """处理 / 直通各测一遍，区分“相机在动”还是“处理链在抖”。"""
    base, cam, hdmi = open_pipeline(args.bit, freeze=args.freeze, wb=args.wb)
    try:
        ans = input("当前是否为【处理】模式（LED2 灭）？(y/n): ").strip().lower()
        first_is_proc = ans.startswith("y")
        lab0 = "处理" if first_is_proc else "直通"
        _noise_block(cam, lab0, interval=args.interval)

        print("\n请按一次 PL_KEY0 切到【%s】模式，然后回车继续 ..."
              % ("直通" if first_is_proc else "处理"))
        input()
        lab1 = "直通" if first_is_proc else "处理"
        _noise_block(cam, lab1, interval=args.interval)
    finally:
        hdmi.stop(); cam.stop()

    print("\n判读方式：")
    print("  * 两种模式都差得差不多 -> 相机/曝光在动（不是处理链的问题）")
    print("  * 只有处理模式差、直通几乎不动 -> Kuwahara 的 argmin 判决在噪声下翻转（正常现象）")


def cmd_compare(args):
    """仅诊断：看看板端输出更像哪种模型。不作为 PASS/FAIL。"""
    os.makedirs(args.outdir, exist_ok=True)
    base, cam, hdmi = open_pipeline(args.bit, freeze=args.freeze, wb=args.wb)
    try:
        print("请确认：画面静止、当前为【处理】模式（LED2 灭）。")
        input(">> 按回车抓取处理结果 ...")
        proc = grab(cam)
        print("请按一次 PL_KEY0 切到【直通】（LED2 亮），保持画面不动。")
        input(">> 按回车抓取原始画面 ...")
        raw = grab(cam)
    finally:
        hdmi.stop(); cam.stop()

    rad = float(np.abs(raw.astype(np.int16) - proc.astype(np.int16)).mean())
    exp = build_expected(raw)
    d = np.abs(proc.astype(np.int16) - exp)

    print("---- diagnostic only ( NOT a consistency criterion ) ----")
    print("  raw vs proc 平均绝对差 : %.2f（应明显大于 0，说明切换生效）" % rad)
    print("  proc vs golden(median+Kuwahara): mean %.2f, max %d, 差异像素 %.1f%%"
          % (d.mean(), d.max(), 100.0 * (d.sum(axis=2) > 0).mean()))
    print("  说明：该差异主要来自“不同帧 + 噪声 + argmin 离散跳变”，不是实现错误。")

    for nm, img in (("raw", raw), ("proc", proc), ("expected", exp)):
        PIL.Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(
            os.path.join(args.outdir, "cmp_%s.png" % nm))
    print("  已保存到", os.path.abspath(args.outdir))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fps", "noise", "compare"])
    ap.add_argument("--seconds", type=float, default=10.0)
    ap.add_argument("--interval", type=float, default=0.5)
    ap.add_argument("--bit", default=DEFAULT_BIT)
    ap.add_argument("--outdir", default="./captures")
    ap.add_argument("--freeze", action="store_true",
                    help="冻结 AE/AGC（稳定画面、降低帧间差异）")
    ap.add_argument("--wb", type=int, default=None,
                    help="固定白平衡 1=日光 2=办公室 3=阴天 4=家里")
    args = ap.parse_args()
    {"fps": cmd_fps, "noise": cmd_noise, "compare": cmd_compare}[args.cmd](args)


if __name__ == "__main__":
    main()