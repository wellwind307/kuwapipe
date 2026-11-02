# KuwaPIPE —— 实时 Kuwahara 保边平滑硬件加速（设计报告 · 初稿）

> 2026 全国大学生嵌入式芯片与系统设计竞赛 · AMD FPGA 创新设计赛道 · 自主选题赛道（初级组）
>
> 状态：**初稿**。正文已用仓库内素材写成，凡需队伍填写处均以 `【待填：…】` 标出。
> 与本报告配套：`LLM_COLLAB_LOG.md`（大模型协作记录）、`../build/metrics.md`（指标汇总）、
> `../THIRD_PARTY_NOTICES.md`（第三方许可）、`../README.md`（工程入口）。

---

## 0. 封面信息

| 项 | 内容 |
|---|---|
| 作品名称 | KuwaPIPE —— 实时 Kuwahara 保边平滑硬件加速 |
| 选题一句话 | 【待填：一句话概括，例如"在 Zynq 上以 1 pixel/clk 定点流水线实现逐位可复现的实时 Kuwahara 保边平滑，并支持板上按键在处理/直通间切换"】 |
| 学校 | 【待填：学校名称】 |
| 队名 | 【待填：队名】 |
| 队员与分工 | 【待填：成员姓名 + 各自分工（算法/RTL/PS/验证/文档）】 |
| 指导教师 | 【待填：指导教师】 |
| 是否开源 | 【待填：是 / 否；若开源补 GitHub/Gitee 地址】 |

---

## 1. 选题背景与创新点

### 1.1 背景与问题

实时视频流处理（去噪、风格化、目标检测前置滤波）要求在**一帧时间内**完成逐像素运算，
且延迟、吞吐、资源都要可控。Kuwahara 保边平滑（Kuwahara et al., 1976）是一种经典的
**保边去噪**算子：以每个像素为中心取 7×7 邻域，按中心划分出 4 个 4×4 象限，各自计算
均值和方差，输出**方差最小象限的均值**。因为方差最小意味着该象限内部最"平坦"、最不
可能跨越边缘，所以它能在去噪的同时保留边缘与块状纹理，广泛用于卡通化、绘画风格化、
以及医学图像的平滑预处理。

问题在于它的**计算量**：每个输出像素要算 4 个象限、每象限 16 个像素的**均值与方差**
（涉及平方、求和、除法），再比较 4 个方差取最小。在 CPU 上用浮点逐像素实现，代价高、
帧率低；GPU 方案则有延迟与功耗问题；而现成的"纯 HLS 一键 IP"通常把边界、舍入、接口
时序做成黑盒，难以给出"与参考模型逐位一致"的确定性保证，也无法在提交时说明每一拍
数据是如何流转的。

### 1.2 本作品做了什么

本作品把 Kuwahara 保边平滑做成了一个 **1 pixel/clk 的定点流水线硬件模块**，插入到
摄像头输入的实时链路上：**OV5640 DVP → 3×3 中值 → Kuwahara(r=3) → gamma/饱和度/色彩
量化 → HDMI**，全程无浮点、无除法、无全图统计；并在板上用 **PL_KEY0** 在「全处理 /
完全直通」两模式间切换（LED2 指示），以便直观对比处理效果。PS 侧（PYNQ）只做 Overlay
加载、OV5640 I2C 初始化与 VideoMode 配置。

### 1.3 创新点 / 差异点

1. **整数判别式替代浮点方差，实现逐位一致。**
   用 `disc = 16·ΣY² − (ΣY)²` 作为象限选择依据：它与浮点方差 `var` 只差一个正的常数
   因子 `2^20`，因此 `argmin(disc) ≡ argmin(var)`；且相关求和项 ≤ 2^41 ≪ 2^53，float64
   表示无误差。均值一侧用 `q + ((rem>8) | (rem==8 & q[0]))` 精确等价于 `np.round` 的
   **银行家舍入**。结果是：**RTL 与浮点 Python golden 在内部像素上 0 LSB 差异**。
2. **扩展网格 flush，帧几何不变、不丢像素。**
   7×7 窗口意味着输出 (y,x) 要等输入推进到 (y+3, x+3) 才能产生。本设计在帧尾/行尾
   多喂 3 行、每行多喂 8 拍，这些 flush 拍不消耗输入（`i_ready=0`），靠消隐期自行走完，
   输出仍是精确的 H×W 个像素，帧对齐不漂移。
3. **输出 skid 寄存器，反压下不丢不重。**
   下游反压或上游气泡时整条流水暂停；已算好的输出被取走后清 `out_vld`，避免"输入有
   气泡 + 下游 ready"时下游重复收到同一像素。
4. **板上可切换对照（处理/直通），且切换不引入错拍。**
   直通模式下中值/Kuwahara 链保持"空转"（避免 HLS 数据流管线在半帧停住导致恢复黑帧），
   输出侧 gamma/饱和度/量化走同样延迟的 bypass 支路，切换无缝。
5. **版权干净、可独立重建。** 采集 IP 由正点原子专有实现替换为**自研等价实现**
   （逐拍协同仿真 91,063 拍 / 0 失配）；IP 仓库内置，不依赖任何外部路径。

---

## 2. 设计原理与功能框图

### 2.1 算法到硬件的映射

Kuwahara(r=3) 每输出一个像素，需要 7×7=49 个输入像素。硬件上不可能为每个输出重读 49
个像素，采用**行缓存 + 列滑动窗口**结构：

```
s_axis ─► [stage A 寄存] ─► 6 级行缓存(RGB 24b + luma 16b) ─► 7×7 窗口
                                            │
                ┌───────────────────────────┴──────────────────┐
                ▼                                              │
     7 行 luma 平方 + 4 行竖直和 (stage B)                      │
                ▼                                              │
     水平 4 列滑动和 box4col ×10（Y/Y²/R/G/B × 上下半窗）        │
                ▼                                              │
     disc = 16·S2 − S²（DSP 乘法）→ 寄存 (stage C)              │
                ▼                                              │
     比较选最小 → 4:1 选象限 RGB 和 → round-half-even (stage D)  │
                ▼                                              │
     输出 skid 寄存器 ─► m_axis（TVALID/TLAST/TUSER 自生成）     │
```

关键算子（与 golden 一一对应）：

```
亮度   Y  = 77R + 150G + 29B            (Q8，16bit)
象限和 S  = ΣY          (4×4 = 16 个)
       S2 = ΣY²
判别式 disc = 16·S2 − S²                 (恒 ≥ 0)
选象限      disc 最小者，平局顺序 TL > TR > BL > BR
输出均值    round-half-even( ΣRGB / 16 )
```

### 2.2 流水线划分（5 级）

| 级 | 工作 | 说明 |
|---|---|---|
| stage A | 输入寄存 | 打拍稳定输入，驱动行缓存 |
| stage B | luma 平方 + 竖直和 | 7 行 luma 平方 + 4 行竖直和 |
| box4col | 水平 4 列滑动和 | 10 组（Y/Y²/R/G/B × 上下半窗），增量更新 |
| stage C | disc 计算 + 寄存 | `16·S2 − S²`（DSP） |
| 输出级 | 比较 + 4:1 选择 + 舍入 | 选方差最小象限的 RGB 均值，银行家舍入 |

把"3 乘 + 平方""20×20 乘 + 40bit 减""比较 + 选 + 舍入"分到不同级，100 MHz 下有余量。

### 2.3 行缓存与扩展网格 flush

- 6 级行缓存（RGB 24b + luma 16b，共 12 个环形 BRAM）；读指针 = 写指针 + 1，抵消寄存器
  读的 +1 拍，级联不产生列偏移。
- 每帧多喂 3 行、每行多喂 8 拍：3 拍给右边界（最后一列 x=W-1 的窗口要到 col=W+2），
  5 拍给流水排空（4 级内部 + 1 级 skid）。关键是它保证"一行 = 固定拍数"，否则行缓存
  行对齐会在帧间漂移。
- 吞吐 1 pixel/clk；每帧实际占用 (H+3)×(W+8) = 483×808 = 390,264 拍，比 H·W 仅多 1.6%。

### 2.4 整体链路与插入点

插入点在 `/video/camera_in` 层次内（100 MHz 时钟域）：

```
改前： median_blur_color_0/video_out ──────────────► pixel_pack/stream_in_24
改后： median_blur_color_0/video_out ─► video_kuwahara_0 ─► pixel_pack/stream_in_24
                                        (s_axis)   (m_axis)
```

这样接，Kuwahara 的结果先经 `pixel_pack → VDMA → DDR`，**PS 端能直接读到 Kuwahara 输出**
做比对；显示端 `video_style_0`（gamma/饱和度/量化）完全不用动。

---

## 3. 软硬件划分依据与接口设计

### 3.1 为什么把中值 / Kuwahara / gamma 放 PL

- **中值与 Kuwahara 是逐像素、数据量巨大的局部邻域运算**（7×7 窗口、每像素 4×16 方差
  求和），放到 CPU 上做实时处理无法满足帧率；放 PL 上以 1 pixel/clk 流水线实现，吞吐为
  **100 Mpixel/s**，是相机需求（约 18.4 Mpixel/s）的 **5.4 倍**。
- **gamma/饱和度/量化是逐像素点运算**，同样有强并行度，且与显示链路同层，放 PL 里与
  Kuwahara 共享流水线，避免数据在 PS/PL 之间往返。

### 3.2 为什么路由与按键放 PL、PS 只做配置

- **模式切换放 PL**：切换要在像素流中做到"无缝"，PS 的 GPIO 轮询延迟（毫秒级）与
  流水线的拍级时序不匹配。放 PL 用一个 `video_mode_switch` 模块，按键消抖 20 ms + 2 级
  同步后直接在流内做 1 拍路由，切换瞬态只丢 4 拍（已由 testbench 验证为预期代价）。
- **PS 只做配置**：PYNQ 加载 Overlay、通过 I2C 初始化 OV5640（输出 800×480 RGB565）、
  配置 VideoMode。这样 PS 代码简单、可移植，且"从零复现"的门槛低。

### 3.3 接口设计

| 接口 | 用途 | 理由 |
|---|---|---|
| AXI4-Stream（`s_axis`/`m_axis`） | 像素流进出 Kuwahara、中值、pixel_pack | 视频数据是单向流，AXI-Stream 的 `TVALID/TREADY/TLAST/TUSER` 正好表达像素/行/帧边界与反压 |
| `vid_io`（自研采集 IP） | OV5640 DVP 侧的 `pclk/vsync/href/data` | 与相机物理接口对齐；命名避开工程已有 `cmos_frame_*` 接口定义，防止 BD 凭空推断出多余接口 |
| AXI-Lite / AXI（PS↔PL） | 配置 VDMA/VTC、读按键、写 LED | 控制面低带宽，标准总线 |
| `mode` 准静态信号（跨时钟域） | 100 MHz→142.9 MHz 传递模式位 | 2 级同步器 + `ASYNC_REG` + `set_false_path`，属标准 CDC 处理 |

### 3.4 显示分辨率限制（一个绕不开的坑）

上游链路（OV5640 + HLS 中值 + Kuwahara）固定 **800×480**，但 PYNQ 的 DVI 输出只有
`(640,480)(800,600)(1280,720)(1280,1024)(1920,1080)` 五种模式，800×480 不在其中，
`VideoMode(800,480,24)` 会在 `hdmi.configure()` 抛 `ValueError`。因此显示用 **640×480**，
右侧 20% 被裁掉——这是显示通路硬限制，不是代码 bug；要显示完整 800 宽需改硬件几何。

---

## 4. 优化过程与前后对比

### 4.1 优化轮次

| 版本 | LUT | FF | BRAM | DSP | 说明 |
|---|---|---|---|---|---|
| 基线（无 Kuwahara） | 21,372 | 25,749 | 13.5 | 0 | 原工程（中值 + style 链路） |
| + Kuwahara r=3 | 22,765 | 27,375 | 22.5 | 19 | 新增 7×7 四象限保边平滑 |
| + 按键切换 | 22,827 | 27,514 | 22.5 | 19 | `video_mode_switch` + bypass，仅 +62 LUT / +139 FF |
| + 自研采集 IP | 22,864 | 27,514 | 22.5 | 19 | 替换正点原子采集 IP（本提交版） |

### 4.2 各轮判断依据与代价

1. **加 Kuwahara**：为在原链路上引入保边平滑，代价 +1,393 LUT、+9 BRAM tile（12 个行缓存）、
   19 个 DSP（7 平方 + 8 判别式 + 3 亮度乘 + 1）。关键结论：**不降帧率**（链路本就时序驱动，
   相机上限 40 fps 不变），单像素吞吐仍 1 pixel/clk。
2. **加按键切换**：为了直观对比"处理 vs 直通"，代价极小（路由开关 + 旁路 mux + 消抖计数）。
   设计取舍：直通模式下中值/Kuwahara 链保持空转，避免 HLS 数据流管线停半帧导致恢复黑帧。
3. **替换采集 IP**：出于版权合规（正点原子 `All rights reserved`），自研等价实现替换。
   资源几乎无变化（+37 LUT）。

### 4.3 资源与时序结论

- 最终资源：**LUT 22,864（42.98%）/ FF 27,514（25.86%）/ BRAM 22.5（16.07%）/ DSP 19（8.64%）**。
- 时序：clk_fpga_0（100 MHz）WNS −0.571 ns，clk_fpga_1（142.9 MHz）WNS −0.115 ns；
  **两个时钟域的最差路径均位于原有 HLS IP 内部**（中值 / color_convert），
  Kuwahara 与新增切换逻辑不在任何违规路径上（`report_timing_summary` 中无违规路径经过
  `video_kuwahara_0`）。

### 4.4 性能口径（表）

| 指标 | 数值 | 类型 |
|---|---|---|
| 输出帧率 | 40.05 fps（10 s，401 帧全不重复） | 实测 |
| 处理吞吐（峰值） | 1 pixel/clk @100 MHz = 100 Mpixel/s | 设计值 |
| 单帧处理占用 | 390,264 clk ≈ 3.90 ms（占帧周期 15.6%） | 设计值 |
| 帧内延迟 | ≈2.43k clk ≈ 24.3 µs | 设计值 |
| 功能一致性 | 全尺寸 384000/384000 像素 bit-exact；采集 IP 91063 拍 0 失配 | 仿真 |

> 完整指标与测量方法见 `../build/metrics.md`。

---

## 5. 大模型协作记录

见 `report/LLM_COLLAB_LOG.md`（已按 6 个真实节点整理，**真实对话原文需队伍导出后粘贴**）。

---

## 6. 技能包的提炼过程

本作品把开发中反复验证有效的经验沉淀为 `skill/` 下 4 项技能，每项均**不与本队题目绑定**
（换题目、换板卡仍可用），并写明适用场景 / 使用方法 / 已验证效果 / 失效条件：

| 技能 | 提炼来源（哪次失败/观察） | 如何验证 | 边界 |
|---|---|---|---|
| S1 `ip-equiv-cosim` 逐拍等价性协同仿真 | 替换正点原子采集 IP 时，不敢"看着能出图"就算过；需要一个可量化的 PASS 判据 | 91,063 拍 0 失配；过程中真抓出"消隐期保持 vs 清零"一处差异 | 原 IP 含未初始化存储/异步 CDC 且无确定初值时，逐拍不收敛，退化为逐帧比对 |
| S2 `vivado-ip-swap` BD 内替换 IP | module_ref 输出不被当时钟源、`ip_repo_paths` 覆盖丢仓库、端口名撞接口定义 | 替换后 validate rc=0、synth Complete、bitstream 0 error | 新 IP 端口语义不同时必须先用 S1 证等价 |
| S3 `bit-exact-golden` 浮点 golden 与定点逐位对齐 | 想证明"硬件实现没引入偏差"，而不是"大概差不多" | 内部像素 0 LSB；边界改 replicate 后全图 0 LSB | 含迭代/自适应/全图统计的算法只能做误差上界 |
| S4 `hls-ip-geometry` HLS IP 几何不被 VideoMode 配置 | 上板出现 4 重错位重影，根因是行缓存按 640 算、上游实际 800 | 按 800 修正后重影消失，全尺寸 bit-exact | HLS 把行列做成可配寄存器时不适用 |

详细用法与脚本骨架见 `../skill/README.md`。

---

## 7. 复现说明

### 7.1 环境

| 项 | 值 |
|---|---|
| 器件 / 板卡 | xc7z020clg400-2（Zynq-7000，PYNQ-Z2 兼容板） |
| 工具 | Vivado 2025.2 |
| PS 侧 | PYNQ 厂商镜像 **Release 2025_08_27**（**必须**，含 `pynq.lib.ov5640`） |

### 7.2 从零构建

```bat
:: 1) 打开工程（IP 仓库已内置 ip_repo_local，无外部依赖）
::    base.xpr

:: 2) 改了采集 RTL 才需要重新打包 IP
vivado -mode batch -source package_capture_ip.tcl

:: 3) 综合 + 实现 + bitstream（自动复制到 ready_to_test/ 与 pynq_overlay/）
vivado -mode batch -source build_btn.tcl
```

### 7.3 上板运行

```python
from pynq import Overlay
from pynq.lib.video import VideoMode
base = Overlay("base.bit")
cam, hdmi = base.video.camera_in, base.video.hdmi_out
mode = VideoMode(640, 480, 24)      # DVI 仅支持固定模式，写 800x480 会 ValueError
cam.configure(mode); hdmi.configure(mode)
cam.start(); hdmi.start(); cam.tie(hdmi)
# 按 PL_KEY0 切换处理/直通，LED2 亮 = 直通
```

板上测量：

```bash
python3 board/measure.py fps --seconds 10        # 输出帧率
python3 board/measure.py noise --freeze --wb 2   # 噪声地板（冻结 AE + 固定白平衡）
python3 board/measure.py compare                 # 仅诊断，不作判据
```

### 7.4 功能一致性验证（复现者可自行核对）

```bat
cd vs_sim
run_kw_sim.bat                 rem 64x48 小图快速回归
rem 全尺寸：xvlog 加 -d TB_FULL 再 xelab/xsim（日志 sim/kw_sim_full800x480.log）
```

预期：全尺寸 800×480 密集流 `captured=384000/384000, mismatch=0`；采集 IP 等价性
`91063 拍 / 0 失配`。

### 7.5 常见失败点

1. 官方 PYNQ 镜像上 `from pynq.lib.ov5640 import OV5640` 会 ImportError——需用**厂商镜像**。
2. `VideoMode(800,480,24)` 抛 `ValueError`——显示只能用 640×480。
3. 上电后立刻按键可能"按两下才切"——先松手等 1 秒让按键极性自动识别完成。
4. 改 `ov5640_capture.v` 后忘跑 `package_capture_ip.tcl`，BD 仍用旧 IP 副本。

---

## 附：可直接引用的关键数据

| 项 | 值 |
|---|---|
| 器件 | xc7z020clg400-2 |
| 工具 | Vivado 2025.2；PYNQ 厂商镜像 Release 2025_08_27 |
| 系统帧率 | 40.05 fps（受 OV5640 时序限制） |
| 处理吞吐 | 1 pixel/clk @100 MHz = 100 Mpixel/s（相机需求的 5.4 倍） |
| 单帧处理占用 | 483×808 = 390,264 clk ≈ 3.90 ms（占帧周期 15.6%） |
| 帧内延迟 | ≈2.43k clk ≈ 24.3 µs |
| 资源 | LUT 22,864 / FF 27,514 / BRAM 22.5 / DSP 19 |
| 基线（无 Kuwahara） | LUT 21,372 / FF 25,749 / BRAM 13.5 / DSP 0 |
| 时序 | clk_fpga_0 WNS −0.571 ns；clk_fpga_1 −0.115 ns（违规点均在原有 HLS IP 内部） |
| 功能一致性 | 全尺寸 384000/384000 bit-exact；采集 IP 等价性 91,063 拍 0 失配 |
