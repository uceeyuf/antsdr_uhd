[English](#en) | [中文](#cn)

<span id="en"></span>

# Linux network tuning — 2026-10-05

**The bridge does have a buffer-sizing problem on host-to-radio traffic.** Increasing GEM descriptors from RX/TX 512/512 to 2048/1024 made three five-second, 15.36 MS/s `sc16` TX-only benchmarks pass with zero underflows and sequence errors. It did not solve the RX or duplex throughput limit. These are transport benchmarks, not RF or long-duration qualification.

The board runs Linux 5.2.28, with PS GEM `eth0` bridged to PL AXI DMA `eth1`; it does not run lwIP. All tests used `e310_codec_loopback=1`, one channel, a 30.72 MHz master clock, and the existing IRQ split (GEM on CPU0, PL DMA on CPU1). The FPGA was unchanged.

## Measured comparisons

| Configuration | Test at 15.36 MS/s sc16 | Result |
| :-- | :-- | :-- |
| GEM RX/TX 512/512 | TX only, two repeated runs | 1 / 4 underflows; 11 / 11 TX sequence errors |
| GEM RX/TX 2048/1024 | TX only, three runs | Zero underflows and sequence errors in all three |
| GEM RX/TX 512/512 | RX only | 91 overflows; 45,910,247 received samples |
| GEM RX/TX 2048/1024 | RX only | 91 overflows; 45,701,315 received samples |
| GEM RX/TX 2048/1024 | Duplex | 104 RX overflows, 1,491 TX underflows, 1 TX sequence error |
| DMA RX interrupt coalescing 64 instead of 24 frames | RX only, default GEM rings | 93 overflows; no improvement |
| RPS: PL receive protocol processing moved to CPU0 | RX only | 80,632 CPU0 softnet backlog drops; UHD control timeout |

Default-ring TX repeats increased GEM `rx_resource_errors` by 452/638 and `rx_overruns` by 369/461. With larger rings, both counters stayed unchanged in all three TX-only runs. DMA errors and allocation failures stayed zero in the recorded comparisons. Ring expansion and coalescing changes did not improve sustained RX capacity. RPS was disabled again; DMA coalescing was restored to RX/TX 24/24.

The startup script now requests GEM RX/TX 2048/1024 **before opening the interfaces**. Failure is reported without blocking management-network bring-up. The packaged RAM image includes this setup; changing ring sizes on a running interface resets its link, so this is not done during a stream.

## A statistics-register bug found and fixed

Reading `ethtool` statistics for the PL interface caused an ARM external-abort Oops at `nixge_ethtools_get_stats`: this FPGA target has no PL Ethernet MAC counter bank, but the inherited driver tried to read it. The old E310 board now exposes only `dma_rx_errors`, `dma_tx_errors` and `rx_alloc_fail`; the original counter set remains unchanged for other boards. The new kernel passed 20 consecutive statistics reads without an Oops. This fixes the diagnostic crash; it is not claimed as the cause of the earlier streaming limit.

## Driver observations and remaining work

* GEM RX/TX rings were 512/512; PL DMA TX/RX rings are 64/512, with 2 KiB RX buffers. MTU remains 1500.
* Both drivers already use RX NAPI, with a poll weight of 64. GEM TX completion runs in its hard-IRQ handler under `bp->lock`; the transmit path takes the same lock and performs DMA mapping. This is a candidate for further profiling, not a measured per-function attribution.
* This minimal kernel has `CONFIG_PROC_SYSCTL` disabled. Its compiled network polling defaults are a budget of 300 and 2000 microseconds. There is no writable `/proc/sys/net/core` interface in this image. Those values were inspected, not tuned in these tests.
* Jumbo frames are not a supported shortcut in this build: the modified DMA driver caps MTU at 1500 with its 2 KiB buffers.
* Larger buffers help TX bursts but do not remove sustained RX processing overhead. Further RX work requires profiling and driver-level changes; simply increasing UDP socket buffers would not address this bridge path.

The final reboot applied 2048/1024 rings automatically. Two-second QPSK regressions passed at 7.68 MS/s `sc16` (958,400 checked bits) and 15.36 MS/s `sc8` (1,918,400 checked bits), with zero bit/transport errors and timestamp gaps.

## Diagnostic helper

Build `firmware/buildroot/board/e310/e310_netdiag.c` with the same ARM Linux toolchain as the rootfs and install the executable as `/sbin/e310_netdiag`, alongside the discovery/endpoint programs and bridge scripts. It uses standard ethtool ioctls, avoiding a full ethtool dependency in the small rootfs.

```sh
# Use the matching, fixed kernel before querying PL statistics.
e310_netdiag rings eth0
e310_netdiag coalesce eth1
e310_netdiag stats eth0
e310_netdiag stats eth1
```

`rings INTERFACE RX TX` changes descriptor counts; `coalesce INTERFACE RX TX` changes frame thresholds and requires the DMA interface down. The helper does not run streaming tests. Curated benchmark output and counter snapshots are in [results/network-tuning](results/network-tuning). Diagnostic inputs were temporary; the only retained tuning is the larger GEM rings and the prior IRQ split.

---

<span id="cn"></span>

# Linux 网络参数检查 — 2026-10-05

**主机到板卡的方向确实受缓冲配置影响。** GEM 的 RX/TX 描述符从 512/512 增至 2048/1024 后，三次 5 秒、15.36 MS/s 的 `sc16` 仅发基准测试均零欠载、零序号错误。但 RX 和双向吞吐限制尚未解决。这是传输基准测试，不是射频验收或长时稳定性结论。

板端运行 Linux 5.2.28，通过 bridge 连接 PS GEM `eth0` 与 PL AXI DMA `eth1`，没有运行 lwIP。测试均使用 `e310_codec_loopback=1`、单通道、30.72 MHz 主时钟和原有中断分核（GEM 在 CPU0、PL DMA 在 CPU1），FPGA 未改变。

## 实测对照

| 配置 | 15.36 MS/s sc16 测试 | 结果 |
| :-- | :-- | :-- |
| GEM RX/TX 512/512 | 仅发，重复两次 | 欠载 1／4 次；TX 序号错误 11／11 次 |
| GEM RX/TX 2048/1024 | 仅发，三次 | 三次均零欠载、零序号错误 |
| GEM RX/TX 512/512 | 仅收 | 溢出 91 次；收到 45,910,247 个样本 |
| GEM RX/TX 2048/1024 | 仅收 | 溢出 91 次；收到 45,701,315 个样本 |
| GEM RX/TX 2048/1024 | 双向 | RX 溢出 104、TX 欠载 1,491、TX 序号错误 1 |
| DMA RX 中断合并从 24 包改为 64 包 | 默认 GEM 环，仅收 | 溢出 93 次，没有改善 |
| RPS 将 PL 收包后的协议处理移到 CPU0 | 仅收 | CPU0 softnet 队列丢包 80,632，随后 UHD 控制超时 |

默认环的两次 TX 复测中，GEM `rx_resource_errors` 增加 452／638，`rx_overruns` 增加 369／461；扩大环的三次 TX 测试，两类错误均未增加。记录的对照中 DMA 错误、分配失败计数均为零。扩大环和调整中断合并没有改善持续 RX 能力。RPS 已恢复关闭，DMA 中断合并已恢复 RX/TX 24/24。

启动脚本现在在**打开接口之前**设置 GEM RX/TX 2048/1024；失败只报告警告，不阻断管理网口启动。交付 RAM 镜像已包含该设置。在运行中的接口上改环大小会重置链路，因此不在采样期间执行。

## 找到并修复的统计寄存器问题

读取 PL 接口的 ethtool 统计时，内核在 `nixge_ethtools_get_stats` 触发 ARM 外部访问异常：本 FPGA 没有 PL 以太网 MAC 计数器组，继承的驱动却尝试读取它。现在老 E310 只公开实际存在的 `dma_rx_errors`、`dma_tx_errors`、`rx_alloc_fail`，其他板卡保留原计数器集合。新内核连续读取 20 次统计正常，没有 Oops。这是诊断接口的修复，不将它认定为此前吞吐瓶颈的成因。

## 驱动检查与未解决项

* GEM 原收发环为 512/512；PL DMA 的 TX/RX 环为 64/512，RX 缓冲为 2 KiB，MTU 仍为 1500。
* 两个驱动已有 RX NAPI，poll weight 都是 64。GEM TX 完成处理仍在硬中断中、持有 `bp->lock`；发送路径获取同一锁并执行 DMA 映射。它值得进一步采样分析，目前尚未精确归因到函数开销。
* 精简内核关闭了 `CONFIG_PROC_SYSCTL`，编译时网络轮询默认预算为 300 包和 2000 微秒，没有可写的 `/proc/sys/net/core` 接口。本轮读取了这些默认值，没有调整它们。
* 当前 DMA 驱动为 2 KiB 缓冲并将 MTU 上限设为 1500，不能直接改 MTU 9000 来解决问题。
* 加大缓冲改善了 TX 突发，但不会消除持续 RX 的处理开销；后续应针对驱动做性能采样与优化，单纯增加 UDP socket 缓冲并不对应这条 bridge 数据通路。

最后重启已自动应用 2048/1024 环。2 秒 QPSK 回归在 7.68 MS/s `sc16`（检查 958,400 比特）和 15.36 MS/s `sc8`（检查 1,918,400 比特）均通过，零误码、零传输错误、零时间戳断点。

## 诊断工具

使用与 rootfs 相同的 ARM Linux 工具链编译 `firmware/buildroot/board/e310/e310_netdiag.c`，安装为 `/sbin/e310_netdiag`，与发现服务、端点程序和 bridge 脚本一起部署。工具通过标准 ethtool ioctl 工作，不需要在精简 rootfs 安装完整 ethtool。

查询命令见上方英文部分；查询 PL 统计前必须使用已修复的配套内核。`rings 网口 RX TX` 修改描述符数量；`coalesce 网口 RX TX` 修改中断合并包数，DMA 接口需先关闭。该工具本身不产生测试流量。

基准输出和计数快照见 [results/network-tuning](results/network-tuning)。本轮临时调参已恢复，只保留扩大 GEM 环和之前的中断分核。
