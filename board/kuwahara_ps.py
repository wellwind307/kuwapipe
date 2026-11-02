#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""KuwaPIPE —— PS 侧控制脚本（PYNQ）

    python kuwahara_ps.py            # 完整流程：加载 Overlay -> 初始化 OV5640 -> 抓一帧
    python kuwahara_ps.py --frames 5 # 连抓 5 帧

硬件：xc7z020clg400-2（PYNQ-Z2 兼容板）+ OV5640 + HDMI 显示器。

两个关键约束：
  * OV5640 由 pynq.lib.ov5640 的寄存器表配置为 800x480 RGB565
    （0x3808/09 = 0x0320、0x380a/0b = 0x01E0），PL 内 HLS 中值 IP 的行列循环同样是 800x480；
  * 但 PYNQ 的 DVI 输出只支持 (640,480) (800,600) (1280,720) (1280,1024) (1920,1080)，
    800x480 会抛 ValueError: Invalid Output resolution 800x480。
    因此显示只能用 640x480 —— 每行取前 640 像素，右侧 20% 被裁掉，这是显示通路的硬限制。
"""

import argparse
import os
from datetime import datetime

import PIL.Image
from pynq.overlays.base import BaseOverlay
from pynq.lib.iic import AxiIIC
from pynq.lib.ov5640 import OV5640
from pynq.lib.video import PIXEL_RGB, VideoMode

BIT_PATH = "./base.bit"
HWH_PATH = "./base.hwh"

# 显示模式：受 PYNQ DVI 支持列表限制，不能用上游的 800x480
FRAME_W, FRAME_H, FRAME_BPP = 640, 480, 24
CAPTURE_DIR = "./captures"


def check_hardware(hwh_path=HWH_PATH):
    """确认硬件描述里确实是自研模块（而不是误加载了旧比特流）。"""
    if not os.path.isfile(hwh_path):
        print("[warn] hwh not found:", hwh_path)
        return
    with open(hwh_path, "r", encoding="utf-8", errors="ignore") as f:
        hwh = f.read()
    checks = {
        "ov5640_capture": "ov5640_capture",
        "video_kuwahara": "video_kuwahara",
        "video_mode_switch": "video_mode_switch",
        "video_style_bypass": "video_style_bypass",
    }
    print("---- hardware check ----")
    for name, key in checks.items():
        print("  %-22s %s" % (name, "OK" if key in hwh else "MISSING"))
    print("------------------------")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=1, help="抓取帧数")
    ap.add_argument("--bit", default=BIT_PATH)
    args = ap.parse_args()

    os.makedirs(CAPTURE_DIR, exist_ok=True)

    base = BaseOverlay(args.bit)
    cam = base.video.camera_in
    hdmi = base.video.hdmi_out

    iic = AxiIIC(base.ip_dict["cam_iic"])
    OV5640(0x3C, iic).init()

    cam.configure(VideoMode(FRAME_W, FRAME_H, FRAME_BPP), PIXEL_RGB)
    hdmi.configure(cam.mode, PIXEL_RGB)
    cam.start()
    hdmi.start()
    cam.tie(hdmi)

    check_hardware()

    try:
        for i in range(args.frames):
            frame = cam.readframe()
            out = os.path.join(
                CAPTURE_DIR,
                "frame_%s_%02d.png" % (datetime.now().strftime("%Y%m%d_%H%M%S"), i),
            )
            PIL.Image.fromarray(frame).save(out)
            print("saved:", out, frame.shape, frame.dtype)
    finally:
        hdmi.stop()
        cam.stop()
        print("video stopped")


if __name__ == "__main__":
    main()