# KuwaPIPE —— 实时 Kuwahara 保边平滑硬件加速

2026 全国大学生嵌入式芯片与系统设计竞赛 · AMD FPGA 创新设计赛道 · 自主选题赛道（初级组）

**南京大学 · 向日葵队**（徐钟意、向鸿轩、欧阳之珩）

> 本目录是**提交包**，按竞赛指南要求的目录结构组织：设计源码 `src/`、仿真 `sim/`、构建与报告
> `build/`、上板产物与实测 `board/`、测试数据 `data/`、技能包 `skill/`、设计报告 `report/`。

## 作品简介

摄像头 DVP 输入 → 3×3 中值 → **Kuwahara 保边平滑（r=3，7×7 窗口）** → gamma/饱和度/色彩量化
→ HDMI 输出，全链路 **1 pixel/clk 定点流水线**，无浮点、无除法、无全图统计。PS 侧用 PYNQ 加载
Overlay 并配置 VideoMode；板上按键（PL_KEY0）在「全处理 / 完全直通」间切换，LED2 指示当前模式。

## 目录结构

| 目录 | 内容 |
|---|---|
| `src/` | **完整可构建 Vivado 工程**（`base.xpr` + `base.srcs/` + `ip_repo_local/`，IP 全部内置、无外部依赖）+ PS 侧软件 `src/ps/` + 设计文档（`README_kuwahara.md`、`README_btn.md`、`README_style.md`、`DITHER_FIX.md`） |
| `sim/` | 4 个自校验 testbench + 3 个一键运行脚本（`run_kw_sim.bat`、`run_style_sim.bat`、`run_capture_sim.bat`）+ 位精确验证脚本 + `sim/logs/` 仿真日志 |
| `build/` | 可复现构建脚本（`build_btn.tcl`、`package_capture_ip.tcl`）+ 综合与实现报告（`synth_utilization.rpt`、`impl_*.rpt`）+ 基线报告（`build/baseline/`）+ 指标汇总 `metrics.md` + 报告出处说明 `build/README.md` |
| `board/` | 比特流/hwh（`board/bitstream/`）+ 上板运行与测量脚本（`measure.py`、`probe.py`、`pynq_read_modes.py`）+ PS 侧 Jupyter 主程序 `board/kuwahara_ps.ipynb`（含真实上板输出）+ 实测素材目录 `board/media/` |
| `data/` | golden 参考模型 + 测试图 + 对比图 + **板上实测抓帧**（`proc_*.png` / `raw_*.png` 处理/直通成对对照） |
| `skill/` | 技能包（7 项通用技能 S1–S7，每项含适用场景/用法/效果/失效条件/坑） |
| `report/` | 设计报告 `design_report.docx` + 大模型协作记录 `LLM_COLLAB_LOG.md` |
| `third_party/` | 第三方许可全文（MIT / BSD-3 / AMD / 正点原子说明），配合 `THIRD_PARTY_NOTICES.md` |

> 早期开发是扁平布局（`ready_to_test/`、`pynq_overlay/`、`vs_sim/`、工程根 `*.tcl`）；
> 本包已统一为上面的结构，各文档里的路径也**已全部同步更新**，不再需要做路径换算。

## 平台与器件

| 项 | 值 |
|---|---|
| 器件 | **xc7z020clg400-2**（Zynq-7000 SoC；正点原子领航者 ATK-DF7010/7020P 底板，PYNQ-Z2 兼容） |
| 工具 | Vivado 2025.2（推荐 2026.1，2025.2 可用） |
| PS 侧 | PYNQ **厂商镜像** `Release 2025_08_27`（含 `pynq.lib.ov5640`，官方镜像没有，见 `board/PS_CODE_NOTES.md`） |
| 时钟域 | 100 MHz（采集/处理）、142.857 MHz（显示） |

## 快速复现

**1) 构建**（需要 Vivado 2025.2）

```bat
cd build
vivado -mode batch -source build_btn.tcl
:: 只有在改过采集 RTL 时先跑：vivado -mode batch -source package_capture_ip.tcl
```

产物：报告写到 `build/`，`base.bit` / `base.hwh` 复制到 `board/bitstream/`。
首次构建会重建 `src/` 下的 `base.runs/`、`base.cache/` 等临时目录（不进提交包，见 `.gitignore`）。

**2) 离线验证**（不需要开发板，PC 上 NumPy + Pillow 即可）

```bat
cd sim
python verify_kuwahara.py    :: 期望 VERIFY RESULT: PASS；内部像素 300516/300516 逐位一致
python verify_style.py       :: 期望所有配置 0 LSB
```

**3) 仿真验证**（需要 xsim；脚本已按提交包路径写好，可直接跑）

```bat
cd sim
run_kw_sim.bat               :: Kuwahara RTL 自校验（小图 64x48，仓库自带激励）
run_style_sim.bat            :: 抖动/量化自检（8x8 恒值块，期望 avg_R=167）
run_capture_sim.bat          :: 采集 IP 逐拍等价性（需本机开发板资料盘里的原厂文件，现场生成比较用副本）
```

**4) 上板**（PYNQ，需厂商镜像）

```python
from pynq import Overlay
from pynq.lib.video import VideoMode
base = Overlay("board/bitstream/base.bit")     # .hwh 必须与 .bit 同目录同名
cam, hdmi = base.video.camera_in, base.video.hdmi_out
mode = VideoMode(640, 480, 24)      # DVI 仅支持 640x480/800x600/1280x720/1280x1024/1920x1080
cam.configure(mode); hdmi.configure(mode)
cam.start(); hdmi.start(); cam.tie(hdmi)
# 按 PL_KEY0 切换处理/直通，LED2 亮 = 直通
```

测量：`cd board && python measure.py fps --seconds 10`（详见 `board/README.md`）。

> 上游链路固定 800×480，但 PYNQ 的 DVI 输出不支持该分辨率（写 `VideoMode(800,480,24)` 会抛
> `ValueError`），故显示用 640×480，**右侧 20% 被裁掉**——显示通路硬限制，详见
> `src/README_kuwahara.md` 第 0 节。

## 关键指标

| 指标 | 数值 | 来源 |
|---|---|---|
| 输出帧率 | 40.05 fps（10 s，401 帧全不重复） | 实测，`build/metrics.md` §3 |
| 处理吞吐 | 1 pixel/clk @100 MHz = 100 Mpixel/s | 设计值 |
| 帧内延迟 | ≈2.43k clk ≈ 24.3 µs | 设计值 |
| 资源 | LUT 22,864 / FF 27,514 / BRAM 22.5 / DSP 19 | `build/impl_utilization.rpt` |
| 功能一致性 | 全尺寸 384000/384000 bit-exact；golden 对拍内部 300516/300516；采集 IP 91063 拍 0 失配 | `sim/logs/`、`sim/verify_kuwahara.py` |
| 静态时序 | **未收敛**：100 MHz 域 WNS −0.571 ns（107 个失败端点）、142.857 MHz 域 −0.115 ns | `build/impl_timing_summary.rpt` |

> 时序说明：违例不在 Kuwahara 核内部（核心路径 +0.318 ns，见 `build/kw_timing.rpt`），
> 而在 HLS IP 与外围路径上。**出比特流、板上正常出图 ≠ 静态时序通过**，本包如实记录该状态。
> 完整指标、测试条件与基线对比见 `build/metrics.md`。

## 许可与合规

- 代码采用 **MIT License**（`LICENSE`，版权人：南京大学 向日葵队）。
- 第三方组件（AMD Vivado IP、Digilent、Xilinx PYNQ、正点原子）的版权与许可声明见
  `THIRD_PARTY_NOTICES.md`，许可全文在 `third_party/`。**这两处要和代码一起提交**——
  MIT / BSD 的授权条件就是「保留版权声明与许可文本」。
- 作品将开源（MIT）。

## 开源

仓库已建立：**<https://github.com/wellwind307/kuwapipe>**（MIT）

```bash
git clone https://github.com/wellwind307/kuwapipe.git
```

> ⚠️ 远端仓库里目前是**目录重排之前**的扁平布局（`base.srcs/`、`ready_to_test/`、`vs_sim/` 都在根目录），
> 与本提交包的结构不一致。要把本包同步上去（保留提交历史），在仓库工作副本目录里执行：

```bat
robocopy <本包路径> . /MIR /XD .git
git add -A
git commit -m "refactor: 按竞赛要求重排目录（src/sim/build/board/data/skill/report）并修正路径与指标口径"
git push
```

> `robocopy /MIR` 会以本包为准镜像过去（`.git` 已排除）。若只想看差异，先用 `robocopy ... /L` 试运行。
> 根目录 `.gitignore` 已排除 Vivado 构建产物与仿真临时目录。

## 提交包说明（清理留痕）

本包是开发工程 `base_2025_2_kuwahara_btn` 的**干净提交版**：只保留设计源码、工程描述、上板产物、
测试数据、报告与许可声明。相对开发工程删掉的内容：

**构建产物（约 190 MB）**：`base.runs/`、`base.cache/`、`base.hw/`、`.Xil/`、
`base.srcs/sources_1/bd/base/ipshared/`（构建时自动重建；正点原子 `ipshared/949d/` 不再需要）、
`ip/*/synth/`、`ip/*/sim/`、`base.srcs/sim_1/`、`utils_1/`、全部 `*.log` / `*.jou`。

**仿真临时与厂商副本**：`_ref/`（原厂参考文件的 UTF-8 副本，由 `sim/prepare_capture_ref.py` 现场生成）、
`_sim_ov5640/`、`_bdtest/`、`sim/work/`、`sim/xsim.dir/`、`sim/tb_full_*.hex`（各约 3 MB，可重新生成）。

**历史脚本**：`impl.tcl`、`synth.tcl`、`build_bitstream.tcl`、`build_copy.tcl`、`modify_bd.tcl`、
`modify_median*.tcl`、`modify_style.tcl`、`recon*.tcl`、`report_cells.tcl`。

**依赖**

- Vivado 2025.2（本机 `C:\Users\30750\Myvivado\2025.2\Vivado\bin`；脚本优先用 PATH 里的 Vivado）
- **无需外部 IP 仓库**：`.xpr` 的 `IPRepoPath` 只指向 `$PPRDIR/ip_repo_local`（IP 全部随包内置）
- 离线验证：Python + numpy + Pillow；上板：厂商 PYNQ 镜像（含 `pynq.lib.ov5640`）

**已验证（可复跑）**

- 2026-11-04 复跑 `sim/verify_kuwahara.py`：内部像素 **300516 / 300516 逐位一致，VERIFY RESULT: PASS**；
  复跑 `sim/verify_style.py`：全部配置 **0 LSB**。
- 2026-11-04 在提交包副本上重跑综合：`synth_design Complete!`，**0 error / 0 critical warning**，
  资源 LUT 24,110 / FF 28,646 / BRAM 22.5 / DSP 19（见 `build/synth_utilization.rpt`）——
  证明本包脱离外部 IP 仓库可独立重建。
- 仿真证据见 `sim/logs/`：全尺寸 384000/384000、采集 IP 91063 拍 0 失配、模式切换 13292 拍 0 失配。

**提交前注意**：若在本目录又跑过构建，会重新生成 `src/base.runs/`、`ipshared/` 等目录，提交前再剔除一遍
（`.gitignore` 已按同一清单写好）；`sim/_ref/`、`sim/_sim_ov5640/` 属临时产物，不要提交；
`board/bitstream/base.bit` 与 `base.hwh` 是配套的一对，必须同时提交。

## 提交自查

逐条对照指南的自查表见 [`SUBMISSION_CHECKLIST.md`](SUBMISSION_CHECKLIST.md)。
