# 仿真与验证

| 文件 / 目录 | 内容 | 结果 |
|---|---|---|
| `kw_sim_full800x480.log` | Kuwahara 全尺寸 800x480 密集流，xsim 自校验 | captured 384000 / 384000，mismatch 0 |
| `kw_sim_gap12.log` | 64x48 两帧，行间 12 拍消隐，下游随机反压 | mismatch 0 |
| `kw_sim_gap0.log` | 同上，消隐压到 0（纯反压推进） | mismatch 0 |
| `mode_switch_sim.log` | 处理/直通切换状态机 | mismatch 0（切换瞬态丢 4 拍属预期） |
| `ov5640_equiv_sim.log` | 采集 IP 与原厂实现逐拍等价性 | 91,063 拍，mismatch 0 |
| `../vs_sim/*.v` | testbench 源码 | — |

## 如何复跑

```bat
:: Kuwahara 位精确模型（需工程外的 golden 与测试图，见 data/）
python verify_kuwahara.py

:: 采集 IP 等价性（首次会用 prepare_capture_ref.py 现场生成参考副本）
vs_sim\run_capture_sim.bat
```