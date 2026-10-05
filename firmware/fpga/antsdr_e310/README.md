[English](#en) | [中文](#cn)

<span id="en">Original ANTSDR E310 Micro-USB: UHD Port</span>
===========================

Experimental board port for single-channel UHD streaming. The target is the original ANTSDR E310 Micro-USB, not the Ettus E310 or ANTSDR E310V2. JTAG bring-up passed an OCM program and a 16 KiB DDR check, then booted Linux with PS GEM, nixge DMA and a bridge. UHD discovery, register loopback, AD9361 digital loopback and srsRAN RF API streaming pass. The highest passing duplex test is 7.68 MS/s for 5 seconds; 15.36 MS/s still underflows/overflows. RF loopback and a complete LTE cell have not been verified.

## Reference Revisions

* `uceeyuf/antsdr_uhd`: `b5ebd04a5f405ac3102a772e5d1e8f1be21a7dc3`.
* `uceeyuf/antsdr_standalone`: `6fd18ba3fd8e7809ec838bfbf2e522e1045af4f8`.
* Standalone MicroPhase/hdl submodule: `a329fa58bb62bd94cc37f3e98528a1e0f6e1afe7`; board reference files `projects/antsdre310/system_bd.tcl`, `system.xdc`, `system_top.v`.
* RF switch selection and initial AD9361 delays: standalone `app_e310/command.c` and `main.c`.
* Micro-USB schematic: [MicroPhase/antsdr-fw](https://github.com/MicroPhase/antsdr-fw/blob/master/schematic/ant_e310_Public.pdf).

## Hardware and Integration

* Separate top level, constraints and Vivado 2020.2 scripts; PS GEM0 RGMII on MIO16–27, MDIO on MIO52–53, PHY reset on MIO46; PS bank1 at 1.8 V.
* UHD/B200 DSP and timestamps, AXI DMA and the DDR TX FIFO are retained. `eth_internal` connects DMA directly to the FPGA CHDR endpoint, replacing the V2 PL RGMII path.
* The old-board UHD profile selects LVDS, RF port B through 3 GHz and port A above it, and the internal reference clock. Existing E200/V2 profiles retain CMOS settings.
* One RX/TX channel only (radio 0 / 1R1T); a second channel and 2R2T are rejected.
* Device tree, FPGA endpoint setup, discovery daemon and loopback tools are included.

The board-tested `ad936x_sin` reference supplied the comparison for
`vivado/ipdef/ad936x_dev_if_idelay/ad936x_dev_if_idelay.v` and `vitis/demo/src/main.c`.
The RX IDDR falling-edge half-word needs one cycle of alignment; TX uses an inverted feedback clock and FPGA IDELAY tap 8. Before the RX correction, frame readback was `0x99`, which never matched the `1100` valid frame and left the RX FIFO empty. `tests/tb_e310_rx_alignment.sv` checks the post-IDDR alignment and I/Q separation; it does not model electrical delay.

The reference's second-channel `adc_data_q2 <= rx_data_i2_r2` assignment is a typo. This port uses only the first channel and does not reuse that second-channel path.

TX FIFO recovery requires more than a longer startup reset: after AD9361 initialization it could remain full=1/empty=1. UHD now pulses `SR_CORE_MISC[9]` for 2 ms to reset only the LVDS interface after DATA_CLK stabilizes, including master-clock changes. Separate masked PRBS checks established the RX I/Q mapping. This TX serializer requires AD9361 TX IQ swap disabled and RX IQ swap retained (`0x010=0x48` in 1R1T). Three repeated initializations passed; a 10-second 1.92 MS/s RX run had no dropped samples, overflow, sequence errors or timeouts.

## Data Path

```text
Host Ethernet ↔ PS GEM0 ↔ Linux bridge ↔ nixge AXI DMA
              ↔ PL eth_internal ↔ UHD radio core ↔ AD9361 LVDS
```

There is no userspace sample relay or NAT. PS management and the PL endpoint use distinct IP/MAC addresses. The discovery daemon responds on UDP 49100 with the PL address and `product=E310`, so this branch's UHD host sends subsequent control/data directly to PL.

Linux uses the first 512 MiB of DDR; the remaining 512 MiB is reserved for the TX FIFO. PHY address 0 and ID `0141:0dd1` were read over MDIO; the schematic's 88E1512 is recognized by Linux as the Marvell 88E1510 family. `tune-network-irqs.sh` puts PS Ethernet on CPU0 and PL DMA on CPU1; `bridge-bringup.sh` invokes it after assigning the management IP.

## Build

From the repository root, without SDK 2019.1:

```sh
firmware/fpga/antsdr_e310/build.sh project
firmware/fpga/antsdr_e310/build.sh synth
firmware/fpga/antsdr_e310/build.sh place
firmware/fpga/antsdr_e310/build.sh route
firmware/fpga/antsdr_e310/build.sh bitstream
firmware/fpga/antsdr_e310/build.sh test
```

Default Vivado is `/tools/Xilinx/Vivado/2020.2/bin/vivado`; override with `VIVADO`.
`project` preserves an existing XPR. `synth` reruns synthesis; `place` checks placement; `route` completes routing. `bitstream` checks DRC and constrained setup/hold paths before export. `rebuild` runs synthesis, implementation and export in one Vivado process. `test` runs the DMA Ethernet ARP/backpressure test in XSim and needs XSim's system GCC dependencies.

Reports go to `artifacts/`. `e310_synthesis_only.xsa` has no bitstream; `antsdr_e310_experimental.xsa` includes the routed experimental bitstream. The firmware root Makefile has no E310 release target yet. Full FSBL/U-Boot/Linux/rootfs/BOOT.BIN integration remains open; do not combine this XSA with an E310V2 boot image. Compile the two board C programs with the rootfs's ARM Linux toolchain and install them, `bridge-bringup.sh`, and `tune-network-irqs.sh` into `/sbin`. The bridge script is for initial serial-console bring-up, not automatically enabled by this source tree.

## Constraints and Remaining Work

1. The selected electrical configuration follows standalone's pins, LVDS_25, internal differential termination and LVCMOS25, as specified for this bring-up. The public Micro-USB schematic labels VCC_1V8 differently; this configuration is not a measured rail-voltage result. DRC severity was not reduced.
2. Complete external input/output timing constraints and CDC review remain open. Routed internal timing alone does not establish external interface timing over all AD9361 rates; initial LVDS delays require board testing.
3. Only channel 0 is supported. The inherited CHDR 12-bit conversion logic still has latch warnings; these tests use `sc16`.
4. RF transmission/wired RF loopback, long-duration throughput and a complete LTE stack remain unverified. The diagnostic GPIO readback page reports internal LVDS status, not external GPIO.

## Digital Loopback Results (2026-09-30)

Use `antsdr_e310_digital_loopback` built from this fork. Test addresses were host `192.168.10.1`, PS `192.168.10.2`, PL UHD endpoint `192.168.10.3`.

```sh
antsdr_e310_digital_loopback 192.168.10.3 5 1 /tmp/e310-qpsk.fc32 codec 7680000 qpsk
```

Arguments: address, seconds, tone sign, IQ output, `fpga|codec`, sample rate, `tone|qpsk`.
`fpga` loops DUC→DDC; `codec` loops FPGA/LVDS→AD9361 digital port→return.
CODEC mode keeps TX digital enabled, powers down TX DACs/upconverters, and applies 89.75 dB TX attenuation. Disabling the whole TX chain instead returns zeros. The driver checks isolation registers and blocks TX gain, RF frequency, bandwidth and master-clock changes while diagnostic streaming is active; RX gain remains adjustable for srsRAN initialization. These measurements did not use an external RF loopback.

| CODEC duplex rate | Duration | RX samples | Checked QPSK bits | Bit errors | Decision EVM |
| :-- | --: | --: | --: | --: | --: |
| 1.92 MS/s | 1 s | 1,920,000 | 118,400 | 0 | 0.356% |
| 3.84 MS/s | 1 s | 3,840,000 | 238,400 | 0 | 0.358% |
| 7.68 MS/s | 5 s | 38,400,000 | 2,398,400 | 0 | 0.355% |

All runs had zero RX errors, TX asynchronous errors and timestamp gaps. QPSK symbols are generated by absolute index, at 32 samples/symbol. Alignment is chosen once from the preamble, with no later resynchronization or phase correction. This checks those QPSK bits, not every raw 12-bit sample. FPGA and CODEC tone modes also each passed a 10-second 1.92 MS/s run.

Before IRQ splitting, a 5-second 7.68 MS/s duplex diagnostic recorded 40 RX overflows, 947 TX underflows and 42 TX sequence errors, with CPU0 saturated by network softirqs. Splitting the IRQs enabled the passing run above. 15.36 MS/s still fails; the remaining bottleneck is not fully attributed. PS GEM is already 1000 Mbps full duplex, 125 MHz reference clock, MTU 1500. Short tests do not establish long-term stability.

### srsRAN RF API

Used srsRAN_4G `bef8680d5f9714f3e040e6f9cbc88d7888439b6d` (25.10.0), building only the RF libraries and linking this fork's UHD. Source and compile instructions: [tests/srsran/README.md](tests/srsran/README.md).
At 1.92 MS/s, TX 2,304,000 / RX 1,920,000 samples, zero RF errors and timestamp gaps, coherent +30 kHz tone power 0.999986498, image rejection 108.479 dB. The plugin uses `uhd_unknown` Generic handling. Full srsENB/EPC was neither built nor started, and no LTE cell or phone attachment was tested.

### Later RF Validation

`host/examples/antsdr_e310_loopback.py` requires this fork's UHD Python bindings and NumPy; only its syntax has been checked. Its TX1→attenuator→RX1 RF connection, attenuation and transmission settings need separate setup and testing. The digital results do not establish RF performance, other master-clock combinations, or complete I/O timing and CDC closure.

This commit contains sources and tests. Generated bit/XSA files, JTAG RAM boot packages, rootfs, raw IQ and local toolchains are excluded from Git. FPGA rebuilding is scripted here; a fully reproducible Linux/JTAG image build is still pending.

---

<span id="cn">老 ANTSDR E310 Micro-USB：UHD 首版移植</span>
===========================

本目录是实验性的板级移植，面向单板 UHD 连续收发与有线射频回环。
不是 Ettus E310，也不是 ANTSDR E310V2。PS 已通过 JTAG 完成最小 OCM 程序和
16 KiB DDR 初测，并已通过 JTAG 启动 Linux、PS GEM 网口、nixge DMA 和 bridge；
UHD 发现、寄存器回环、AD9361 CODEC 数字回环和 srsRAN RF API 收发已通过。
当前最高通过的双向数字回环测试档位为 7.68 MS/s（5 秒）；15.36 MS/s 仍有欠载／溢出。
完整 LTE 小区、手机入网和射频回环尚未验证。测试记录见下文。

## 固定的参考版本

- `uceeyuf/antsdr_uhd`：`b5ebd04a5f405ac3102a772e5d1e8f1be21a7dc3`。
- `uceeyuf/antsdr_standalone`：`6fd18ba3fd8e7809ec838bfbf2e522e1045af4f8`。
- standalone 的 MicroPhase/hdl 子模块：`a329fa58bb62bd94cc37f3e98528a1e0f6e1afe7`。
  对照 `projects/antsdre310/system_bd.tcl`、`system.xdc` 与 `system_top.v`。
- RF 开关规则和初始 AD9361 延时来自 standalone `app_e310/command.c`、`main.c`。
- Micro-USB 原理图：[MicroPhase/antsdr-fw](https://github.com/MicroPhase/antsdr-fw/blob/master/schematic/ant_e310_Public.pdf)。

## 已实现的修改

- 独立的 `antsdr_e310` 顶层、约束和 Vivado 2020.2 工程脚本。
- 使用 PS GEM0，RGMII 经 MIO16–27，MDIO 经 MIO52–53，复位 MIO46；PS bank1 为 1.8V。
- 保留 UHD/B200 DSP、时间戳、AXI DMA 和 DDR TX 深 FIFO。
- 使用仓库里的 LVDS 接收/发送逻辑，在本目录补齐缺失 FIFO、未连接的控制信号，
  修正全局时钟缓冲；以 standalone 的物理引脚、初始延时作板级适配。
- 通过 `eth_internal` 将 DMA 接到 FPGA CHDR 端点，移除 V2 的 PL RGMII。
- UHD 精确识别 `product=E310`，选择 LVDS；3 GHz 及以下使用 RF port B，以上使用 A；
  仅公布内部参考时钟支持。原 E200/V2 仍走其原有 CMOS 设置。
- 提供实验设备树、板端端点配置程序、发现服务，以及单进程 Python 射频回环工具。

## 实板最小工程对照

用户提供的 `ad936x_sin` 最小工程已实板验证。对照其
`vivado/ipdef/ad936x_dev_if_idelay/ad936x_dev_if_idelay.v` 和
`vitis/demo/src/main.c`，本移植增加 RX IDDR 下降沿的一拍对齐，
采用反相 TX 反馈时钟，并将 FPGA IDELAY tap 改为 8。
修改前实板帧调试值为 `0x99`，无法命中 `1100` 有效帧，RX FIFO 一直为空。
`tests/tb_e310_rx_alignment.sv` 检查 IDDR 后的半字对齐及 I/Q 分离，
不模拟模拟输入延时，也不代替数字接口上板测试。

参考工程的第二通道输出存在 `adc_data_q2 <= rx_data_i2_r2` 笔误；
本移植仅支持第一通道，没有沿用该第二通道路径。

## 数据通路

电脑网口 → PS GEM0 → Linux bridge → nixge AXI DMA → PL eth_internal → UHD radio core。
返回方向相反。样本不经过用户态 UDP 转发，也不使用 NAT。

PL 端点和 PS 管理接口有不同的 IP/MAC。发现服务只回应 UDP49100 的发现报文，
返回 PL 的源 IP/MAC，使 UHD 后续直接向 FPGA 端点发送控制和数据。
发现报文里的板型号是 `E310`，必须使用本分支的 UHD host。

设备树将 Linux 内存限制在前 512 MiB，保留后 512 MiB 给原设计的 TX FIFO。
GEM0 PHY 地址经实板 MDIO 扫描确认为 0，ID 为 0141:0dd1；
PHY 为原理图上的 88E1512，Linux 识别为 Marvell 88E1510 系列。
板端 bridge 和 DMA 已通过实板收发。`tune-network-irqs.sh` 将 PS 网口 IRQ 分配给
CPU0、PL DMA IRQ 分配给 CPU1，避免双向流量集中到 CPU0；首次启动脚本在配置管理 IP 后调用它。

## 重建

在仓库根目录运行，不需要 SDK 2019.1：

```sh
firmware/fpga/antsdr_e310/build.sh project
firmware/fpga/antsdr_e310/build.sh synth
firmware/fpga/antsdr_e310/build.sh place
firmware/fpga/antsdr_e310/build.sh route
firmware/fpga/antsdr_e310/build.sh bitstream
firmware/fpga/antsdr_e310/build.sh test
```

默认 Vivado 为 `/tools/Xilinx/Vivado/2020.2/bin/vivado`，可用 `VIVADO` 覆盖。
`project` 不覆盖已有 XPR；`synth` 重跑综合；`place` 仅检查布局；`route` 完整布线，
`bitstream` 在已布线且已约束路径 setup/hold 通过后生成实验位流和含位流的 XSA。
`test` 为 AXI DMA 以太网 ARP／背压仿真，要求 XSim 的系统 GCC 依赖可用。
报告位于 `artifacts/`。`e310_synthesis_only.xsa` 不含位流；
`antsdr_e310_experimental.xsa` 为完整布线后导出的实验硬件平台，包含位流。

此阶段尚未把 `e310` 加入固件根 Makefile 的可发布目标。
FSBL、U-Boot、Linux、rootfs 和 BOOT.BIN 的完整集成仍待完成；不能把此 XSA 和
E310V2 的启动镜像混用。板端两个 C 程序使用对应 rootfs 的 ARM Linux 工具链编译，
与 `bridge-bringup.sh`、`tune-network-irqs.sh` 一起安装到 `/sbin`。`bridge-bringup.sh` 仅用于串口控制台的首次联调，不会自动执行。

## 联调范围与未完成事项

1. **电气配置选择**：按用户明确指定，采用 standalone 的原有引脚及 LVDS_25、
   内部差分终端、LVCMOS25 配置继续上板联调。公开 Micro-USB 原理图的 VCC_1V8
   标注与它有差异，尚无实测供电数据；此选择不是实测电压结论。未降低 DRC 严重性。
2. 输入/输出延时、不同 AD9361 采样率的时序约束与 CDC 审查尚未完成，布局成功
   不是时序收敛。LVDS 初始延时只是参考值，必须做数字接口校准／测试模式验证。
3. 本首版固定为 1R1T，UHD 拒绝第二通道及双通道请求。第二射频通道和 2R2T
   留待后续添加；目前只使用通道 0。
4. UHD host、JTAG Linux、桥接、设备发现、寄存器回环和 CODEC 数字回环已实测通过。
   TX FIFO 在 AD9361 初始化后曾卡于 full=1/empty=1；延长上电复位不足以解决，
   必须在 DATA_CLK 稳定后使用 SR_CORE_MISC[9] 单独复位 LVDS 接口。host 在初始化及
   主时钟变化后执行此复位。RX I/Q 用独立屏蔽的 PRBS 确认；本 TX 串行器要求关闭
   AD9361 TX IQ swap（1R1T 寄存器0x010=0x48），保留 RX IQ swap。
   三次重新初始化均通过；1.92 MS/s 单通道 RX 10秒测试无丢样、overflow、序号错误或超时。
   srsRAN RF API 的 1.92 MS/s CODEC 回环已通过；RF 发射／有线 RF 回环、
   长时吞吐和完整 LTE 协议接入尚未验收。
   现有 CHDR 12-bit 转换模块仍有继承的 latch 告警；首轮使用 `sc16`。

`build.sh rebuild` 可在一个 Vivado 进程内执行综合、实现、位流导出；导出前检查 DRC
和已约束路径的 setup/hold。实验 FPGA 的内部 GPIO 回读页用于 LVDS 诊断，不代表外部 GPIO。

## 数字回环验收（2026-09-30）

主机使用本分支构建的 `antsdr_e310_digital_loopback`。测试地址为主机
192.168.10.1、PS 管理 192.168.10.2、PL UHD 端点 192.168.10.3。

```sh
antsdr_e310_digital_loopback 192.168.10.3 5 1 /tmp/e310-qpsk.fc32 codec 7680000 qpsk
```

参数依次为地址、秒数、单音正负号、IQ 输出文件、`fpga|codec`、采样率、`tone|qpsk`。
`fpga` 测试 DUC→DDC，`codec` 测试 FPGA/LVDS→AD9361 数字端口→返回。
CODEC 模式保留 TX 数字通道，同时关断 TX DAC 与上变频器，设置 89.75 dB TX 衰减；
完全关闭 TX 通道会导致数字回环全零。驱动回读隔离寄存器，并限制诊断期间的 TX 增益、
射频频率、带宽和主时钟变更；允许 srsRAN 初始化所需的 RX 增益设置。
本次测试使用数字回环，未连接或验证外部射频回环。

| CODEC 双向采样率 | 时长 | RX 样本数 | 检查的 QPSK 比特 | 比特错误 | 判决 EVM |
| --- | --- | --- | --- | --- | --- |
| 1.92 MS/s | 1 秒 | 1,920,000 | 118,400 | 0 | 0.356% |
| 3.84 MS/s | 1 秒 | 3,840,000 | 238,400 | 0 | 0.358% |
| 7.68 MS/s | 5 秒 | 38,400,000 | 2,398,400 | 0 | 0.355% |

以上 RX 错误、TX 异步错误、时间戳断点均为 0。QPSK 每 32 样本一个符号，按绝对符号序号
生成；只在前段确定一次整数延迟，后续不重新同步、不纠正相位。此结果仅对应检查过的
QPSK 比特，不等价于全部 12 位原始样本的逐位 BER。1.92 MS/s 的 FPGA 与 CODEC
单音模式也各通过 10 秒测试。

7.68 MS/s 分核前的 5 秒吞吐诊断记录 RX overflow 40、TX underflow 947、TX sequence
error 42，CPU0 网络软中断占满；分核后通过上表测试。15.36 MS/s 分核后仍失败，
具体剩余瓶颈待查。实板 PS GEM 已是 1000 Mbps 全双工，GEM 参考时钟 125 MHz、MTU 1500。
不能将短时通过结果视为长期吞吐保证。

### srsRAN RF API

测试使用 srsRAN_4G `bef8680d5f9714f3e040e6f9cbc88d7888439b6d`（25.10.0），
只构建 RF 库，并链接本分支 UHD。独立测试源码与编译方法见
[tests/srsran/README.md](tests/srsran/README.md)。1.92 MS/s 实测 TX 2,304,000、RX 1,920,000，
RF 错误及时间戳断点为 0，+30 kHz 单音相干功率占比 0.999986498、镜像抑制 108.479 dB。
srsRAN 插件使用 `uhd_unknown` 的 Generic 路径。尚未编译／启动完整 srsENB/EPC，
未建立 LTE 小区，也未做手机入网。

### 后续射频回环

`host/examples/antsdr_e310_loopback.py` 是需要 UHD Python 绑定和 NumPy 的有线射频测试工具，
目前仅做过语法检查。外部 TX1→衰减器→RX1 的连接、衰减与发射参数需单独配置后验证。
本目录的数字测试结果不证明射频路径、其他主时钟组合或完整 I/O 时序与 CDC 已验收。

当前提交保存源码和测试程序；生成的 bit/XSA、JTAG RAM 启动包、rootfs、原始 IQ 和本机
工具链不放入 Git。可从本目录重建 FPGA；整套 Linux/JTAG 镜像的一键可复现构建仍待集成。
