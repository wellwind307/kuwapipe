# 上板产物与运行脚本

| 文件 | 说明 |
|---|---|
| `../ready_to_test/base.bit` | 比特流（Vivado 2025.2 生成） |
| `../ready_to_test/base.hwh` | 硬件描述，交给 PYNQ 解析 |
| `../pynq_overlay/` | 同上，PYNQ 流程的副本 |
| `../pynq_read_modes.py` | PYNQ 侧读取/切换模式的脚本 |
| kuwahara_ps.py / kuwahara_ps.ipynb | **PS 侧主控制脚本**：加载 Overlay → 初始化 OV5640(800x480) → 直通 → 抓帧 → 硬件自检 |
| `../verify_kuwahara.py`、`../verify_style.py` | 与板上输出做比对的离线脚本 |

## 上板步骤（PYNQ）

```python
from pynq import Overlay
from pynq.lib.video import VideoMode
base = Overlay("base.bit")
cam, hdmi = base.video.camera_in, base.video.hdmi_out
mode = VideoMode(640, 480, 24)   # DVI 只支持 640x480/800x600/1280x720/1280x1024/1920x1080
cam.configure(mode); hdmi.configure(mode)
cam.start(); hdmi.start(); cam.tie(hdmi)
```

按 PL_KEY0 在处理/直通间切换，LED2 亮 = 直通。

> 上游链路是 800×480，但 PYNQ 的 DVI 输出不支持该分辨率（`hdmi.configure` 会抛
> `ValueError: Invalid Output resolution 800x480`），所以显示用 640×480，**右侧 20% 被裁掉**。
> 这是显示通路限制，不是 PS 代码问题。

## 板上实测：怎么做

### 0. 准备

- 场景**静止**（摆几个静物或贴一张打印图），避免 OV5640 自动曝光来回漂移；
- 显示器接 HDMI，手机或相机固定机位对着屏幕；
- 用厂商镜像（含 `pynq.lib.ov5640`）。

### 1. 测输出帧率

```bash
python measure.py fps --seconds 10
```

按“**不重复帧**”计数（读得快只会读到重复帧），输出 `measured fps`。
这是链路可持续帧率，受显示时序限制（60 Hz 附近），**不代表 PL 峰值算力**。

### 2. 测“噪声地板”（说明为什么板上不做逐像素比对）

```bash
python3 measure.py noise --seconds 2
```

同一场景连抓 4 帧，打印相邻帧的 mean / max / 差异像素比例。**这个数就是板上逐像素比对的下限**：
两次抓帧本身都差这么多，再拿它去和 golden 比就没有意义。

> 实测参考：本机约 mean 16~22 LSB、99% 像素差异，判定为 **50 Hz 工频 + 自动曝光呼吸**；
> 演示录屏时加 `--freeze --wb 2` 可显著稳定画面。

> 关键原因：Kuwahara 选象限是 **argmin(方差)** 的**离散判决**。4 个象限方差接近时，
> 输入几个 LSB 的噪声就可能让 argmin 翻到另一个象限，输出随之差出几十。
> 所以板上逐像素差异大 ≠ 实现错误。

**等价性由 xsim 证明**，不是靠板子：

| 证据 | 位置 | 结果 |
|---|---|---|
| 全尺寸 800x480 密集流 | `sim/kw_sim_full800x480.log` | captured 384000 / 384000，mismatch 0 |
| 与 golden 逐位比对 | `verify_kuwahara.py` | 内部像素 0 LSB |

### 3.（可选）诊断：板端输出更像哪种模型

```bash
python3 measure.py compare
```

需要按一次 PL_KEY0。它打印 `raw vs proc` 的平均差（应明显 >0，说明切换生效）以及
`proc vs golden` 的统计，**仅供排查，不作为 PASS/FAIL 判据**。

### 3. 拍“实测输出”素材

| 素材 | 要求 | 建议文件名 |
|---|---|---|
| 处理模式照片 | 同机位、同场景，能看清保边效果 | `board/media/proc_01.jpg` |
| 直通模式照片 | 同机位对照 | `board/media/raw_01.jpg` |
| 处理模式视频 | 10 s 左右，含缓慢移动镜头 | `board/media/proc_01.mp4` |
| 直通模式视频 | 同上 | `board/media/raw_01.mp4` |
| 按键切换视频 | 按 PL_KEY0，LED2 亮灭与画面切换同框 | `board/media/switch_01.mp4` |

拍照时把 **LED2 状态一起拍进去**，证明当前是哪种模式。

### 4. 填表

把测得的数字填进 `build/metrics.md`（已给出表格与计算值）。建议每个指标重复 3 次取中位数。