# 构建与实现报告

| 文件 | 内容 |
|---|---|
| `impl_utilization.rpt` | 实现后资源占用（LUT / FF / BRAM / DSP） |
| `impl_timing_summary.rpt` | 实现后时序（WNS/TNS，含各时钟域） |
| `synth_utilization.rpt` | 综合后资源占用 |
| `timing_summary.rpt` | 综合后时序 |
| `kw_timing.rpt` | Kuwahara 模块自身时序 |
| `utilization.rpt` | 早期版本资源对比（基线） |

## 关键数据（取自上述报告）

| 指标 | 本设计 | 基线（不含 Kuwahara） |
|---|---|---|
| Slice LUTs | 22,864（42.98%） | 21,372 |
| Slice Registers | 27,514（25.86%） | 25,749 |
| Block RAM Tile | 22.5（16.07%） | 13.5 |
| DSP48E1 | 19（8.64%） | 0 |
| clk_fpga_0 WNS | -0.571 ns | -0.498 ns |
| clk_fpga_1 WNS | -0.115 ns | -0.304 ns |

> 两个时钟域的最差路径均位于**原有 HLS IP 内部**（中值 / color_convert），Kuwahara 模块不在任何违规路径上。