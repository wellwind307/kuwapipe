# 测试数据与参考结果

## 1. 参考模型与测试图

| 文件 | 说明 |
|---|---|
| `style_cartoon_640x480.py` | **golden 参考实现**（本队自建），Kuwahara + 中值 + gamma/饱和度/量化的浮点版本 |
| `fortest.jpg` | 演示输入图，**本队成员自行拍摄**（可替换为任意自拍图） |
| `preview_kuwahara.png` | 6 宫格对比：输入 / 中值后 / Kuwahara(RTL) / Kuwahara(golden) / 全链路 / 差异图 |
| `preview_kuwahara_crop.png` | 同一区域的细节裁剪对比 |

> `preview_*.png` 由 `sim/make_preview.py` 生成；`fortest.jpg` 仅用于演示与回归，替换后需重跑
> `sim/verify_kuwahara.py` 与 `sim/make_preview.py`。

## 2. 板上实测抓帧（处理 / 直通 成对对照）

四张都是**板端 DDR 抓帧**（`cam.readframe()` 直接存 PNG，640×480 RGB888），
即 **VDMA 之前**的数据：处理模式下 = 3×3 中值 + Kuwahara 的输出，
直通模式下 = 摄像头原始画面；**不含** gamma / 饱和度 / Bayer 量化（那三级在 VDMA 之后的显示端）。

| 文件 | 场景 | 模式 | 说明（可核对的特征） |
|---|---|---|---|
| `proc_outdoor.png` | 窗外建筑与树 | 处理（中值+Kuwahara） | 树叶纹理被归并成色块、轮廓保留；亮度梯度能量 3.30 |
| `raw_outdoor.png` | 同上 | 直通 | 树叶细节保留；梯度能量 6.51（是处理图的约 2 倍） |
| `proc_desk.png` | 桌面静物（瓶子/笔/鼠标） | 处理（中值+Kuwahara） | 桌面与暗部平滑成色块、物体边界仍清晰；梯度能量 4.87 |
| `raw_desk.png` | 同上 | 直通 | 细节与噪点保留；梯度能量 6.52 |

- 同场景**处理 vs 直通**的帧间平均绝对差：窗外 10.5 LSB、桌面 6.0 LSB，
  与 `build/metrics.md` §3 里 `measure.py compare` 的实测（mean 5.97）量级一致 —— 说明按键切换确实生效。
- 四张图低 4 位几乎都不为 0（0.3%–5.8%），**不存在 16 级量化痕迹**，可作为「抓的是 VDMA 前数据」的旁证。
- 原始文件名是板端脚本的自动时间戳（板子未联网校时，显示 2021-11-18）：
  `044243`→`proc_outdoor`、`044310`→`raw_outdoor`、`052233`→`raw_desk`、`052241`→`proc_desk`。
  其中 `raw_outdoor.png` 与 `board/kuwahara_ps.ipynb` 里保存的那张抓帧是同一帧。

> 用途：作为指南 A4「实测输出」的板端证据，可与 `build/metrics.md` 的帧率/噪声地板数字配合引用。
> 若还需要「实物照 / 现场录屏」（显示器与开发板同框、按键切换过程），仍建议补到 `board/media/`。
