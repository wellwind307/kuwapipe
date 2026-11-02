# PS 侧代码整理说明

## 1. 来源与处理

原 `ps.ipynb` 由 **PYNQ base overlay 的 OpenCV 人脸检测示例**改编而来
（板卡镜像内对应 `jupyter_notebooks/wellwind/opencv_face_detect_hdmi_live.py`，其上游为 Xilinx PYNQ 示例）。
本次整理做了两件事：

1. 删除全部与本作品无关的残留（人脸检测、素材引用、调试代码）；
2. 按实际硬件重写为「加载 Overlay → 初始化 OV5640 → 800x480 直通 → 抓帧 → 自检」。

整理后仅保留通用的 PYNQ 调用形态（`BaseOverlay` / `VideoMode` / `tie`），
其余为针对本作品重写的代码。第三方声明见 `../THIRD_PARTY_NOTICES.md`。

## 2. 删掉的内容

| 原内容 | 为什么删 |
|---|---|
| 标题「OpenCV Face Detection HDMI」与 haarcascade 参考链接 | 与本作品无关，且引用的是他人示例的素材 |
| 人脸检测相关流程（`cv2`、级联分类器、检测循环、画框） | 本作品不做人脸检测 |
| `Step 2 / Step 3` 之类过程性标题 | 属示例的叙述结构，已重写 |
| 股票照片 URL（示例素材出处） | 与本作品无关 |
| 保存到 `/home/xilinx/jupyter_notebooks/base/video/data/face_detect.jpg` | 名称与路径都是示例残留；改为 `./captures/frame_<时间戳>.png` |
| 重复的 `camera_in.tie(hdmi_out)` 单元 | 前面已 tie，重复无意义 |
| `print("video_style" in open(p).read())` 调试单元 | 改为结构化硬件自检（逐项确认自研 IP 是否在 hwh 里） |
| `from pynq.lib.video import *`、`from pynq.lib.iic import *` | 改为显式导入，避免命名污染 |

## 3. 保留且不能删的

| 内容 | 原因 |
|---|---|
| `AxiIIC(base.ip_dict["cam_iic"])` + `OV5640(0x3C, iic).init()` | OV5640 必须经 I2C 配置；`init()` 的寄存器表决定输出 **800x480 RGB565**（`0x3808/09=0x0320`、`0x380a/0b=0x01E0`） |
| `BaseOverlay("./base.bit")` | 该 Overlay 的 `video` 层次提供 `camera_in` / `hdmi_out` |
| `cam.tie(hdmi)` | 直通显示；PL 链路里已含处理 |

## 4. 分辨率：只能用 640x480，不是 800x480（重要更正）

硬件链路（OV5640 + HLS 中值 + Kuwahara）固定 **800×480**，但 PYNQ 的 DVI 输出只有五种模式
（`pynq/lib/video/dvi.py` 的 `_outputmodes`）：

```
(640,480) (800,600) (1280,720) (1280,1024) (1920,1080)
```

`800×480` **不在其中**，所以 `VideoMode(800, 480, 24)` 会在 `hdmi.configure()` 抛
`ValueError: Invalid Output resolution 800x480`。

只能用 **640×480**：画面稳定，但每行只取前 640 像素，**右侧 20% 被裁掉**。
这不是 PS 代码的 bug，是显示通路的硬限制。

> 早期文档里“用 800×480 可 1:1 看完整画面”的说法是**错误的**，已在各 README 中更正。
> 若确实需要完整 800 宽，只能改硬件：把 HLS 中值 IP 的模板尺寸与 Kuwahara 的 `W/H`
> 一起改成受支持的显示模式（如 1280×720）并重新综合，PS 侧无法绕过。

## 5. 尚未上板验证的点

我没有板子，以下三处请你在板上确认一次：

1. `base.ip_dict["cam_iic"]` 的键名是否与 hwh 中的实例名一致（不一致会 KeyError）；
2. `base.buttons.read()`：本设计的 `btns_gpio` 是 **2 bit**，而 `BaseOverlay` 内部会
   `setlength(3)`（为通用 base 写的）。`setlength` 只改属性、不做越界检查，通常无害，
   但若读写 LED 时报错，就是这里的不匹配；
3. 抓帧分辨率：应为 `frame.shape == (480, 640, 3)`（显示侧 640×480 裁切后的结果）。
## 6. 运行环境与依赖出处（重要）

本作品 PS 侧**必须使用开发板厂商提供的 PYNQ 镜像**（镜像 `REVISION` 为 `Release 2025_08_27`，
基于 `github.com/Xilinx/PYNQ`）。原因如下：

| 模块 | 出处 | 上游 PYNQ 是否有 |
|---|---|---|
| `pynq.lib.video`（`VideoMode` / `PIXEL_RGB` / HDMI 层次） | Xilinx，Copyright 2021 | ✅ 有 |
| `pynq.lib.iic.AxiIIC` | Xilinx，Copyright 2018 | ✅ 有 |
| `pynq.overlays.base.BaseOverlay` | Xilinx 2017 文件，**被厂商改过**（docstring 为 "The Base overlay for the Pynq-atk"） | ⚠️ 有，但行为不同 |
| `pynq.lib.ov5640.OV5640` | `__copyright__ = "Copyright 2020, alientek"` | ❌ **没有，是厂商添加的** |

因此：

- 在官方 PYNQ 镜像上运行本脚本会在 `from pynq.lib.ov5640 import OV5640` 处 `ImportError`；
- 这属于**平台依赖**，不是作品缺陷，但按指南"可由他人从零复现"的要求必须在文档中声明；
- 上述库**均不随本作品分发**（它们位于板端镜像中），本作品只调用、不复制。

复现时请先确认镜像：

```python
import pynq, pynq.lib
print(getattr(pynq, "__version__", "unknown"))
import pynq.lib.ov5640   # 存在即为厂商镜像
```
