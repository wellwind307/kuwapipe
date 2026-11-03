# sim/ —— 仿真与验证

| 文件 | 内容 |
|---|---|
| `tb_video_kuwahara.v` | Kuwahara 全尺寸 bit-exact 自校验 testbench（`-d TB_FULL` 切 800×480） |
| `tb_video_mode_switch.v` | 处理/直通切换状态机自校验 |
| `tb_video_style.v` | style（gamma/饱和度/量化）自校验 |
| `tb_ov5640_capture.v` | 采集 IP 与原厂实现的逐拍等价性协同仿真 |
| `prepare_capture_ref.py` | 现场生成参考副本（转 UTF-8 + 补 timescale，**不进提交包**） |
| `run_kw_sim.bat` / `run_capture_sim.bat` / `run_style_sim.bat` | 一键编译 + 仿真（Kuwahara / 采集 IP 等价性 / 抖动量化） |
| `tb_kw_in.hex` / `tb_kw_exp.hex` / `*.png` | 仿真激励 / 期望向量（全尺寸 `tb_full_*.hex` 不入库，需 `--tb-full` 现场生成） |
| `verify_kuwahara.py` | Python 位精确模型 vs golden 的逐位比对（内部像素 300516/300516 一致） |
| `verify_style.py` | style 链路比对（各配置 0 LSB） |
| `make_preview.py` | 生成对比图（输出在 `../data/`） |
| `gen_gamma_lut.py` | 生成 `../src/base.srcs/sources_1/new/gamma_lut.mem` |
| `logs/` | xsim 仿真日志（含 384000/384000 bit-exact、91063 拍 0 失配、模式切换 13292 拍 0 失配） |

## 复跑

```bat
:: Kuwahara 位精确模型（需 ../data/ 里的 golden 与测试图）
python verify_kuwahara.py

:: Kuwahara RTL 自校验（64x48 小图快速回归）
run_kw_sim.bat

:: 抖动/量化自检（8x8 恒值块，期望 avg_R=167、level_errors=0）
run_style_sim.bat

:: 采集 IP 等价性（首次会用 prepare_capture_ref.py 现场生成参考副本）
run_capture_sim.bat
```

> 功能一致性的**判据来自 xsim**（全尺寸 800×480 密集流 `captured=384000/384000, mismatch=0`；
> 采集 IP 等价性 `91063 拍 / 0 失配`）。板上只做功能演示与性能测量，不做逐像素比对
> （原因见 `../build/metrics.md` §2）。

### 运行环境

- **xsim**：`run_*.bat` 会先找 PATH 里的 Vivado（`xvlog.bat`），找不到再退回本机
  `C:\Users\30750\Myvivado\2025.2\Vivado\bin`。
- **Python**（离线脚本 + 现场生成向量/参考副本）：`run_kw_sim.bat`、`run_capture_sim.bat`
  按 `%PYTHON%` → `python` → `py -3` 的顺序找一个可用的解释器；若你机器上的 `python`
  只是微软商店的占位程序，先 `set PYTHON=<python.exe 的完整路径>` 再运行。
  `verify_kuwahara.py` / `make_preview.py` 需要 numpy、Pillow。

### 已实测（2026-11-04 复跑）

| 命令 | 结果 |
|---|---|
| `python verify_kuwahara.py` | 内部像素 300516/300516 逐位一致，`VERIFY RESULT: PASS` |
| `python verify_style.py` | 全部配置 0 LSB |
| `run_kw_sim.bat` | `captured=6144/6144 mismatch=0 extra=0 flag_err=0`，`=== PASS ===` |
| `run_style_sim.bat` | `captured=64 avg_R=167 level_errors=0`，`=== PASS ===` |
| `run_capture_sim.bat` | `compared cycles: 91063 mismatches: 0`，`RESULT: PASS` |
