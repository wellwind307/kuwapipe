# 提交包说明（clean 版）

本目录是 `base_2025_2_kuwahara_btn` 的**最干净提交版**：只保留源码 / 工程描述 / 上板文件 /
许可声明，剔除全部构建产物、日志、仿真临时文件与厂商源码副本。

---

## 1. 目录结构

| 路径 | 内容 |
|---|---|
| `base.xpr` | Vivado 2025.2 工程（`IPRepoPath` 只有 `$PPRDIR/ip_repo_local`） |
| `base.srcs/` | RTL、BD（`base.bd`）、约束；IP 的 `.xci`/`.xml` 保留，生成物已剔除，构建时自动重建 |
| `ip_repo_local/` | 自研 `ov5640_capture` + 工程所需的 Digilent / PYNQ / HLS / 中值 IP 包（**自带，不依赖外部仓库**） |
| `ready_to_test/` | `base.bit` + `base.hwh`（当前上板验证过的那一版） |
| `pynq_overlay/` | 同上，PYNQ 流程用（与 `ready_to_test` 内容相同） |
| `vs_sim/` | testbench + 运行脚本（不含波形、日志、大尺寸激励） |
| `third_party/` | MIT / BSD 许可全文 + AMD / 正点原子说明 |
| `*.py` / `*.tcl` | 验证脚本与构建脚本 |

## 2. 相对原始工程删掉了什么

**构建产物（约 190 MB）**

```
base.runs/  base.cache/  base.hw/  .Xil/
base.srcs/sources_1/bd/base/ipshared/
base.srcs/sources_1/bd/base/ip/*/synth/   ip/*/sim/
base.srcs/sources_1/bd/base/synth/        bd/base/sim/
base.srcs/sim_1/
所有 *.log / *.jou / *.backup.log / *.backup.jou
```

**仿真临时与厂商副本**

```
_ref/           原厂参考源码的 UTF-8 仿真副本（需要时由 prepare_capture_ref.py 现场生成）
_sim_ov5640/    xsim 运行目录
_bdtest/        调试脚本与日志
vs_sim/work/  vs_sim/xsim.dir/  vs_sim/*.log
vs_sim/tb_full_in.hex / tb_full_exp.hex   （各 3 MB，可重新生成）
```

**历史脚本**（指向更早的工程路径，与本次提交无关）

```
impl.tcl  synth.tcl  build_bitstream.tcl  build_copy.tcl
modify_bd.tcl  modify_median*.tcl  modify_style.tcl  recon*.tcl  report_cells.tcl
```

## 3. 依赖

- **Vivado 2025.2**（`vivado` 在 PATH 里，或直接用安装目录下的 `vivado.bat`）
- 无需外部 IP 仓库：`.xpr` 的 `IPRepoPath` 只指向 `$PPRDIR/ip_repo_local`
- Python（仅验证脚本用）：numpy、Pillow

## 4. 构建

```bat
:: 只有改过采集 RTL 时才需要重新打包 IP
vivado -mode batch -source package_capture_ip.tcl

:: 综合 + 实现 + bitstream（产物自动复制到 ready_to_test/ 与 pynq_overlay/）
vivado -mode batch -source build_btn.tcl
```

> 首次构建会重建全部 IP 生成物（`ipshared/`、`ip/*/synth` 等），比增量构建慢几分钟。

## 5. 验证

| 内容 | 命令 | 说明 |
|---|---|---|
| 采集 IP 等价性 | `vs_sim\run_capture_sim.bat` | 首次运行会自动调用 `vs_sim\prepare_capture_ref.py`，从本机资料盘生成 `_ref/` 参考副本 |
| Kuwahara 位精确 | `python verify_kuwahara.py` | 依赖工程外的 `style_cartoon_640x480.py` 与 `fortest.jpg` |
| 样式算子位精确 | `python verify_style.py` | 同上 |

**本包已实测**：只用 `ip_repo_local` 打开工程 → `validate_bd_design` rc=0 → `synth_design Complete!`
（即删掉 `ipshared/` 与 IP 生成物后仍可独立重建）。

## 6. 合规

第三方组件与许可见 `THIRD_PARTY_NOTICES.md`，许可全文在 `third_party/`。
**提交时这两个要一起交**——MIT / BSD 的授权条件就是"保留版权声明与许可文本"。

## 7. 提交前注意

- 若在本目录又跑过构建，会重新生成 `base.runs/`、`ipshared/` 等目录；提交前请再剔除一遍，
  或直接打包当前这份干净状态。
- `_ref/`、`_sim_ov5640/` 属仿真临时产物，不要提交。
- `ready_to_test/base.bit` 与 `base.hwh` 是配套的一对，必须同时提交。