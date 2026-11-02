# base_2025_2_median_style

`base_2025_2_median` 工程的另存副本，已在**显示输出通路**的输出端新增风格化处理模块
`video_style`，只实现参考脚本 `style_cartoon_640x480.py` 里的三个逐像素算子。

> **当前状态：已完成。** BD 已接线并验证通过，综合 + 实现 + 生成 bitstream 全部完成，
> 可直接上板的比特流 / 硬件描述文件已更新到 `ready_to_test/` 和 `pynq_overlay/`。

| 算子 | 参考实现 | RTL 实现 |
|------|----------|----------|
| gamma 提亮 | `_build_gamma_lut(45)`，256x8 查找表 | `$readmemh("gamma_lut.mem")` 加载同一张表 |
| 饱和度 | `ly + sat*(x-ly)`，`sat=ENH_SAT/100` | Q8 定点：`ly + (SAT_Q8*diff)>>8` |
| 色彩量化 | `_posterize`，屏蔽低位（2 的幂级数） | `x & PMASK`，纯与门 |

> 说明：参考脚本里还包含中值滤波 / Kuwahara / 白平衡 / 线稿等环节，本工程**只取了
> gamma、饱和度、色彩量化这三步**（按用户要求）。这三个算子都是纯点运算，因此用
> 一条 4 级流水线即可，无需行缓存、无全图统计、无反馈。

## 1. 接线位置（输出端）

在 `/video/hdmi_out` 层次内，24-bit RGB888 的 AXI4-Stream 上：

```
color_convert/stream_out_24 ──► video_style_0/s_axis ──► m_axis ──► frontend/video_in
                                                                     (v_axi4s_vid_out → rgb2dvi → HDMI)
```

时钟/复位与 `color_convert` 同源：`clk_142M` / `periph_resetn_clk142M`。
模块接口完全对齐 AXI4-Stream（TDATA=24），latency = 4 拍，背压安全。

## 2. 逐位一致性自检

`verify_style.py` 用 numpy 复刻 RTL 定点流水线，与 `style_cartoon_640x480.py` 的
`_brighten` + `_posterize` 逐位比对：

```
gamma_lut.mem 与参考 LUT 一致: True  (共 256 项)
SAT=1.00 (256)  POSTER=16/8/4/32 : 逐位一致，最大差 0 LSB
SAT=1.25/1.50/2.00              : 逐位一致，最大差 0 LSB
```

即 RTL 整数实现与参考浮点实现，在 gamma → 饱和度 → 量化这条链路上**逐位一致**
（Q8 定点 + 截断在 `clip` 后与浮点 `trunc` 完全等价）。

## 3. 构建结果（已用 Vivado 2025.2 跑通）

| 阶段 | 结果 |
|------|------|
| `validate_bd_design` | rc=0（通过） |
| `generate_target` | rc=0，`base_wrapper.v` 已含 `video_style_0` 实例 |
| 综合（synth_1） | **0 Errors**（`$readmemh` 成功加载 gamma_lut.mem） |
| 实现（impl_1 → write_bitstream） | **0 Errors**，`base_wrapper.bit` 生成成功 |

产出文件：

```
base.runs/impl_1/base_wrapper.bit     新比特流（4,045,688 B）
base.srcs/sources_1/bd/base/hw_handoff/base.hwh   新硬件描述（1,885,019 B）
ready_to_test/base.bit + base.hwh                 已更新（可直接上板）
pynq_overlay/base_wrapper.bit + base_wrapper.hwh  已更新
```

### 关于时序

本工程**原本就有时序违规**（100MHz 域的 GPIO/MDM 路径、以及显示通路
`color_convert` HLS IP 内部未打拍的乘法链），并非本次新增：

| 时钟域 | 原工程 WNS | 本工程 WNS | 说明 |
|--------|-----------|-----------|------|
| clk_fpga_0 (100MHz) | -0.710ns / 150 端点 | -0.498ns / 125 端点 | 原就违规，与视频无关 |
| clk_fpga_1 (142MHz) | -0.298ns / 5 端点 | -0.115ns / 4 端点 | 关键路径在 `color_convert` 内部 |

`video_style_0` 的 4 级流水线**未出现在任何违规路径中**（关键路径是
`color_convert/inst/mul_10s_8ns_18_1_1` 的 11 级组合逻辑）。即本次修改没有引入新的
时序问题，clk_fpga_1 的 WNS 反而因布局差异略有改善。若需要彻底收敛，可后续给
`color_convert` 内部乘法链补打拍（与本模块无关）。

## 4. 文件清单

```
base.srcs/sources_1/new/video_style.v   风格化模块（gamma + 饱和度 + 量化）
base.srcs/sources_1/new/gamma_lut.mem   gamma=0.45 查找表（256x8）
base.srcs/.../base.bd                   已由 modify_style.tcl 完成接线（已保存）
base.xpr                                已登记 video_style.v / gamma_lut.mem
modify_style.tcl                        BD 接线脚本（已执行过；可重复执行）
build_bitstream.tcl                     综合+实现+bitstream 脚本（已执行过）
gen_gamma_lut.py                        重新生成 gamma_lut.mem（可换其他 gamma）
verify_style.py                         RTL vs 参考的逐位自检
README_style.md                         本说明
```

## 5. 若需重新跑 / 调参

需要 Vivado 2025.2（`vivado` 在 PATH 里，或直接用安装目录下的 `vivado.bat`）。**在仓库根目录执行**：

```bat
:: 重新接线 + 生成 BD 输出（一般不需要，已执行）
vivado -mode batch -source modify_btn.tcl
:: 重新综合 + 实现 + bitstream
vivado -mode batch -source build_btn.tcl
```

调参（`video_style` 的 Verilog 参数，默认值见下）：

| 参数 | 默认 | 含义 |
|------|------|------|
| `ENABLE` | 1 | 1=风格化；0=直通（仍 4 拍延迟） |
| `GAMMA` | 45 | gamma×100（实际曲线由 `gamma_lut.mem` 决定） |
| `SAT_Q8` | 256 | 饱和度 Q8：256=1.0、320=1.25、384=1.5、512=2.0 |
| `POSTER_LEVELS` | 16 | 量化级数（2 的幂）：4 / 8 / 16 / 32 |

直接改 `video_style.v` 的 `parameter` 默认值（或 BD 里改 `video_style_0` 的属性），
然后重跑 `build_btn.tcl`。换 gamma 曲线：`python gen_gamma_lut.py <GAMMA>`。

## 6. 自检（无需 Vivado）

```bash
python verify_style.py       # RTL 定点 vs 参考逐位比对
python gen_gamma_lut.py 45   # 重新生成 gamma_lut.mem
```

`verify_style.py` 会 import `data/style_cartoon_640x480.py` 作参照（仓库内自带）；
若你要换参考模型，改脚本开头的 `REF_PATH`。
