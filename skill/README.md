# Skill 包 — 从本项目沉淀的可复用经验

七项均**不与本队题目绑定**：换一个图像处理题目、换一块 Zynq 板卡仍可直接套用。
每项给出：适用场景 / 使用方法 / 已验证效果 / 失效条件 / 踩过的坑。

---

## S1 `ip-equiv-cosim` — 与原厂 IP 的逐拍等价性协同仿真

**适用场景**
要替换某个厂商 IP（许可不清、停更、或想自研），但下游时序敏感、不能"看着能出图"就算过。

**使用方法**
1. 把原厂源码复制为**仿真专用副本**（改 UTF-8、补 `` `timescale``），只进仿真、不进综合与提交包。
2. 写一个 TB 并排例化「原厂 IP」与「自研模块」，同一组输入激励。
3. 每拍用 `!==` 比较**全部输出**（含 X 检测），而不是只比数据总线。
4. 复位瞬态用 `cmp_hold` 屏蔽（两者复位语义常不同），从双方都放行后开始比。
5. 激励要覆盖：上电复位→释放、多帧连续、行/场消隐随机抖动、运行中复位后再对齐、超宽行。
6. PASS 条件写成「0 失配 **且** 比较拍数 > 阈值」，防止"没比几拍就 PASS"。

**已验证效果**
本项目替换 OV5640 采集 IP：91,063 拍、0 失配；过程中抓出 1 处真实差异（原 IP 在消隐期保持最后一个像素，
自研版清零），修正后才通过。

**失效条件**
原厂 IP 内部含未初始化存储/异步跨时钟域且无确定初值时，逐拍比较可能永不收敛——此时退化为"逐帧比对输出图像"。

**踩过的坑**
- `xelab -debug` 在本机直接 `EXCEPTION_ACCESS_VIOLATION`，去掉 `-debug` 即可。
- 原厂文件是 GBK 且无 `timescale`，xsim 报 `Module ... doesn't have a timescale`。
- 只比数据总线会漏掉 `ce/vsync/href` 的错拍。

---

## S2 `vivado-ip-swap` — 在 BD 中用自建 IP 替换厂商 IP（保持接口不动）

**适用场景**
已有一个能跑的 BD，想把其中某个 IP 换掉，又不想重画连线与接口。

**使用方法**
1. 先把自研 RTL 打包成 IP（`ipx::package_project`），而不是用 module_ref。
2. `ip_repo_paths` **追加**本地仓库（不要 `set_property` 覆盖，否则原有仓库路径全丢）。
3. 打开 BD，先**记录被替换单元每个引脚的对端**（`get_bd_nets` / `get_bd_intf_nets`）。
4. 删除旧单元 → 在**同一层次**新建单元 → 按记录的对端逐一接回。
5. 接口用 `connect_bd_intf_net`；时钟/使能等单独走 `connect_bd_net`。
6. `validate_bd_design` → `save_bd_design`，再跑 synth/impl 确认。

**已验证效果**
替换正点原子采集 IP 后：`validate_bd_design` rc=0、`synth_design Complete`、bitstream 0 error；
生成物 `base.hwh` 中厂商 VLNV 引用数从 1 归零，自研 IP 引用为 1。

**失效条件**
新 IP 的端口语义与原 IP 不同（例如位宽、字节序、消隐期行为）时，必须先用 S1 证明等价，不能只靠接线。

**踩过的坑**
- **module_ref 的输出不被 BD 当作时钟源**，会报 `clock pins are not connected to a valid clock source`；
  打包成 IP 后同一根线即可通过。
- 端口名撞上工程里已有的接口定义会**凭空推断出多余接口**并报缺引脚（本例 `cmos_frame_*` 撞了 `lcd` 接口），
  改名（如 `vid_*`）即可。
- Vivado 会缓存 module_ref 的旧端口表，改端口后要换新单元名。

---

## S3 `bit-exact-golden` — 浮点 golden 与定点 RTL 的逐位对齐

**适用场景**
先用 Python/NumPy 写参考实现，再把算法硬化；需要证明"硬件实现没有引入偏差"。

**使用方法**
1. 参考实现只用**可在硬件上精确复现**的算子；不可避免的浮点（如 /16）要单独证明其与定点等价。
2. 用整数判别式替代浮点方差：`disc = 16*sum(Y^2) - sum(Y)^2` 与 `var` 只差正常数因子，`argmin` 相同。
3. 舍入对齐：RTL 用 `q + ((rem>8) | (rem==8 & q[0]))`，等价于 `np.round` 的**银行家舍入**。
4. 比对时把"内部像素"和"边界像素"分开统计——边界策略不同是常态，不能混在一起看。
5. 单独做一个"把边界策略改成与 golden 一致"的模型，若此时全图 0 差异，就证明差异**只**来自边界。

**已验证效果**
Kuwahara 链路：内部像素 0 LSB 差异；把边界改 replicate 后全图 0 LSB。

**失效条件**
算法含迭代/自适应阈值/全图统计（如自动白平衡）时，定点与浮点无法逐位一致，只能做误差上界。

**踩过的坑**
- 只报"最大差 N LSB"没有意义，要同时报差异像素数占比，并区分内部/边界。
- 边界策略（补零 vs replicate）会让最外 3 行 3 列差异被误判成算法错误。

---

## S4 `hls-ip-geometry` — PYNQ 上 HLS IP 的几何参数不会被 VideoMode 配置

**适用场景**
用 PYNQ 的 `VideoMode` 改分辨率后画面错位/重影/被裁。

**使用方法**
1. 先怀疑 **HLS IP 里的行列循环是硬编码常量**，而不是 VDMA/VTC 的寄存器。
2. 在生成的 RTL 里搜 `icmp_ln*` 与 `10'd800` 这类常量，确认每行像素数与每帧行数。
3. 让自研模块的 `W/H` 参数跟随**上游 HLS IP 的实际几何**，不要跟随 `VideoMode`。
4. 若上游几何与 `VideoMode` 不一致，V_DMA 会按 `VideoMode` 裁切/错读。

**已验证效果**
本项目上游中值 IP 固定 800x480，而 `VideoMode` 用了 640x480：行缓存按 640 算时出现约 4 重错位重影，
按 800 修正后消失；全尺寸 384000/384000 像素 bit-exact。

**失效条件**
HLS IP 若把行列做成 AXI-Lite 可配寄存器，则不适用。

**踩过的坑**
- 只改 PYNQ 侧 `VideoMode` 不会改变 HLS IP 的行列常量。
- 行缓存深度必须 = `W + 消隐拍数`，否则帧间会漂移。

---

## S5 `stream-sync-align` — 流式/视频接口：数据与同步信号同拍对齐

**适用场景**
在视频/流式接口上插入自写处理模块后画面花屏、撕裂、错位，怀疑「这条通路不能加时钟延迟」。

**使用方法**
1. 先**反证**：在现有通路里找已经存在的、带寄存/延迟的模块（`axis_register_slice`、HLS IP 等），证明「延迟」本身不是问题。
2. 认清接口与必须同拍对齐的信号：AXI4-Stream 对齐 `TDATA + TUSER(SOF) + TLAST(EOL) + TVALID`（并正确处理 `TREADY` 反压）；并行视频总线对齐 `data + hsync + vsync + active_video`。
3. 数据延迟 N 拍时，同步标志**整组一起**延迟 N 拍，不能只延迟数据。
4. 反压：行缓冲/流水只按有效像素推进（`adv = tready && tvalid`），不要用墙钟移位。

**已验证效果**
本工程在 camera_in / hdmi_out 插处理模块：组合逻辑正常、时序逻辑花屏；按「数据与同步同拍」重写后画面正常。

**失效条件**
跨时钟域（CDC）不能靠同拍对齐，需 2 级同步 + `set_false_path`（见 S2 相关的 CDC 约束）。

**踩过的坑**
- 只延迟 TDATA 不延迟 TUSER/TLAST/TVALID → 帧/行错位、花屏。
- 行间消隐气泡：用「时钟域」valid 跟踪会在消隐气泡处 valid 与数据错位（手写彩色中值上板失败的根因）。

---

## S6 `bd-interface-check` — BD 接口对接：interface 是否真正展开到 signal pin

**适用场景**
模块仿真正确、直通就是一根导线，但上板连直通都不正常；或 `connect_bd_intf_net` 之后信号仍没连上。

**使用方法**
1. `connect_bd_intf_net` 连完 interface 后，检查 interface 是否**真正展开**到 signal pin（tdata/tkeep/tstrb/tlast/tuser/tvalid/tready）——只看 interface pin 连着 interface net 不够。
2. 若展开失败（signal pin 悬空），改用手动 `connect_bd_net` 逐个连接 signal pin。
3. 先验证「无处理的直通基线」，再增量加模块；模块插不进通路，算法再对也没用。

**已验证效果**
本工程「直通都不亮」最终定位为 interface 展开失败、signal pin 全悬空；手动补连后恢复。

**失效条件**
module reference 的 component.xml 缺接口宽度参数（TDATA_WIDTH 等）会触发展开失败，需先补参数或改用打包 IP。

**踩过的坑**
- 只关注自写 RTL 的仿真，忽略与相接模块的接口对接。
- 连完 interface 不检查 signal pin 的实际连接状态。

---

## S7 `pipeline-timing` — 组合逻辑时序收敛：打流水 + 并行化

**适用场景**
功能 bit-exact 的模块综合后时序违例（组合路径过长）；排序、多级乘加等长依赖链。

**使用方法**
1. 先读 report_timing_summary 定位违例路径。
2. 长依赖链拆流水：把「亮度计算 + 乘加」这类挤在同一组合级的拆成多级打拍。
3. 排序：串行选择排序（N 级依赖）改并行排序网络（奇偶转置，各级比较器互不依赖），再按需分段打拍。
4. 打拍后同步标志同样延迟（见 S5）。

**已验证效果**
sat 级拆两级流水、median9 从串行 36 级依赖改并行网络 + 4 级流水后，WNS 从 -15.386 ns 转正。

**失效条件**
受面积/资源约束不能无限打拍；跨时钟域路径不适用本方法。

**踩过的坑**
- 功能仿真 bit-exact ≠ 时序收敛。
- 为修反压删掉输出寄存器，会让组合逻辑直接怼进下一级（路径 12.7 ns）爆时序。