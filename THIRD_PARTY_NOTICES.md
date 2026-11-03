# 第三方组件与许可声明（Third-Party Notices）

工程：KuwaPIPE 提交包 `kuwapipe/`（源自开发工程 `base_2025_2_kuwahara_btn`；目录已按竞赛要求的
`src/ sim/ build/ board/ data/ skill/ report/` 结构重排，下表的路径均为重排后的实际位置）
适用文件：《参赛作品承诺及使用授权书》第一条——
> 本队所提交的参赛作品为**原创设计或已获得知识产权权属方的合法授权**，不存在任何侵权行为。

本声明把"原创设计 / 已获授权"两条逐项落实并留痕。文件本身不参与综合，不影响 bitstream。

---

## 1. 组件清单

| # | 组件 | 版本 / VLNV | 权利方 | 许可 | 工程内位置 | 本队是否修改 |
|---|---|---|---|---|---|---|
| 1 | Kuwahara 保边平滑 RTL：`kuwahara.v` `linebuf.v` `box4col.v` `luma_q8.v` `video_kuwahara.v` | — | 本队 | **原创** | `src/base.srcs/sources_1/new/` | 自研 |
| 2 | 模式切换与旁路：`video_mode_switch.v` `video_style.v` `video_style_bypass.v` | — | 本队 | **原创** | 同上 | 自研 |
| 3 | 早期模块：`median9.v` `video_median_color.v` `video_delay_mux.v` | — | 本队 | **原创**（仅参考公开算法思想） | 同上 | 自研 |
| 4 | **摄像头采集 IP：`ov5640_capture.v`** | `user:ip:ov5640_capture:1.0` | 本队 | **原创** | `src/base.srcs/sources_1/new/ov5640_capture.v`、`src/ip_repo_local/ov5640_capture/` | 自研 |
| 5 | Python 位精确模型 / 自校验：`verify_kuwahara.py` `make_preview.py` `verify_style.py` `gen_gamma_lut.py` | — | 本队 | **原创** | `sim/` | 自研 |
| 6 | xsim testbench：`tb_video_kuwahara.v` `tb_video_mode_switch.v` `tb_video_style.v` `tb_ov5640_capture.v` | — | 本队 | **原创** | `sim/` | 自研 |
| 7 | AMD Vivado 标准 IP（PS7、VDMA、VTC、Video In/Out 等） | Vivado 2025.2 | AMD | Vivado/Vitis EULA | `src/base.srcs/sources_1/bd/base/ip/` | 未修改（工具生成） |
| 8 | HLS IP：`median_blur_color` `color_convert` `pixel_pack` `pixel_unpack` | `xilinx.com:hls:*:1.0` | 由本队 HLS 工程生成（其中 3 个的 C++ 源来自 PYNQ，见 #10） | 工具输出 + PYNQ BSD-3 | `src/base.srcs/sources_1/bd/base/ip/` | 由本队配置并生成 |
| 9 | Digilent：`rgb2dvi` v1.4、`axi_dynclk` v1.0、`if/pmod`、`if/tmds` | `digilentinc.com:*` | © Digilent | **MIT**（`rgb2dvi.vhd` 文件头为 **BSD-3**） | `src/ip_repo_local/`（随包内置） | 未修改 |
| 10 | Xilinx PYNQ：`io_switch` 1.1、`audio_codec_ctrl` 1.0、`dff_en_reset_vector` 1.0、HLS 源码 | `xilinx.com:user:*` / `xilinx.com:hls:*` | © Xilinx | **BSD-3-Clause** | `src/ip_repo_local/`（随包内置） | 未修改 |
| 11 | 算法参考：Kuwahara 滤波 | Kuwahara et al., 1976 | 公开文献 | 无版权 / 无专利 | — | 独立实现 |
| 12 | 演示输入图像 `fortest.jpg` 及其派生图 | — | 本队成员 | **原创（自行拍摄）** | `data/` | — |
| 13 | golden 参考模型 `style_cartoon_640x480.py`（早期版本为 `style_reference*.py`） | — | 本队 | **原创（自行编写）** | `data/` | — |
| 14 | ~~正点原子 `cmos_capture_data` v1.1~~ | — | — | **已移除**：BD 不再例化，`ipshared/949d/` 已删除 | — | — |
| 15 | PS 侧控制脚本 `src/ps/kuwahara_ps.py` / `src/ps/kuwahara_ps.ipynb` | — | 本队重写（形态派生自 PYNQ base overlay 示例，© Xilinx，BSD-3） | **MIT / 派生说明见 `board/PS_CODE_NOTES.md`** | `src/ps/` | 已重写：删除人脸检测残留，显示按 DVI 限制用 640x480 |

---

## 2. 摄像头采集 IP 的替换（本次主要改动）

原设计使用正点原子 `cmos_capture_data`（`All rights reserved`，无开源许可）。为消除授权不确定性，
本队依据其**对外可观测行为**重写了 `ov5640_capture.v`，并打包为 IP 替换原单元。

**功能等价性验证（不是"看起来能出图"）**

`sim/tb_ov5640_capture.v` 并排例化"原 IP（仅作比对参考）"与"自研模块"，喂同一组
`cam_pclk / cam_vsync / cam_href / cam_data`，逐拍用 `!==` 比较全部输出：

```
compared cycles : 91063
mismatches      : 0
RESULT          : PASS
```

覆盖：上电复位→释放、30 帧（首行 1600 字节模拟 800 像素宽）、行/场消隐随机抖动、
帧末随机空闲、运行中复位 10 拍后重新对齐再跑 15 帧。

期间发现并修正过一处真实差异：原 IP 在**消隐期保持最后一个像素**而非清零，
自研模块初版清零，被该 TB 抓到后已改为一致行为。

**替换方式**

- RTL：`src/base.srcs/sources_1/new/ov5640_capture.v`（自研，含 `vid_io` 接口属性）
- IP：`src/ip_repo_local/ov5640_capture/`（`user:ip:ov5640_capture:1.0`）
- BD 单元：`/video/camera_in/frontend/ov5640_capture_0`（原 `cmos_capture_data_0` 已删除）
- 可重复执行脚本：`build/modify_capture.tcl`（替换）、`build/package_capture_ip.tcl`（打包）

> 说明：`ipshared/949d/SRC/cmos_capture_data.v` 已从本副本删除。删除后已重新打开工程并
> 通过 `validate_bd_design`（rc=0）、`synth_design Complete`，并重新跑完
> 综合/实现/bitstream（0 error），bit/hwh 由最终干净工程树生成。
>
> **改 RTL 后必须重新打包**：先跑 `package_capture_ip.tcl`，再跑 `build_btn.tcl`；
> 否则 BD 用的仍是 `ip_repo_local` 里的旧副本。

---

## 3. 工程内第三方源码的实际分布

| 目录 | 内容 | 权利方 / 许可 | 处理 |
|---|---|---|---|
| `src/ip_repo_local/` | Digilent `rgb2dvi` / `axi_dynclk`、PYNQ `io_switch` / `audio_codec_ctrl` / `dff_en_reset_vector`、HLS `color_convert` / `pixel_pack` / `pixel_unpack`、自研 `ov5640_capture` | 见 §1 第 4/9/10 行 | 随包内置（许可全文在 `third_party/`） |
| `src/base.srcs/sources_1/bd/base/ip/` | BD 中每个 IP 实例的 `.xci` 与配置 | AMD / Digilent / Xilinx，见 §1 | 保留（保留版权头） |
| `src/base.srcs/sources_1/bd/base/ipshared/` | 厂商 IP 的生成源码 | 同上 | **本提交包不含**：构建时由 Vivado 自动重建（正点原子 `ipshared/949d/` 已删除） |
| `sim/_ref/` | 等价性验证用的原厂参考副本（仅转 UTF-8、补 timescale） | © 正点原子，专有 | **仅仿真用，不随包分发**；由 `sim/prepare_capture_ref.py` 现场生成 |

纯构建产物，打包时整体排除（根目录 `.gitignore` 已按同一清单写好）：

```
src/base.runs/   src/base.cache/   src/base.hw/   src/.Xil/
sim/work/   sim/_sim_ov5640/   sim/_ref/
*.log  *.jou  *.backup.log  *.backup.jou  __pycache__/
```

---

## 4. 已确认事项

- 演示输入图像 `fortest.jpg` 及其派生文件：本队成员自行拍摄 → 著作权归本队；
- golden 参考模型：本队自建 → 原创；
- 自研 RTL / IP / Python / testbench：原创；
- 摄像头采集 IP：已替换为自研实现，等价性经逐拍协同仿真确认。

> 仍需自查承诺书**第二条**：演示画面中不应出现他人肖像、实验室敏感设备或资料。

---

## 5. 作品报告可直接引用的一段

> 本作品由本队独立完成算法设计、RTL 实现、验证平台搭建与板级调试。作品在实现中使用了以下
> 第三方组件，均已按相应许可合法使用并在提交包中保留其版权声明：AMD Vivado 2025.2 标准 IP
> （依 Vivado 许可）；Digilent `rgb2dvi` / `axi_dynclk`（MIT / BSD-3-Clause，© Digilent）；
> Xilinx PYNQ `io_switch` / `audio_codec_ctrl` / `dff_en_reset_vector` 及 HLS `color_convert` /
> `pixel_pack` / `pixel_unpack`（BSD-3-Clause，© Xilinx）。摄像头采集模块 `ov5640_capture`
> （RGB565→RGB888、DVP 同步、上电稳定计数）为本队依据公开的 OV5640 DVP 时序自主实现，
> 并与原厂参考实现做了逐拍等价性协同仿真（91,063 拍 0 失配）。Kuwahara 滤波算法参考
> Kuwahara 等（1976）公开发表的论文，其 RTL 实现与 Python 位精确模型均为本队独立完成；
> 演示所用输入图像为本队成员自行拍摄，golden 参考模型为本队自建。详见 `THIRD_PARTY_NOTICES.md`。

---

## 6. 许可全文索引

| 文件 | 覆盖对象 |
|---|---|
| `third_party/LICENSE_Digilent_MIT.txt` | rgb2dvi、axi_dynclk、if/pmod、if/tmds（仓库级 MIT） |
| `third_party/LICENSE_Digilent_BSD-3_rgb2dvi.txt` | `rgb2dvi.vhd` 文件头 BSD-3 |
| `third_party/LICENSE_PYNQ_BSD-3.txt` | io_switch、audio_codec_ctrl、dff_en_reset_vector、HLS 三个源码 |
| `third_party/NOTICE_AMD_VIVADO.txt` | AMD Vivado IP 使用说明 |
| `third_party/NOTICE_ALIENTEK.txt` | 正点原子 IP 的来源与替换记录 |

---

## 7. 本副本相对原工程 `base_2025_2_kuwahara_btn` 的改动

| 类型 | 文件 | 改动 |
|---|---|---|
| 新增 | `src/base.srcs/sources_1/new/ov5640_capture.v` | 自研采集模块 |
| 新增 | `src/ip_repo_local/ov5640_capture/` | 打包后的 IP（`user:ip:ov5640_capture:1.0`） |
| 新增 | `build/package_capture_ip.tcl`、`build/modify_capture.tcl` | 打包与 BD 替换脚本（可重复执行） |
| 新增 | `sim/tb_ov5640_capture.v`、`sim/prepare_capture_ref.py` | 等价性验证（参考副本现场生成，不随包分发） |
| 新增 | `THIRD_PARTY_NOTICES.md`、`third_party/` | 本声明与许可全文 |
| **BD 改动** | `src/base.srcs/sources_1/bd/base/base.bd` | `cmos_capture_data_0` → `ov5640_capture_0`（IP），接口/网络按原对端接回 |
| 配置改动 | `src/base.xpr` | `IPRepoPath` **只保留** `$PPRDIR/ip_repo_local`（内置全部所需 IP，无外部依赖） |
| 路径修正 | `build/*.tcl` | `projdir` 由脚本位置自动推导，提交包整体搬移后仍可用 |
| 目录重排 | 全部 | 按竞赛要求的 `src/ sim/ build/ board/ data/ skill/ report/` 分层（原为扁平布局） |
| 清理 | 构建产物 / 日志 / 仿真临时 / 厂商源码副本 / 历史脚本 | 见根目录 `README.md` 与 `.gitignore` |

**未改动**：Kuwahara / 中值 / style 相关 RTL 与 BD 逻辑、Python、testbench。

**PS 侧代码**：`src/ps/kuwahara_ps.py` / `.ipynb` 由 PYNQ base overlay 的人脸检测示例改编后重写
（删除 `cv2` 与全部检测逻辑、修正分辨率 640→800、替换示例的保存路径与调试单元），
保留的仅是通用 PYNQ 调用形态。派生关系与逐项删改记录见 `board/PS_CODE_NOTES.md`。

**独立性实测**：在剔除 `ipshared/`、`ip/*/synth|sim` 与全部构建产物后，仅用 `ip_repo_local`
打开工程 → `validate_bd_design` rc=0 → `synth_design Complete!`，确认本包可脱离外部
`D:/my_big_file/FPGA/ip_repo` 独立重建。
