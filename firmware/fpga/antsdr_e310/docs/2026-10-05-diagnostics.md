[English](#en) | [中文](#cn)

<span id="en"></span>

# E310 throughput diagnosis — 2026-10-05

The FPGA and JTAG Linux image are unchanged from the previous measurements. PS GEM is at 1000 Mbps full duplex, MTU 1500. IRQ affinity is GEM/CPU0 and PL DMA/CPU1. All streaming below uses isolated AD9361 CODEC digital loopback, a 30.72 MHz master clock and one channel. No external RF loopback was performed.

## Separate the two directions

Five-second `benchmark_rate` runs at 15.36 MS/s, `sc16`:

| Direction | RX samples | TX samples | RX overflows | TX underflows | TX sequence errors |
| :-- | --: | --: | --: | --: | --: |
| RX only | 45,457,851 | 0 | 92 | 0 | 0 |
| TX only | 0 | 81,057,340 | 0 | 3 | 18 |
| Duplex | 37,623,348 | 65,973,544 | 104 | 1,423 | 4 |

Benchmark stream duration includes its startup/stop behavior; sample counts are reported as observed, not used to assert an exact five-second sample total. In the duplex run both CPUs were about 95–97% busy. In the RX-only run CPU1 spent about 88–90% in softirq and GEM generated 132,442 interrupts across the recorded interval (130,312 transmitted Ethernet packets). Host UDP `RcvbufErrors` and `InErrors` did not increase.

TX-only increased GEM RX errors by 1,018; duplex increased them by 337. Subsequent counter readback identified FIFO overruns and buffer-resource errors, with zero CRC/frame errors. Moving all IRQs to CPU1 made RX worse; exchanging CPU0/CPU1 did not materially improve it. The original affinity was restored.

These measurements implicate the PS Ethernet/Linux bridge processing path and burst buffering. They do not fully attribute every CPU cycle or establish a single remaining bottleneck.

## Optional TX flow-control window

An E310-only streamer argument now permits a smaller window, without changing the default:

```sh
benchmark_rate --args='type=ant,addr=192.168.10.3,master_clock_rate=30.72e6,e310_codec_loopback=1' \
  --duration=5 --tx_rate=15360000 --tx_stream_args='e310_tx_fc_window=256' \
  --underrun-threshold=0 --seq-threshold=0
```

Range: 32 through the existing hardware-buffer-derived limit (686 packets with the tested frame size). The lower bound stays above the 30-packet credit-update interval. Other board models reject this argument. The default remains the existing approximately 1 MB window.

| Requested window | GEM RX error increase | TX underflows | TX sequence errors |
| --: | --: | --: | --: |
| 64 | 0 | 2,164 | 0 |
| 128 | 0 | 215 | 3 |
| 256 | 0 | 3 | 0 |

Smaller windows removed the observed GEM receive errors in these runs, but did not produce an error-free TX test. A very small window starves TX while waiting for credits. This is a diagnostic control, not a new recommended default or a claim that 15.36 MS/s `sc16` works. An invalid value of 31 was rejected on the board.

## Lower wire precision as a controlled comparison

Keeping 15.36 MS/s but using `sc8` reduced the wire payload from four to two bytes per complex sample. A five-second RX-only benchmark received 77,555,196 samples with zero drops, overflows, sequence errors or timeouts.

The digital QPSK checker now accepts an optional last argument `sc16|sc8`; its default is still `sc16`, and the saved capture remains `fc32`:

```sh
antsdr_e310_digital_loopback 192.168.10.3 2 1 /tmp/e310-sc8.fc32 codec 15360000 qpsk sc8
```

The two-second duplex run received 30,720,000 samples and checked 1,918,400 QPSK bits with zero errors. RX errors, TX asynchronous errors and timestamp gaps were all zero. The decision-point normalized EVM was zero for these quantized QPSK plateaus after the test's fitted scalar gain; this is not a broadband EVM or RF-quality measurement.

A repeat at three seconds received 46,080,000 samples and checked 2,878,400 bits, again with zero bit/transport errors or timestamp gaps. The final default-format regression at 7.68 MS/s also passed.

This confirms that the digital path can carry valid data at 15.36 MS/s under reduced network load. It does not fix full-precision `sc16`, establish analog performance, or validate an LTE cell. The existing 7.68 MS/s `sc16` QPSK baseline also passed a fresh two-second run (15,360,000 received samples, 958,400 checked bits, zero errors).

Selected raw test outputs: [results/2026-10-05](results/2026-10-05).

---

<span id="cn"></span>

# E310 吞吐定位 — 2026-10-05

FPGA 和 JTAG Linux 镜像与之前测量相同。PS GEM 已是千兆全双工、MTU 1500；GEM 中断在 CPU0，PL DMA 在 CPU1。以下使用隔离射频发送路径的 AD9361 CODEC 数字回环、30.72 MHz 主时钟、单通道，没有进行外部射频回环。

## 分方向测试

15.36 MS/s、`sc16`、5 秒 `benchmark_rate`：

| 方向 | RX 样本数 | TX 样本数 | RX 溢出 | TX 欠载 | TX 序号错误 |
| :-- | --: | --: | --: | --: | --: |
| 仅收 | 45,457,851 | 0 | 92 | 0 | 0 |
| 仅发 | 0 | 81,057,340 | 0 | 3 | 18 |
| 双向 | 37,623,348 | 65,973,544 | 104 | 1,423 | 4 |

基准程序有自身的启停行为，表中样本数为实际报告值，不用它宣称精确的 5 秒样本总量。双向时两个 CPU 忙碌率约 95–97%；仅收时 CPU1 软中断占比约 88–90%，记录期间 GEM 产生 132,442 次中断、发送 130,312 个以太网包。主机 UDP `RcvbufErrors` 和 `InErrors` 没有增加。

仅发时 GEM 接收错误增加 1,018，双向增加 337；后续计数回读确认存在 FIFO 溢出和缓冲资源错误，CRC／帧错误为零。全部中断放 CPU1 后 RX 更差，交换 CPU0／CPU1 也没有明显改善，测试后已恢复原分核。

证据指向 PS 以太网／Linux bridge 的处理负载和突发缓冲问题，但尚未精确分解所有 CPU 开销，也不表示已找出唯一瓶颈。

## 可选 TX 流控窗口

新增仅用于老 E310 的 streamer 参数 `e310_tx_fc_window`，运行命令见上方英文部分。有效范围从 32 到原有按硬件缓冲计算的上限（本次帧大小下为 686 包）；下限高于每 30 包一次的 credit 更新间隔。其他型号会拒绝这个参数。默认值仍为原来约 1 MB 的窗口。

| 请求窗口 | GEM RX 错误增量 | TX 欠载 | TX 序号错误 |
| --: | --: | --: | --: |
| 64 | 0 | 2,164 | 0 |
| 128 | 0 | 215 | 3 |
| 256 | 0 | 3 | 0 |

缩小窗口后，这几次测试的 GEM 接收错误降为零，但 TX 仍未全部通过。窗口过小会因等待 credit 导致大量欠载。因此只提供诊断选项，不更改默认值，也不宣称 15.36 MS/s `sc16` 已可用。实板确认非法值 31 会被拒绝。

## 降低传输位宽的对照

保持 15.36 MS/s，使用 `sc8` 将每复数样本的网络负载从 4 字节降到 2 字节。5 秒仅收测试收到 77,555,196 个样本，丢样、溢出、序号错误和超时均为零。

QPSK 数字回环检查器新增最后一个可选参数 `sc16|sc8`，默认仍为 `sc16`，捕获文件仍为 `fc32`：

```sh
antsdr_e310_digital_loopback 192.168.10.3 2 1 /tmp/e310-sc8.fc32 codec 15360000 qpsk sc8
```

2 秒双向实测接收 30,720,000 样本，检查 1,918,400 个 QPSK 比特，零误码，RX 错误、TX 异步错误及时间戳断点均为零。判决点归一化 EVM 为零，来自这些量化后的 QPSK 平台值及测试拟合的标量增益，不代表宽带 EVM 或射频质量。

重复运行 3 秒接收 46,080,000 个样本、检查 2,878,400 个比特，再次零误码、零传输错误、零时间戳断点。最后使用默认格式复测 7.68 MS/s 也通过。

这验证了减小网络负载时 15.36 MS/s 数字通路可以传输正确数据；它没有修复完整位宽的 `sc16`，也没有验证模拟射频性能或 LTE 小区。原有 7.68 MS/s `sc16` QPSK 基线重新运行 2 秒亦通过：15,360,000 个接收样本、958,400 个检查比特，零错误。

部分原始测试输出见 [results/2026-10-05](results/2026-10-05)。
