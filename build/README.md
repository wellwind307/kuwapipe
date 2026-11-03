# build/ —— 可复现构建脚本与综合/实现报告

## 1. 脚本

| 文件 | 作用 | 何时需要 |
|---|---|---|
| `build_btn.tcl` | 重置并重跑 `synth_1` + `impl_1`，导出综合/实现报告，并把 `base.bit` / `base.hwh` 复制到 `../board/bitstream/` | 改了 RTL / BD / 约束后需要新比特流时 |
| `package_capture_ip.tcl` | 把 `../src/base.srcs/sources_1/new/ov5640_capture.v` 重新打包成 `../src/ip_repo_local/ov5640_capture` | **只**在改了采集 RTL 后需要（否则 BD 仍用旧副本） |
| `modify_btn.tcl` | 一次性脚本：在 BD 里插入 `video_mode_switch` 等按键切换逻辑 | 历史用途，复现构建**不需要**运行 |
| `modify_capture.tcl` | 一次性脚本：用自研 `ov5640_capture` 替换原厂采集 IP | 历史用途，复现构建**不需要**运行 |

用法（在 `build/` 下）：

```bat
vivado -mode batch -source build_btn.tcl
```

> 首次构建会重建 `src/` 下的 `base.runs/`、`base.cache/`、`*.jou`/`*.log` 等产物；
> 这些目录**不进提交包**（见根目录 `.gitignore`），提交前删掉或重新打包干净副本。

## 2. 报告（本设计的最终实现）

| 文件 | 内容 | 来源构建 | 日期 |
|---|---|---|---|
| `impl_utilization.rpt` | 最终 Routed 状态的资源占用（LUT 22864 / FF 27514 / BRAM 22.5 / DSP 19） | `base_2025_2_kuwahara_btn_submit` | 2026-11-01 |
| `impl_timing_summary.rpt` | 最终实现时序（clk_fpga_0 WNS **−0.571 ns**、clk_fpga_1 WNS −0.115 ns） | 同上 | 2026-11-01 |
| `synth_utilization.rpt` | 本设计的**综合后**资源（LUT 24110 / FF 28646 / BRAM 22.5 / DSP 19，0 个黑盒；综合比实现多出的 LUT 属实现优化掉的冗余） | 本提交包副本，`synth_design Complete!`，0 error / 0 critical warning | 2026-11-04 |
| `kw_timing.rpt` | 只针对 `video_kuwahara_0` 内部时序路径的报告（核心路径 **+0.318 ns**，无违例） | 较早一次构建 | 2026-10-31 |

> ⚠️ `impl_timing_summary.rpt` 显示整机仍有建立时间违例（100 MHz 域 107 个失败端点），
> 违例不在 Kuwahara 核内部（见 `kw_timing.rpt`），而在 HLS IP 与外围路径上。
> 报告与 README 均已如实写明，不要改写成「时序已收敛」。

## 3. baseline/ —— 加 Kuwahara 之前的历史基线

| 文件 | 内容 | 来源构建 | 日期 |
|---|---|---|---|
| `baseline/utilization.rpt` | 基线（纯中值、无 Kuwahara）资源：LUT 21121 / FF 25636 / BRAM 13.5 / DSP 0 | `base_2025_2_median` | 2026-10-31 |
| `baseline/timing_summary.rpt` | 基线时序：clk_fpga_0 WNS −0.710 ns、clk_fpga_1 WNS −0.298 ns | 同上 | 2026-10-31 |
| `baseline/synth_utilization.rpt` | 基线的综合后资源（LUT 22299 / FF 26772 / BRAM 13.5 / DSP 0） | 同上 | 2026-10-31 |

**口径提醒**：这三份是**另一个工程目录、另一天**的构建结果，只能当作「加 Kuwahara 前的参考量级」，
不能当作受控对照实验：

- 资源差值可用作「Kuwahara 一级大约占多少」的量级估计（+1743 LUT、+9 BRAM、+19 DSP，
  以 impl 报告比较；用综合报告比较则是 +1811 LUT）；
- 但基线是否已包含 `video_style`（gamma/饱和度/量化）与按键切换逻辑，从报告里看不出层次明细，
  无法核验；若要写进报告，建议重新用同一工程、同一提交版本关掉 Kuwahara 综合一次再比。
- 时序方面两者都是**负裕量**，且是不同批次的 place & route，**不能**据此声称「优化了时序」。

## 4. 关于报告里的绝对路径

所有 `.rpt` 都是 Vivado 原始输出，表头 `Command:` 行里带着当时本机的工程绝对路径
（如 `C:/Users/30750/Desktop/...`）。这不影响报告内容，但会暴露本机目录；如不希望出现，
可在提交前把该行改成相对路径或直接删除该行。

## 5. 指标汇总

见 `metrics.md`（数字均可在本目录的报告里查到，出处逐行标注）。
