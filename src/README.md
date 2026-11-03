# src/ —— 设计源码（RTL / HLS / PS 侧软件）

本目录包含**完整可构建的 Vivado 工程**与 PS 侧软件：

| 路径 | 内容 |
|---|---|
| `base.xpr` | Vivado 工程文件（IP 仓库已内置，`IPRepoPath` 只指 `ip_repo_local`，无外部依赖） |
| `base.srcs/sources_1/new/` | 自研 RTL（12 个 `.v` + `gamma_lut.mem`） |
| `base.srcs/sources_1/bd/base/` | Block Design（`base.bd` + IP 配置 + `hw_handoff/base.hwh`） |
| `base.srcs/constrs_1/new/base.xdc` | 引脚/时序约束 |
| `ip_repo_local/` | 自带 IP 仓库（自研 `ov5640_capture` + 10 个所需 IP） |
| `ps/kuwahara_ps.py` | **PS 侧主控制软件（命令行版）**：加载 Overlay → 初始化 OV5640(800×480) → 直通 → 抓帧 → 硬件自检 |
| `ps/kuwahara_ps.ipynb` | 同一程序的 **Notebook 纯源码版**（输出已清空）；带真实上板输出的那份在 `../board/kuwahara_ps.ipynb` |
| `README_kuwahara.md` | Kuwahara 算法/RTL 设计文档（流水线、等价性推导、资源时序） |
| `README_btn.md` | 按键切换/双模式体系结构文档 |
| `README_style.md` | gamma/饱和度/量化旁路文档 |
| `DITHER_FIX.md` | 抖动修正记录 |

## 自研 RTL 清单（`base.srcs/sources_1/new/`）

- Kuwahara 保边平滑：`kuwahara.v`、`video_kuwahara.v`、`linebuf.v`、`box4col.v`、`luma_q8.v`
- 处理/直通切换：`video_mode_switch.v`、`video_style.v`、`video_style_bypass.v`
- 采集前端：`ov5640_capture.v`（自研，替换原厂参考 IP）
- 早期模块：`median9.v`、`video_median_color.v`、`video_delay_mux.v`
- 查找表：`gamma_lut.mem`

> 构建脚本在 `../build/`；仿真在 `../sim/`；上板产物在 `../board/`。改 `ov5640_capture.v` 后
> 必须重跑 `../build/package_capture_ip.tcl` 再构建，否则 BD 仍用 `ip_repo_local` 里的旧副本。
