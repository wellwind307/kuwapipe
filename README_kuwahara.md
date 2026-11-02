# base_2025_2_median_style_kuwahara —— 新增 Kuwahara 保边平滑硬件实现

`base_2025_2_median_style_fixed` 的**另存副本**（原工程未做任何修改）。
在摄像头输入通路上，于 **3×3 中值**之后、**gamma / 饱和度 / 色彩量化**之前，插入了一级
`video_kuwahara_0`（Kuwahara 保边平滑，r=3，7×7 窗口，4 个 4×4 象限）。

> **当前状态：已完成并上板实测通过（2026-11-01）。**
> 第 1 版按 W=640 做行缓存，上板出现 ~4 重错位重影；改为真实几何 **W=800**（见第 0 节）后
> **重影消失，画面正常**。Python 位精确模型与 golden 内部逐位一致；xsim 全尺寸 800×480
> 密集流 384000/384000 像素 bit-exact；综合 / 实现 / bitstream 全程 0 error。

---

## 0. 重要修正：行宽是 800，不是 640（第一版上板出现 4 重影的原因）

第一版把 `W` 当成 640（跟着 PYNQ 的 `VideoMode(640,480)` 和 golden 的尺寸），上板后出现
**约 4 重错位重影**。原因：

**HLS 中值 IP 的行列循环是硬编码常量，与 PYNQ 的 VideoMode 无关。**

```
median_blur_color_..._xfMat2AXIvideo_..._Pipeline_loop_col_mat2axi.v
    assign icmp_ln204_fu_132_p2 = ((ap_sig_allocacmp_j_1 == 10'd800) ? 1'b1 : 1'b0);
```

即中值输出**固定每行 800 像素、每帧 480 行**；而 `VideoMode(640,480)` 只写 VDMA/VTC 的
寄存器，**不会**写中值 IP 的 `rows/cols`（PYNQ 的 video 库对 HLS IP 不做配置）。所以：

* 改之前：VDMA 按 640 取每行前 640 个像素 → 右边 20% 一直被裁掉，但画面稳定，看着"正常"；
* 我按 640 做行缓存后：每行多出 160 像素，行缓存"一行"≈ 0.8 条真实行 → 5 个虚拟行才走完
  4 条真实行 → 7 行窗口里混进了 4 条不同真实行的内容、每行水平错开 160 像素 →
  **正好呈现 4 重错位重影**。

修正：`W=800, H=480`（`kuwahara.v` / `video_kuwahara.v` 的参数默认值 + BD 的
`CONFIG.W/CONFIG.H`）。修正后全尺寸 800×480 密集流仿真逐位通过，
**上板实测：重影消失，画面正常。**

> **以后要注意的坑**：`W/H` 要跟着**上游 HLS 中值的模板常量**走，不是跟着 `VideoMode`。
> 如果哪天重新生成中值 IP（换模板尺寸）、或者在它前面再加别的 HLS IP，必须同步检查
> 它的 `icmp_ln* == <cols>` 常量，并改 `modify_kuwahara.tcl` 里的 `CONFIG.W/CONFIG.H`。

> **显示分辨率受 PYNQ DVI 限制**：`pynq.lib.video` 的 `_outputmodes` 只支持
> 640×480 / 800×600 / 1280×720 / 1280×1024 / 1920×1080 五种输出模式。
> 上游的 800×480 **不在其中**，写 `VideoMode(800, 480, 24)` 会在 `hdmi.configure()` 抛
> `ValueError: Invalid Output resolution 800x480`。
>
> 所以上板统一用 **640×480**：画面稳定，但每行只取前 640 像素，**右侧 20% 被裁掉**。
> 想要完整 800 宽，需要把 HLS 中值 IP 与 Kuwahara 的几何一起改成受支持的显示模式
> （例如 1280×720）并重新综合，属于硬件改动，PS 侧绕不过去。

---

## 1. 改了哪里（和 golden 的对应关系）

golden（`style_cartoon_640x480.py`）的处理链与本工程的对应：

| golden 里的步骤 | 本工程里的实现 | 位置 |
|---|---|---|
| 步骤 1 `_med3` 3×3 中值 | `median_blur_color_0`（HLS IP） | `/video/camera_in` |
| 步骤 2 白平衡 | Q8 增益固定 256（=1.0，恒等）→ **不需要实现** | — |
| 步骤 3 `_kuwahara` r=3 | **`video_kuwahara_0`（本次新增）** | `/video/camera_in` |
| 步骤 4 `_brighten` gamma+饱和度 | `video_style_0` | `/video/hdmi_out` |
| 步骤 5 `_posterize` 色彩量化 | `video_style_0`（屏蔽低位 + Bayer 抖动） | `/video/hdmi_out` |

插入点在 `/video/camera_in` 层次内（100 MHz 时钟域，`clk_100M`）：

```
改前： median_blur_color_0/video_out ──────────────► pixel_pack/stream_in_24
改后： median_blur_color_0/video_out ─► video_kuwahara_0 ─► pixel_pack/stream_in_24
                                       (s_axis)   (m_axis)
```

时钟 / 复位与 HLS 中值同源：`median_blur_color_0/ap_clk` / `ap_rst_n`。

这样接的好处：Kuwahara 的结果先经 `pixel_pack → VDMA → DDR`，**PS 端能直接读到
Kuwahara 输出**做比对；显示端 `video_style_0` 完全不用动。

---

## 2. 算法：为什么整数实现能和浮点 golden 逐位一致

RTL 里做的（与 `_kuwahara` 一一对应）：

```
亮度   Y     = 77R + 150G + 29B                  (Q8，16bit，就是 _luma_q8)
象限和 S     = Σ Y      (4x4 = 16 个)
        S2    = Σ Y²
判别式 disc  = 16*S2 – S²      (= 256 * var，恒 ≥ 0)
选象限        disc 最小者，平局顺序 TL > TR > BL > BR
输出均值      round-half-even( ΣRGB / 16 )
```

与参考的等价性推导（这是能"逐位一致"的原因）：

```
参考： y = Y/256 ,  var = Σy²/16 – (Σy/16)²
              = (16·ΣY² – (ΣY)²) / 2^20  =  disc / 2^20
```

`2^20` 是正的常数因子，所以 **argmin(disc) ≡ argmin(var)**；float64 表示这些整数没有误差
（Σ 项 ≤ 2^41 ≪ 2^53），因此象限选择、平局结果与 golden **完全一致**。
均值一侧 RTL 用 `q + ((rem>8) | (rem==8 & q[0]))`，正好等价于 `np.round(sum/16)` 的银行家舍入。

实测（`verify_kuwahara.py`，输入 `fortest.jpg` 640×480，先做参考的 3×3 中值）：

```
全图       : 最大差 165 LSB, 差异像素 3157 / 307200 (1.03%)   ← 只在最外 3 行/3 列
内部(去掉最外3行3列): 最大差 0 LSB, 差异像素 0 / 300516        ← 逐位一致
把同一模型的边界换成 replicate 后: 全图 0 LSB，逐位一致        ← 证明差别只来自边界
```

> 边界策略：RTL 用**补零**做窗口边界（参考用 edge-replicate），所以最外 3 行/3 列不同。
> 因为最终只取"方差最小"象限的均值，含补零的象限方差极大、几乎总被排除，所以边界
> 不会出现黑边，看起来接近"取最靠近的真实象限"。这是有意为之的取舍（见第 7 节）。

---

## 3. RTL 结构与关键设计

```
s_axis ─► [stage A 寄存] ─► 6 级行缓存(RGB 24b + luma 16b) ─► 7×7 窗口
                                                    │
                        ┌───────────────────────────┴──────────────────┐
                        ▼                                              │
        7 行 luma 平方 + 4 行竖直和(stage B)                            │
                        ▼                                              │
        水平 4 列滑动和 box4col ×10（Y / Y² / R / G / B × 上下半窗）     │
                        ▼                                              │
        disc = 16·S2 – S² (DSP 乘法) → 寄存 (stage C)                   │
                        ▼                                              │
        比较选最小 → 4:1 选象限 RGB 和 → round-half-even (stage D)       │
                        ▼                                              │
        输出 skid 寄存器 ─► m_axis（TVALID/TLAST/TUSER 自己生成）        │
```

| 要点 | 说明 |
|---|---|
| **扩展网格 flush** | 输出像素 (y,x) 要等输入走到 (y+3, x+3) 才产生，所以每帧多喂 3 行、每行多喂 8 拍。这些 flush 拍**不消耗输入**（`i_ready=0`），靠水平/垂直消隐的拍自己走完；输出正好 `H*W` 个像素，帧几何不变、不丢像素。 |
| 为什么是 8 拍 | 3 拍给右边界（最后一列 x=W-1 的窗口要到 col=W+2），5 拍给流水排空（4 级内部 + 1 级 skid）。关键是它必须让"一行 = 固定拍数"，否则行缓存的行对齐会在帧间漂移。 |
| **输出 skid 寄存器** | 下游反压或上游出现气泡时整条流水暂停；已算好的输出被下游取走后清掉 `out_vld`，**不会重复发同一个像素**。没有这一级（纯组合输出）在"输入有气泡 + 下游 ready"时会让下游重复收到同一像素（本次调试踩到过）。 |
| 流水线 5 级 | stageA(寄存输入) → stageB(平方/竖直和) → box4col(累加) → stageC(disc 寄存) → 输出寄存。把"3 乘 + 平方"、"20×20 乘 + 40bit 减"、"比较+选+舍入"分到不同级，100 MHz 有余量。 |
| 行缓存 | 12 个环形 BRAM（6 级 × RGB/luma），读指针 = 写指针 + 1，正好抵消寄存器读的 +1 拍，级联不产生列偏移。 |
| 吞吐 | 1 像素/拍；每帧实际占用 `(H+3)×(W+8)` = 483×808 = 390,264 拍，比 `H*W`(384,000) 多 1.6%，100 MHz 下 800×480 绰绰有余。 |
| 延迟 | 窗口延迟 ≈ 3 行 + 3 列，再加 5 拍流水 ≈ `3×(W+8)+3+5` ≈ 2.43k 拍 ≈ 24.3 µs @100 MHz（帧对齐型，不改变帧率）。 |

---

## 4. 验证

### 4.1 Python 位精确模型 vs golden（不需要 Vivado）

```bash
python verify_kuwahara.py             # 与 golden 的逐位比对（见第 2 节的数字）
python verify_kuwahara.py --tb        # 生成 64x48 小图仿真向量
python verify_kuwahara.py --tb-full   # 生成 800x480 全尺寸仿真向量
python make_preview.py                # 生成 preview_kuwahara.png 对比图
```

`preview_kuwahara.png`：输入 / 中值后 / Kuwahara(RTL) / Kuwahara(golden) / RTL 全链路 /
差异图。第 6 张几乎全黑（差异只在最外 3 行 3 列）。

### 4.2 xsim 自校验（RTL 逐位）

```bat
cd vs_sim
run_kw_sim.bat                       rem 小图快速回归（64x48，2 帧，含随机反压）
rem 全尺寸：xvlog 加 -d TB_FULL 再 xelab/xsim（日志见 kw_sim_full800x480.log）
```

**① 全尺寸 800×480、完全密集流（最接近硬件里 HLS 中值输出的形态）**

```
tb_video_kuwahara  W=800 H=480  grid=483 x 808  frames=1  GAP=0 VGAP=6000
captured=384000 / 384000   mismatch=0   extra=0   flag_err=0
=== PASS ===
```

**② 64×48 小图，2 帧，行间 12 拍消隐，下游 `m_axis_tready` 每 8 拍随机拉低 1 拍**

```
tb_video_kuwahara  W=64 H=48  grid=51 x 72  frames=2  GAP=12 VGAP=400
captured=6144 / 6144   mismatch=0   extra=0   flag_err=0
=== PASS ===
```

同一 testbench 把 `GAP` 改成 0（完全密集流，flush 拍靠反压从上游"借"）也是
`captured=6144/6144 mismatch=0 extra=0 flag_err=0 === PASS ===`。

> "喂 2 帧"是特意加的：专门验证帧间行缓存对齐不会漂移（如果每帧的拍数不是
> `(H+3)×LW` 的整数倍，第 2 帧开始就会整体错位）。
> 日志：`vs_sim/kw_sim_gap12.log`、`kw_sim_gap0.log`、`kw_sim_full800x480.log`。

---

## 5. 上板

`base.bit` / `base.hwh` 已经更新到：

```
ready_to_test/base.bit + base.hwh          （配原有 PYNQ 流程，直接换这两个文件）
pynq_overlay/base_wrapper.bit + .hwh
```

PYNQ 侧用法**完全不变**（`Overlay(...)` + `base.video.camera_in/hdmi_out`）：

```python
from pynq import Overlay
from pynq.lib.video import VideoMode
base = Overlay("base.bit")
camera_in = base.video.camera_in
hdmi_out  = base.video.hdmi_out

# 显示只支持 640x480 / 800x600 / 1280x720 / 1280x1024 / 1920x1080
# 上游是 800x480，只能用 640x480（右侧裁掉 20%）
mode = VideoMode(640, 480, 24)
camera_in.configure(mode); hdmi_out.configure(mode)
camera_in.start(); hdmi_out.start()
camera_in.tie(hdmi_out)          # 直通显示：链路里已经带 Kuwahara
```

切换风格：`video_style_0` 的 `SAT_Q8 / POSTER_LEVELS` 等参数照旧（见 `README_style.md`）。

## 6. 资源与时序（Vivado 2025.2，xc7z020clg400-2）

完整流程已跑通：`synth_design Complete!` → `write_bitstream Complete!`，**0 error**。
具体数字见 `impl_utilization.rpt` / `impl_timing_summary.rpt` / `kw_timing.rpt`。

| 项目 | 原工程（不含 Kuwahara） | 本工程（含 Kuwahara） |
|---|---|---|
| Slice LUTs | 21 372 | **22 765 (42.8%)** → +1 393 |
| Slice Registers | 25 749 | **27 375 (25.7%)** → +1 626 |
| Block RAM Tile | 13.5 | **22.5 (16.1%)** → +9（14×RAMB36 + 7×RAMB18，12 个行缓存） |
| DSP48E1 | 0 | **19 (8.6%)**（7 个平方 + 8 个 20×20 判别式 + 3 个亮度乘 + 1） |
| clk_fpga_0 (100 MHz) WNS | −0.498 ns / 125 端点 | −0.567 ns / **122 端点**（差 0.07 ns 属布局噪声，路径仍在 HLS 中值内部） |
| clk_fpga_1 (142.9 MHz) WNS | −0.115 ns / 4 端点 | −0.138 ns / **3 端点**（仍在 `color_convert` 内部） |
| Kuwahara 是否在违规路径里 | — | **0 条**（`report_timing_summary` 里没有任何违规路径经过 `video_kuwahara_0`） |

时序说明：两个时钟域的最差路径都在**原工程**的 HLS IP 内部（100 MHz 在
`median_blur_color_0/.../medianBlur_...`，142.9 MHz 在 `color_convert`），
`video_kuwahara_0` 不在任何违规路径上；换 W=800 后模块自身仍是正余量。

产出文件：

```
base.runs/impl_1/base_wrapper.bit                 新比特流
base.srcs/sources_1/bd/base/hw_handoff/base.hwh   新硬件描述
ready_to_test/base.bit + base.hwh                 已更新（可直接上板）
pynq_overlay/base_wrapper.bit + .hwh              已更新
```

## 7. 已知差异与限制（重要）

1. **行宽/行数必须 = 上游实际几何（800×480）**，这是模块参数 `W/H`（BD 里
   `CONFIG.W/CONFIG.H`）。它**不等于** PYNQ 的 `VideoMode`：中值 IP 的行列循环是硬编码
   常量（见第 0 节）。改错行宽 → 行对齐漂移 → 画面出现多重错位重影。
   行缓存深度 = `W+8` = 808。
2. **边界（最外 3 行 / 3 列）**：RTL 补零边界 vs golden 的 replicate 边界。
   全链路量化后约 **0.37%（1134/307200）** 的像素不同，最大差 112 LSB，
   **内部像素全部逐位一致**。视觉上是贴边 1~3 像素的轻微偏移，没有黑边/彩边。
   若要严格 replicate，需要给左/上边界加"预装首像素"、给右/下边界加"重放末行"，
   会多出一行缓存和一个行选择 mux，当前版本按"性价比"没做。
3. **每行需要 ≥8 拍消隐、每帧需要 ≥3 行消隐**：flush 拍靠消隐推进。中值输出的
   HBlank/VBlank 都远大于这个量，够用；即使上游是完全密集流，flush 拍也会通过反压
   从上游"借"到（已在仿真里验证 GAP=0 通过）。
4. **字节序**：亮度公式按 `{R[23:16], G[15:8], B[7:0]}` 取字节（与 golden、与工程里已有的
   `video_style.v` 一致）。注意 BD 的接口元数据把 24bit RGB 声明成 `G_B_R_444`
   （Xilinx 视频 IP 的默认声明）。如果实测发现高字节其实不是 R，只需改 `luma_q8.v` 里
   三个乘法的字节选择（3 行）——**只影响"选哪个象限"的亮度，不影响 R/G/B 象限均值本身**
   （各通道独立求和后原样写回，所以颜色永不错位）。
5. 时序上本工程原本就有一条 100 MHz 域的 WNS 违规（在 HLS 中值 IP 内部，与本次改动无关，
   见 `README_style.md`），本次没有新增违规路径。

---

## 8. 文件清单

```
base.srcs/sources_1/new/video_kuwahara.v   AXI4-Stream 顶层（module_ref IP，W=800/H=480）
base.srcs/sources_1/new/kuwahara.v         Kuwahara r=3 核心（扩展网格 + 5 级流水）
base.srcs/sources_1/new/linebuf.v          行缓存（环形 BRAM，精确延迟一行）
base.srcs/sources_1/new/box4col.v          4 列滑动和（h_new / h_old）
base.srcs/sources_1/new/luma_q8.v          亮度 77R+150G+29B（Q8）

modify_kuwahara.tcl      BD 接线脚本（已执行，可重复执行；含 CONFIG.W=800/H=480）
build_kuwahara.tcl       综合 + 实现 + bitstream + 复制上板文件
verify_kuwahara.py       RTL 整数模型 + 与 golden 的逐位比对 + TB 向量生成
make_preview.py          生成 preview_kuwahara.png / preview_kuwahara_crop.png
vs_sim/tb_video_kuwahara.v   自校验 testbench（默认 64x48；-d TB_FULL 切 800x480）
vs_sim/run_kw_sim.bat    一键编译 + 仿真（小图）
vs_sim/tb_kw_in.hex / tb_kw_exp.hex         小图激励 / 期望
vs_sim/tb_full_in.hex / tb_full_exp.hex      800x480 全尺寸激励 / 期望
vs_sim/kw_sim_*.log      仿真日志（gap12 / gap0 / full800x480，全部 PASS）
preview_kuwahara.png / preview_kuwahara_crop.png   对比图
impl_utilization.rpt / impl_timing_summary.rpt     实现后的资源与时序
kw_timing.rpt            Kuwahara 模块自身时序
modify_kuwahara.log / build_kw.log                接线与构建日志
```

## 9. 想改 / 重跑

```bash
# 1) 改算法参数（半径目前固定 r=3，与 golden 的 KUWA_R=3 对齐）
#    gamma / 饱和度 / 量化级数在 video_style.v 里改（见 README_style.md）

# 2) 改完 RTL 后先跑 Python 比对 + xsim
python verify_kuwahara.py --tb --tb-full
cd vs_sim && run_kw_sim.bat

# 3) 重新出 bitstream（Vivado 2025.2，在仓库根目录执行）
vivado -mode batch -source build_btn.tcl
```

如果只是想临时关掉 Kuwahara 看对比：把 `median_blur_color_0/video_out` 直接接回
`pixel_pack/stream_in_24`（或删掉 `video_kuwahara_0`），再跑一次 `build_btn.tcl`。
