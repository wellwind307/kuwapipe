# base_2025_2_kuwahara_btn —— 板上按键切换「全处理 / 完全直通」

> **本副本的额外改动（版权合规）**：摄像头采集 IP 已由正点原子 `cmos_capture_data` 替换为
> 自研 `ov5640_capture`（`user:ip:ov5640_capture:1.0`）。与原 IP 做了同激励逐拍等价性协同仿真：
> **91,063 拍 / 0 失配 / PASS**。替换脚本 `modify_capture.tcl`、打包脚本 `package_capture_ip.tcl`，
> 仿真见 `vs_sim/tb_ov5640_capture.v`。详见 `THIRD_PARTY_NOTICES.md`。

`base_2025_2_median_style_kuwahara` 的**另存副本**（那个工程未动）。在它基础上加了：

> **按板上 PL_KEY0（L14）可以在两种模式间切换，按一下切一次：**
>
> | 模式 | 内容 | 指示 |
> |---|---|---|
> | 0（上电默认） | 全处理：3×3 中值 → Kuwahara(r=3) → gamma(0.45) → 饱和度 → 色彩量化 | LED2 灭 |
> | 1 | 完全直通：摄像头数据原样送出去，中值 / Kuwahara / gamma / 饱和度 / 量化 全不做 | LED2 亮 |

![模式](preview_kuwahara.png)

---

## 1. 体系结构（两种模式怎么实现的）

```
                  ┌───────────── 处理支路 ─────────────┐
                  │                                   │
 camera_in:       ▼                                   │
  frontend/video_out → color_convert → axis_register_slice_0
                                            │
                                            ▼
                                  video_mode_switch_0  ── m_proc ─► median_blur_color_0 ─► video_kuwahara_0
                                    （本次新增）  ▲                          │
                                            │   └──────────── s_proc ◄──────┘
                                            │
                            m_axis ─────────┴──────► pixel_pack → VDMA → DDR
                                                        │
 hdmi_out:                             VDMA → pixel_unpack → color_convert
                                                              │
                                                              ▼
                                                    video_style_bypass_0
                                                     （加了 bypass 端口）
                                                              │
                                                              ▼
                                              frontend/video_in → v_axi4s_vid_out → rgb2dvi → HDMI
```

* **输入侧**：新模块 `video_mode_switch`（`base.srcs/sources_1/new/video_mode_switch.v`）
  * `mode=0`：`s_axis → m_proc → 中值 → Kuwahara → s_proc → m_axis`（正常处理）
  * `mode=1`：`s_axis → 1 拍寄存 → m_axis`（直通）；中值+Kuwahara 仍在跑，但它们的输出
    在模块内部被丢弃（`s_proc_tready=1`）。
  * 为什么直通模式下还要"空转"中值链：HLS 中值 IP 是数据流流水线，直接断输入会让它停在
    半帧状态，恢复时要重新等 TUSER，切回去可能黑好几帧；让它一直跑就没有这个恢复过程。
* **输出侧**：`video_style`（gamma/饱和度/量化）加了运行期 `bypass` 端口 —— 旁路时输出
  走它内部同样 4 拍延迟的 `raw3`，所以这一段切换**完全无缝**，不会错拍。
* 所以"完全直通"= 只剩框架（color_convert、pixel_pack/unpack、VDMA 帧缓存），
  三个处理块（中值、Kuwahara、gamma/饱和度/量化）全部不生效。

### 切换时的瞬态（正常现象）

两条支路延迟不同（处理支路比直通晚约 3~5 行 + 中值 IP 自身延迟），所以**按下的那一瞬间**
画面会跳一下/撕一帧，VDMA 会在下一个 TUSER（帧首）重新对齐，之后就稳定了。
这是这类"双支路切换"的固有代价，属于预期行为，不是 bug。

---

## 2. 按键与 LED

### 按键

| 项 | 值 |
|---|---|
| 用哪个键 | **PL_KEY0**（`btns_tri_i[0]`，引脚 **L14**） |
| 行为 | 按下（上升沿）切换一次；带 **20 ms 消抖** + 2 级同步 |
| 极性 | **上电 100 ms 静置后自动识别**空闲电平（低有效/高有效都能用），XDC 里还开了内部上拉 `PULLTYPE PULLUP` |
| 复位后默认 | `mode=0`（全处理） |
| PS 侧 | `btns_gpio` 仍保留（PS 照样能读按键状态），另外把 `btns_tri_i` 分了一路给 PL（`btn_sl` 取 bit0） |

> 如果发现"按一下没反应 / 按两下才切"（例如上电时手按着键导致极性判断反了）：
> 在 BD 里把 `video_mode_switch_0` 的 `CONFIG.AUTO_POL` 设成 `0`，
> 再用 `CONFIG.BTN_ACTIVE_LOW`（1=按下为低）显式指定即可，重跑 `build_btn.tcl`。

### LED

| LED | 引脚 | 用途 |
|---|---|---|
| LED0 | J16 | PS 的 `leds_gpio[0]`（不变） |
| LED1 | H15 | PS 的 `leds_gpio[1]`（不变） |
| **LED2** | **L15** | **PL 端口 `mode_led`：raw 直通模式点亮** |

> 为什么用 LED2 而不是 LED0：三个 LED 都在同一个 AXI GPIO 的**向量**里，从中间切一位
> 需要拆 GPIO 向量；取最高位只需把 `leds_gpio` 从 3 bit 改成 2 bit，**PS 的 LED0/LED1
> 编号和物理位置完全不变**，代价最小。
> 因此 `leds_gpio` 现在是 **2 bit**（如果你的 PS 脚本以前写 3 bit，最高位会被忽略）。

---

## 3. 验证

### 3.1 模式切换自校验（xsim）

```bat
cd vs_sim
rem 编译 + 仿真（脚本里 CLK_HZ=100000，把 20ms/100ms 缩成 2000/10000 拍，逻辑一致）
```

`vs_sim/tb_video_mode_switch.v` 用一个"假处理链"（8 拍延迟 + 每通道 +1/+2/+3）代替
中值+Kuwahara，检查：

```
PHASE1 pol locked, mode=0 ...
PHASE2 mode=0 ...            处理模式：输出必须是"处理后"的数据
PHASE3 after press1 mode=1   按一下（带 6 次抖动）-> 切到直通
PHASE4 mode=1 ...            直通模式：输出必须是原始数据
PHASE5 after press2 mode=0   再按一下 -> 切回处理
PHASE6 mode=0 ...
captured=13292  sent=13296  mismatch=0
=== PASS ===  (模式切换瞬态丢 4 拍，属预期)
```

即：**两种模式下数据全对（mismatch=0）**，切换瞬态丢的 4 拍就是上面说的固有代价。

### 3.2 图像处理本身

Kuwahara / 中值 / gamma 那部分和前一版**完全一样**（只多了一个路由开关和旁路 mux），
前一版的验证结论继续有效：

* Python 位精确模型 vs golden：**内部像素 0 LSB 差**
* 全尺寸 800×480 密集流 xsim：`384000/384000 mismatch=0` PASS
* 详见 `../base_2025_2_median_style_kuwahara/README_kuwahara.md`

---

## 4. 资源与时序（Vivado 2025.2，xc7z020clg400-2）

综合 / 实现 / bitstream 全部 **0 error**（`write_bitstream Complete!`），
`ready_to_test/` 与 `pynq_overlay/` 已更新。

| 项目 | 上一版（只有 Kuwahara） | 本版（+按键切换） |
|---|---|---|
| Slice LUTs | 22 765 (42.8%) | **22 827 (42.9%)** |
| Slice Registers | 27 375 (25.7%) | **27 514 (25.9%)** |
| Block RAM Tile | 22.5 | 22.5 |
| DSP48E1 | 19 | 19 |
| clk_fpga_0 (100 MHz) WNS | −0.567 / 122 端点 | **−0.498 / 146 端点**（路径仍在 HLS 中值内部） |
| clk_fpga_1 (142.9 MHz) WNS | −0.138 / 3 端点 | **−0.304 / 15 端点**（路径仍在 `color_convert` 内部） |
| **包含新模块的违规路径** | — | **0 条** |

即：加按键切换只多了 **62 个 LUT / 139 个 FF**（路由开关 + 旁路 mux + 消抖计数），
两个时钟域的最差路径仍然都在**原工程**的 HLS IP 内部，新逻辑不在任何违规路径上。

### 一个跨时钟域约束

`mode` 从 100 MHz（camera_in）传到 142.9 MHz（hdmi_out 的 video_style），接收侧是
2 级同步器。如果不加约束，Vivado 会把这条 CDC 当成普通路径去优化并报 −0.892 ns 违规。
本工程的处理：
* RTL 里给同步器寄存器加了 `(* ASYNC_REG = "TRUE" *)`；
* `base.xdc` 里加了
  `set_false_path -from [get_cells -hier -filter {NAME =~ "*video_mode_switch_0*mode_r_reg*"}] -to [get_cells -hier -filter {NAME =~ "*video_style_byp_0*bp_*"}]
  `（准静态控制信号，标准做法）。

## 5. 上板

```python
from pynq import Overlay
from pynq.lib.video import VideoMode
base = Overlay("base.bit")          # 用本目录 ready_to_test/ 或 pynq_overlay/ 里的 bit+hwh
camera_in = base.video.camera_in
hdmi_out  = base.video.hdmi_out
mode = VideoMode(640, 480, 24)      # DVI 只支持固定几种模式；写 800x480 会 ValueError
camera_in.configure(mode); hdmi_out.configure(mode)
camera_in.start(); hdmi_out.start()
camera_in.tie(hdmi_out)

# 然后按板上 PL_KEY0：LED2 亮 = 直通，灭 = 全处理
```

> ⚠️ 上电/复位后请**先松手等 1 秒**，让按键极性自动识别完成，再按第一下。

---

## 6. 文件清单（相对本目录）

```
base.srcs/sources_1/new/video_mode_switch.v    新增：输入侧 处理/直通 路由 + 按键消抖
base.srcs/sources_1/new/video_style_bypass.v   新增：video_style + 运行期 bypass 端口
base.srcs/sources_1/new/video_style.v          原文件（未在 BD 中使用，保留）
base.srcs/sources_1/new/video_kuwahara.v       同上一个工程（W=800 H=480）
base.srcs/sources_1/new/kuwahara.v / linebuf.v / box4col.v / luma_q8.v
base.srcs/constrs_1/new/base.xdc               LED2→mode_led、按键内部上拉
modify_btn.tcl                                 BD 改动脚本（已执行，可重复执行）
build_btn.tcl                                  综合+实现+bitstream+复制上板文件
vs_sim/tb_video_mode_switch.v                  模式切换自校验 testbench
vs_sim/mode_switch_sim.log                     仿真日志
ready_to_test/base.bit + base.hwh              可直接上板
pynq_overlay/base_wrapper.bit + .hwh
```

### 一个 Vivado 坑（记一下）

`video_style` 加端口后，**不要**用原来的 cell 名重建 module_ref（Vivado 会用
缓存的旧端口表，导致新端口不出现）。本工程的做法是给模块**换个新名字**
（`video_style_bypass` / cell `video_style_byp_0`），IP 目录是全新的，端口一定正确。
另外 `bypass` 这个跨层次信号是直接 `connect_bd_net /video/mode
/video/hdmi_out/video_style_byp_0/bypass` 连的（BD 会自动生成边界引脚），
手动 `create_bd_pin` 再两头连反而会报 "sink already connected"。

## 7. 想改 / 重跑

```bash
# 换按键：modify_btn.tcl 里 btn_sl 的 CONFIG.DIN_FROM 改成 1（用 PL_KEY1/K16）
# 换消抖时间：video_mode_switch_0 的 CONFIG.DEBOUNCE_MS
# 换极性策略：CONFIG.AUTO_POL=0 + CONFIG.BTN_ACTIVE_LOW
vivado -mode batch -source build_btn.tcl
```
