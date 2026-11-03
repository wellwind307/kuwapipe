# -*- coding: utf-8 -*-
"""
================================================================================
 pynq_read_modes.py —— 在 PS（Jupyter / PYNQ）上分别读出「全处理」和「直通」的画面
================================================================================

前提
----
板子上运行的是本提交包 `board/bitstream/base.bit` + `base.hwh`。
板上按键（PL_KEY0 / L14）在「全处理(0) / 完全直通(1)」之间切换，LED2 亮 = 直通。

读出来的画面到底是什么
----------------------
DDR 帧缓存里存的是 **pixel_pack 之前** 的 24bit 画面，也就是：
   模式 0：前端 color_convert -> **中值 -> Kuwahara** 的结果
   模式 1：前端 color_convert -> 原始画面（中值/Kuwahara 都被旁路）

> gamma / 饱和度 / 色彩量化 在 hdmi_out 里、VDMA **之后**，所以 PS 读不到"最终成片"。
> 想对比"最终成片效果"，用下面的 style_preview() 在 numpy 里复刻 video_style.v
> （gamma 0.45 + 饱和度 1.0 + 16 级量化 + Bayer 抖动），和显示端一致。
> 如果希望 DDR 里直接就是最终成片，需要把 video_style 挪到 VDMA 前面（要改硬件）。

用法
----
  在板上:
      python3 pynq_read_modes.py            # 交互：提示你按按键
      python3 pynq_read_modes.py --auto     # 不交互，各抓 1 帧（用延时）
  在 Jupyter 里: 把下面各函数 import 或直接粘 cell。

注意
----
  1) readframe() 返回的是 DMA 缓冲区的**视图**，下一帧会被覆盖 -> 必须 np.array(..., copy=True)
  2) 每次切换模式后会有一帧左右的瞬态 -> grab() 先丢 drop 帧再抓
  3) 通道顺序：本脚本用 PIXEL_RGB 配置；若颜色不对，改成 PIXEL_BGR 或在 numpy 里翻转
================================================================================
"""
import os
import sys
import time

import numpy as np

# ----------------------------------------------------------------------------
# 1. 打开 overlay + 配置视频
# ----------------------------------------------------------------------------
CASE_DIR = os.path.dirname(os.path.abspath(__file__))
BIT = os.environ.get("KW_BIT", os.path.join(CASE_DIR, "bitstream", "base.bit"))
W, H = 640, 480      # 显示只能用 PYNQ DVI 支持的模式；上游实际几何是 800x480（右侧裁 20%）

# 说明：pynq 相关的 import 放在 open_video() 里，这样在没有 pynq 的机器上
# 也能 import 本文件用 style_preview() / grab() 做离线验证。


def open_video(bit=BIT, w=W, h=H):
    from pynq import Overlay
    from pynq.lib.video import VideoMode
    try:
        from pynq.lib.video import PIXEL_RGB
    except Exception:                             # 老版本 PYNQ 没有这个常量
        PIXEL_RGB = None

    base = Overlay(bit)
    cam = base.video.camera_in
    out = base.video.hdmi_out
    mode = VideoMode(w, h, 24)
    if PIXEL_RGB is not None:
        cam.configure(mode, PIXEL_RGB)
        out.configure(mode, PIXEL_RGB)
    else:
        cam.configure(mode)
        out.configure(mode)
    cam.start()
    out.start()
    try:
        cam.tie(out)                 # 直通显示（链路里已经带处理/直通开关）
    except Exception as e:
        print("tie() 失败（可能已经在直通状态）:", repr(e))
    return base, cam, out


# ----------------------------------------------------------------------------
# 2. 抓帧（丢掉切换瞬态）
# ----------------------------------------------------------------------------
def grab(cam, drop=8, n=3):
    """丢 drop 帧，再抓 n 帧；返回 (H,W,3) uint8 的**副本**"""
    for _ in range(drop):
        cam.readframe()
    f = None
    for _ in range(n):
        f = cam.readframe()
    return np.array(f, copy=True)


# ----------------------------------------------------------------------------
# 3. 在 PS 上复刻 video_style.v（gamma 0.45 + 饱和度 1.0 + 16 级量化 + Bayer 抖动）
#    这样就能看到"最终成片长什么样"，而不只是 DDR 里的中值+Kuwahara 结果
# ----------------------------------------------------------------------------
BAYER8 = np.array([
    [0, 32,  8, 40,  2, 34, 10, 42],
    [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44,  4, 36, 14, 46,  6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43,  1, 33,  9, 41],
    [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47,  7, 39, 13, 45,  5, 37],
    [63, 31, 55, 23, 61, 29, 53, 21]], dtype=np.int16)


def style_preview(rgb, gamma100=45, sat_q8=256, poster_levels=16):
    """
    与 video_style.v 一致的定点实现（默认参数 = 工程里的设置）：
      gamma LUT(0.45) -> 饱和度混合(Q8) -> 加 Bayer 抖动量 -> 屏蔽低位量化
    rgb: (H,W,3) uint8。
    """
    g = max(gamma100, 1) / 100.0
    lut = np.clip(np.round(255.0 * (np.arange(256) / 255.0) ** g), 0, 255).astype(np.int32)
    x = lut[rgb.astype(np.int32)]

    # 饱和度：out = ly + (sat_q8*(x-ly))>>8，ly = (77R+150G+29B)>>8
    ly = ((77 * x[..., 0] + 150 * x[..., 1] + 29 * x[..., 2]) >> 8)[..., None]
    x = np.clip(ly + ((sat_q8 * (x - ly)) >> 8), 0, 255)

    # 量化：step = 256/levels，先加 8x8 Bayer 的 [0,step) 抖动量再屏蔽低位
    step = 256 // max(poster_levels, 2)
    h, w = x.shape[:2]
    dith = (np.tile(BAYER8, (h // 8 + 1, w // 8 + 1))[:h, :w] * step) >> 6
    q = np.clip(x + dith[..., None], 0, 255).astype(np.int32)
    mask = 0xFF & (~(poster_levels - 1))
    return (q & mask).astype(np.uint8)


# ----------------------------------------------------------------------------
# 4. 主流程：先读"全处理"，按一下按键，再读"直通"
# ----------------------------------------------------------------------------
def main():
    auto = "--auto" in sys.argv
    base, cam, out = open_video()
    print("视频已启动: %dx%d, 当前默认模式 = 全处理（LED2 灭）" % (W, H))

    print("\n[1/2] 抓「全处理」画面（中值 + Kuwahara）...")
    time.sleep(0.5)
    f_proc = grab(cam, drop=10, n=3)
    print("      已抓:", f_proc.shape, f_proc.dtype)

    if auto:
        print("\n[--auto] 3 秒后抓「直通」画面 —— 请在这之前按下 PL_KEY0")
        time.sleep(3.0)
    else:
        try:
            input("\n[2/2] 现在请按一下板上 PL_KEY0（切到直通，LED2 应亮），然后回车...")
        except EOFError:
            time.sleep(2.0)
    time.sleep(0.3)
    f_raw = grab(cam, drop=15, n=3)
    print("      已抓:", f_raw.shape, f_raw.dtype)

    # ---- 存图 + 出对比图 ----
    from PIL import Image
    Image.fromarray(f_proc).save("frame_processed_ddr.png")
    Image.fromarray(f_raw).save("frame_raw_ddr.png")
    Image.fromarray(style_preview(f_proc)).save("frame_processed_style.png")
    Image.fromarray(style_preview(f_raw)).save("frame_raw_style.png")

    cmp_img = np.concatenate(
        [f_raw, f_proc, style_preview(f_raw), style_preview(f_proc)], axis=0)
    Image.fromarray(cmp_img).save("frame_compare.png")

    print("\n已保存:")
    print("  frame_raw_ddr.png        直通：DDR 原样（原始画面）")
    print("  frame_processed_ddr.png  全处理：DDR 里 = 中值+Kuwahara 结果")
    print("  frame_raw_style.png / frame_processed_style.png  PS 上复刻的最终显示效果")
    print("  frame_compare.png        四张竖着拼一起（从上到下：raw DDR / proc DDR / raw 成片 / proc 成片）")

    # ---- 简单数值对比（画质指标） ----
    a, b = f_raw.astype(np.float64), f_proc.astype(np.float64)
    mse = ((a - b) ** 2).mean()
    psnr = float("inf") if mse == 0 else 10 * np.log10(255.0 ** 2 / mse)
    print("\nraw vs proc(DDR): 平均绝对差 %.2f LSB, PSNR %.2f dB"
          % (np.abs(a - b).mean(), psnr))

    try:
        cam.stop()
        out.stop()
    except Exception:
        pass


if __name__ == "__main__":
    main()
