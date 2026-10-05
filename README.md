![Language](https://img.shields.io/badge/Language-Verilog_+_C_+_C%2B%2B-9A90FD.svg) ![Vivado](https://img.shields.io/badge/Vivado-2020.2-FF1010.svg) ![Board](https://img.shields.io/badge/Board-ANTSDR_E310_Micro--USB-blue.svg) ![Transport](https://img.shields.io/badge/Transport-1GbE-green.svg)

[English](#en) | [中文](#cn)

<span id="en">UHD on the Original ANTSDR E310 Micro-USB</span>
===========================

Fork of [MicroPhase/antsdr_uhd](https://github.com/MicroPhase/antsdr_uhd), containing the UHD host driver and ANTSDR firmware derived from Ettus Research's UHD. This branch adds an experimental port for the **original ANTSDR E310 with Micro-USB, Zynq-7020 and AD9361**, using **Vivado 2020.2** and the board design from `antsdr_standalone`. The ANTSDR E310V2 and Ettus USRP E310 are different targets.

Measured on the board: **7.68 MS/s full-duplex AD9361 digital loopback for 5 seconds, 38.4 million received samples, 2,398,400 checked QPSK bits with zero errors, and no RX/TX transport errors or timestamp gaps.** The **srsRAN 4G RF API** also passes a 1.92 MS/s digital loopback through its UHD plugin. **15.36 MS/s still underflows/overflows; an LTE cell, phone attachment and external RF loopback have not been verified.**

## Technical Features

* Separate [E310 FPGA target](firmware/fpga/antsdr_e310/README.md): LVDS interface, standalone board constraints, UHD/B200 DSP, timestamps, AXI DMA and DDR TX FIFO.
* Ethernet path: **host ↔ PS GEM0 ↔ Linux bridge ↔ nixge AXI DMA ↔ FPGA UHD core ↔ AD9361 LVDS**. Samples do not go through a userspace UDP relay.
* Old-board UHD profile: one RX and one TX channel, internal reference clock, board-specific RF port selection and I/Q mapping. E200 and E310V2 keep their existing profiles.
* RX half-word alignment, TX feedback clock and post-initialization LVDS reset fixes, with FPGA and AD9361 CODEC loopback diagnostics.
* Network IRQ affinity: PS GEM on CPU0 and PL DMA on CPU1. This removed the observed CPU0 softirq bottleneck at 7.68 MS/s duplex.
* JTAG RAM bring-up used for the measurements; no SD or Flash programming. The complete boot-image build remains to be integrated.

## Performance Test Results

Board measurements from 2026-09-30; `sc16` transport, 30.72 MHz master clock, one channel per direction. CODEC loopback keeps the digital TX path enabled while powering down the TX DAC/upconverters and applying maximum TX attenuation.

| CODEC duplex rate | Duration | RX samples | Checked QPSK bits | Bit errors | Decision EVM |
| :-- | --: | --: | --: | --: | --: |
| 1.92 MS/s | 1 s | 1,920,000 | 118,400 | 0 | 0.356% |
| 3.84 MS/s | 1 s | 3,840,000 | 238,400 | 0 | 0.358% |
| **7.68 MS/s** | **5 s** | **38,400,000** | **2,398,400** | **0** | **0.355%** |

All three runs had zero RX errors, TX asynchronous errors and timestamp gaps. The QPSK test uses 32 samples per symbol and a single fixed alignment; this is not a bitwise comparison of every raw 12-bit sample. These short runs do not establish long-duration stability.

srsRAN RF API: TX 2,304,000 / RX 1,920,000 samples at 1.92 MS/s, zero RF errors and timestamp gaps, coherent +30 kHz tone power 0.999986498 and image rejection 108.479 dB. The plugin uses the `uhd_unknown` Generic path. This tests the RF abstraction and UHD plugin, not a complete LTE stack.

## Build and Run

```sh
git clone --branch e310-vivado-2020.2 https://github.com/uceeyuf/antsdr_uhd.git
cd antsdr_uhd
firmware/fpga/antsdr_e310/build.sh project
firmware/fpga/antsdr_e310/build.sh rebuild
```

Default Vivado: `/tools/Xilinx/Vivado/2020.2/bin/vivado`; override with `VIVADO`. Build the matching host driver using [host/README.md](host/README.md). With the matching FPGA/Linux already running and the PL endpoint at `192.168.10.3`:

```sh
antsdr_e310_digital_loopback 192.168.10.3 5 1 /tmp/e310-qpsk.fc32 codec 7680000 qpsk
```

Detailed constraints, integration fixes, build scope and test instructions: [E310 port](firmware/fpga/antsdr_e310/README.md). Standalone srsRAN RF test: [tests/srsran](firmware/fpga/antsdr_e310/tests/srsran/README.md).

This is a source checkpoint, not a complete SD-card release. Generated bit/XSA files, rootfs, JTAG boot packages and raw IQ captures are excluded. Full external I/O timing and CDC review, RF tests, higher rates and other master-clock combinations remain open.

## Upstream Targets and Credits

The upstream E200/E310V2 sources remain in `firmware/` and `host/`. Their [upstream quick start](https://github.com/MicroPhase/antsdr_uhd#quick-start-guide) and [released SD images](https://github.com/MicroPhase/antsdr_uhd/releases/tag/v1.0) apply to those boards, not this original E310 target.

UHD/DSP and related platform code: Ettus Research; ANTSDR integration: MicroPhase; original E310 HDL and pinout: `antsdr_standalone` / MicroPhase HDL. The E310 port in this fork is maintained by **[Yijie Yu (uceeyuf)](https://github.com/uceeyuf)**. Existing upstream copyright and license notices are retained.

## Citation

To cite this fork's E310 port:

```bibtex
@misc{yu2026antsdr_e310_uhd,
    author = {Yijie Yu},
    title = {{UHD on the Original ANTSDR E310 Micro-USB}},
    year = {2026},
    howpublished = {\url{https://github.com/uceeyuf/antsdr_uhd}},
    note = {Experimental E310 port, e310-vivado-2020.2 branch},
}
```

GitHub's **Cite this repository** uses [CITATION.cff](CITATION.cff). Credit the upstream projects separately when using their work.

## License

The repository includes the [GNU GPL v3](LICENSE). Individual files and bundled projects retain their own license notices, including LGPL and the srsRAN test's AGPL notice; this port does not relicense upstream code.

---

<span id="cn">老款 ANTSDR E310 Micro-USB 的 UHD 移植</span>
===========================

本仓库 fork 自 [MicroPhase/antsdr_uhd](https://github.com/MicroPhase/antsdr_uhd)，包含基于 Ettus Research UHD 的主机驱动和 ANTSDR 固件。本分支使用 **Vivado 2020.2**，结合 `antsdr_standalone` 的板级设计，为 **Micro-USB 老款 ANTSDR E310（Zynq-7020 + AD9361）** 增加实验性支持。ANTSDR E310V2 和 Ettus USRP E310 是其他硬件目标。

实板结果：**7.68 MS/s 双向 AD9361 数字回环运行 5 秒，接收 3840 万样本，检查 2,398,400 个 QPSK 比特，零误码，RX/TX 传输错误和时间戳断点均为零。** **srsRAN 4G RF API** 经 UHD 插件的 1.92 MS/s 数字回环也已通过。**15.36 MS/s 仍有欠载／溢出；完整 LTE 小区、手机入网和外部射频回环尚未验证。**

## 技术特点

* 独立的 [E310 FPGA 工程](firmware/fpga/antsdr_e310/README.md#cn)：LVDS 接口、standalone 板级约束、UHD/B200 DSP、时间戳、AXI DMA 和 DDR TX FIFO。
* 以太网通路：**主机 ↔ PS GEM0 ↔ Linux bridge ↔ nixge AXI DMA ↔ FPGA UHD core ↔ AD9361 LVDS**。样本不经过用户态 UDP 转发。
* 老板卡专用 UHD 配置：单接收单发射、内部参考时钟、板级射频端口选择与 I/Q 映射；E200、E310V2 沿用各自配置。
* 修复 RX 半字对齐、TX 反馈时钟、初始化后的 LVDS 复位；提供 FPGA 和 AD9361 CODEC 数字回环诊断。
* PS GEM 中断分配给 CPU0，PL DMA 分配给 CPU1，消除了实测 7.68 MS/s 双向传输时的 CPU0 软中断瓶颈。
* 测量使用 JTAG RAM 启动，没有写入 SD／Flash；完整启动镜像构建仍待集成。

## 性能测试结果

2026-09-30 实板测试，`sc16` 传输、30.72 MHz 主时钟、每方向一个通道。CODEC 回环保留 TX 数字通路，同时关闭 TX DAC／上变频器并使用最大 TX 衰减。

| CODEC 双向采样率 | 时长 | RX 样本数 | 检查的 QPSK 比特 | 比特错误 | 判决 EVM |
| :-- | --: | --: | --: | --: | --: |
| 1.92 MS/s | 1 秒 | 1,920,000 | 118,400 | 0 | 0.356% |
| 3.84 MS/s | 1 秒 | 3,840,000 | 238,400 | 0 | 0.358% |
| **7.68 MS/s** | **5 秒** | **38,400,000** | **2,398,400** | **0** | **0.355%** |

以上三次测试的 RX 错误、TX 异步错误和时间戳断点均为 0。QPSK 每符号 32 样本，只确定一次固定对齐；这不等价于对所有 12 位原始样本逐位比较，也不代表已完成长时稳定性验证。

srsRAN RF API：1.92 MS/s 下 TX 2,304,000／RX 1,920,000 样本，RF 错误与时间戳断点为 0，+30 kHz 单音相干功率占比 0.999986498、镜像抑制 108.479 dB。插件使用 `uhd_unknown` 的 Generic 路径；验证范围是 RF 抽象层与 UHD 插件，尚未运行完整 LTE 协议栈。

## 构建与运行

```sh
git clone --branch e310-vivado-2020.2 https://github.com/uceeyuf/antsdr_uhd.git
cd antsdr_uhd
firmware/fpga/antsdr_e310/build.sh project
firmware/fpga/antsdr_e310/build.sh rebuild
```

默认 Vivado 路径为 `/tools/Xilinx/Vivado/2020.2/bin/vivado`，可用 `VIVADO` 覆盖。按 [host/README.md](host/README.md) 构建配套主机驱动。板端已运行匹配的 FPGA／Linux、PL 端点为 `192.168.10.3` 时：

```sh
antsdr_e310_digital_loopback 192.168.10.3 5 1 /tmp/e310-qpsk.fc32 codec 7680000 qpsk
```

约束、接口修复、构建范围与测试方法见 [E310 移植说明](firmware/fpga/antsdr_e310/README.md#cn)；独立 srsRAN RF 测试见 [tests/srsran](firmware/fpga/antsdr_e310/tests/srsran/README.md#cn)。

本次提交为源码检查点，尚不是完整 SD 卡发行版。生成的 bit／XSA、rootfs、JTAG 启动包和原始 IQ 不放入 Git。完整外部 I/O 时序与 CDC 审查、射频测试、更高采样率和其他主时钟组合仍待验证。

## 原有目标与来源

`firmware/` 和 `host/` 保留上游 E200／E310V2 代码。[上游快速开始](https://github.com/MicroPhase/antsdr_uhd#quick-start-guide) 和[已发布 SD 镜像](https://github.com/MicroPhase/antsdr_uhd/releases/tag/v1.0) 适用于那些板卡，不能直接用于本次老 E310 移植。

UHD／DSP 与相关平台代码来自 Ettus Research，ANTSDR 适配来自 MicroPhase，老 E310 HDL 与引脚参考 `antsdr_standalone`／MicroPhase HDL。本 fork 的 E310 移植由 **[Yijie Yu（uceeyuf）](https://github.com/uceeyuf)** 维护，保留上游版权及许可证声明。

## 引用

引用本 fork 的 E310 移植：

```bibtex
@misc{yu2026antsdr_e310_uhd,
    author = {Yijie Yu},
    title = {{UHD on the Original ANTSDR E310 Micro-USB}},
    year = {2026},
    howpublished = {\url{https://github.com/uceeyuf/antsdr_uhd}},
    note = {Experimental E310 port, e310-vivado-2020.2 branch},
}
```

GitHub 的 **Cite this repository** 使用 [CITATION.cff](CITATION.cff)。使用上游工作时，请另外注明相应项目。

## 许可证

仓库包含 [GNU GPL v3](LICENSE)。各文件及所含项目保留各自许可证声明，包括 LGPL 和 srsRAN 测试的 AGPL 声明；本移植不改变上游代码的许可。
