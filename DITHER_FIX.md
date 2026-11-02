# 色彩量化暗部色带（banding）修复说明

## 问题

`video_style.v` 输出端的色彩量化用的是**均匀位屏蔽**：

```verilog
wire [7:0] out_r = cr & PMASK;   // POSTER_LEVELS=16 -> 屏蔽低 4 位
```

这是"均匀截断量化"。高对比场景下，亮光向暗区的平滑渐变被强行归并到
`0/16/32/.../240` 这几个台阶上，暗部（数值小、层级本来就少）出现明显色带，
看起来就是"暗处被光污染"。

## 修复方案：Bayer 有序抖动（ordered dithering）

在截断**之前**给像素加一个与坐标相关的抖动量 `[0, Q_STEP)`，再屏蔽低位：

```
out = (cr + dither(x,y)) & PMASK
```

原理：8×8 邻域内，输出电平的**均值 = 量化前的原值**（逐块无偏），
把台阶状 banding 变成人眼几乎看不见的细噪声，同时保留卡通的平涂色块观感。

具体改动（只改了 `base.srcs/sources_1/new/video_style.v` 一个文件）：

1. 新增 8×8 Bayer 抖动矩阵（`function bayer8`，0..63）。
2. 新增像素坐标计数器（mod 8，随 TUSER/TLAST 逐帧复位，保证逐帧一致、无闪烁）。
3. 坐标随数据 4 级流水线同步延迟，输出级计算抖动量并做饱和截断。
4. 新增 `localparam DITHER_EN = 1`：`1`=开启抖动（默认），`0`=退回原来的纯屏蔽。

**接口、参数、延迟（4 拍）均不变**，BD 无需重新接线。

## 验证结果（Vivado 2025.2 xsim）

`vs_sim/tb_video_style.v` 自检（8×8 恒值灰度块，POSTER=16）：

```
captured=64  expected_cr(gamma(100))=167  avg_R=167  level_errors=0
=== PASS ===
```

- 输出 64 拍全部落在量化级（16 的倍数）上；
- 8×8 块均值 = 167 = 量化前原值 `gamma(100)`，即抖动**逐块无偏**（不抖动则全被截成 160）。

## 完整构建已跑通（Vivado 2025.2，本副本）

```
SYNTH STATUS: synth_design Complete!
IMPL STATUS : write_bitstream Complete!
BUILD DONE
```

- 综合 / 实现 / 生成 bitstream 全程 **0 errors**；
- 新比特流 `base.runs/impl_1/base_wrapper.bit`（4,045,688 B）已同步到
  `ready_to_test/base.bit` 与 `pynq_overlay/base_wrapper.bit`；
- 新比特流 SHA256 与原比特流不同，确认改动已生效；
- 时序仍有一条 WNS≈-0.48ns 的违规，属原工程就有的 100MHz 域路径（README 已记录），
  与本修改无关（video_style 的 4 级流水线不在关键路径上）。

## 如何使用

1. 新比特流已生成：直接取 `ready_to_test/base.bit`（配原有 `base.hwh`）即可上板，
   或按 PYNQ 流程加载 `pynq_overlay/base_wrapper.bit` + `base_wrapper.hwh`。
2. 若要重跑：用 Vivado 2025.2 打开本目录 `base.xpr`，跑 `build_copy.tcl`
   （或 `build_bitstream.tcl` 把里面的工程路径改成本目录）。`video_style` 是
   module_ref IP，会自动用修改后的 `.v` 重新综合，BD 无需重新接线。
3. 想对比开/关抖动：改 `video_style.v` 里的 `localparam DITHER_EN`（1/0），重跑即可。

> 附：`vs_sim/` 是验证用的 testbench 与脚本，可删，不影响工程。
