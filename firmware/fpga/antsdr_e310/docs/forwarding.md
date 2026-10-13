[English](#en) | [中文](#cn)

<span id="en"></span>

# Bridge forwarding optimization — 2026-10-13

**15.36 MS/s `sc16` now streams in both directions.** Before this work, RX-only lost 39% of samples with 92 overflows, and duplex had 106 overflows and 1,656 underruns in 5 seconds. After it, RX-only and TX-only are clean, three 15.36 MS/s `sc16` duplex QPSK checks pass bit-exact, and a 120-second duplex benchmark received 1.85 × 10⁹ samples with no overflow or underflow and 2 lost TX packets. The FPGA is unchanged. All tests use the CODEC digital loopback (`e310_codec_loopback=1`), one channel and a 30.72 MHz master clock; they are not RF or long-term qualification.

## Results (15.36 MS/s `sc16` unless stated)

| Test | Before | After |
| :-- | :-- | :-- |
| RX only, 5 s / 10 s | 47.1 M of 76.8 M samples, 92 overflows | 154.4 M samples, 0 overflows, 0 drops |
| TX only, 5 s / 10 s | 1 underrun | 157.7 M samples, 0 underruns, 0 sequence errors |
| Duplex, 5 s / 120 s | 106 overflows, 1,656 underruns, 1 sequence error | 0 overflows, 0 underruns, 2 sequence errors |
| Duplex QPSK, 3 s | not run (benchmark failing) | 3 of 3 PASS, 2,878,400 bits each, 0 errors |
| 7.68 MS/s `sc16` duplex, 60 s | — | 0 errors of any kind |
| 15.36 MS/s `sc8` duplex, 60 s | — | 0 errors of any kind |

QPSK checks at 1.92 and 7.68 MS/s `sc16` and 15.36 MS/s `sc8` also pass. Logs: [results/forwarding](results/forwarding).

## What limited throughput

A tick profile (`CONFIG_PROFILING`, `profile=2`) of RX-only streaming showed most CPU time outside the bridge itself ([profile](results/forwarding/profile-rx-before.txt)):

1. **`e310_discovery` saw every frame.** It opened an `ETH_P_ALL` packet socket on `eth0`, so each sample frame in both directions was cloned, copied to user space and woke the process (`finish_task_switch`, `packet_rcv`, `copy_to_user`; about 30% of samples). It now attaches a classic BPF filter for unfragmented IPv4 UDP to port 49100 and sets `PACKET_IGNORE_OUTGOING`. `reply()` still validates every field.
2. **macb computed every FCS in software.** With TX checksum offload enabled, Linux 5.2 `macb_pad_and_fcs()` runs `crc32_le` over every frame that is not `CHECKSUM_PARTIAL`, which is every forwarded frame (16.6%). The bridge never uses that offload, because nixge has none. `bridge-bringup.sh` now turns it off with `e310_netdiag txcsum eth0 off`.
3. **The PL310 L2 cache was disabled.** The kernel had `CONFIG_CACHE_L2X0` off, so the A9 cores ran with only 32 KiB L1 caches. Enabling it, with the PL310 and Cortex-A9 errata Zynq needs, raised RX-only from 47.1 M to 56.0 M samples on its own.
4. **Cache maintenance.** Neither DMA master is coherent. Each forwarded frame was invalidated twice on receive and cleaned on transmit, line by line in L1 and PL310 (about 60% of the remaining profile).

## Changes

**Board kernel** (not in this tree's kernel config; applied to `work/jtag-linux/kernel-build/.config`): `CACHE_L2X0`, `PL310_ERRATA_588369/727915/753970/769419`, `ARM_ERRATA_754322/764369/775420`, `PROFILING` (sampling stays off without `profile=`), and `MODULES`, `BPF_SYSCALL`, `BPF_JIT`, `BPF_JIT_ALWAYS_ON` so the discovery filter is compiled; this kernel has no sysctl to turn the JIT on.

**Forwarding fast path** (`include/net/e310_fastpath.h`, nixge, macb). Forwarding only needs headers. A receive driver that sees a frame the bridge will forward syncs just the first 128 bytes for the CPU and marks the skb. The transmitting driver maps a marked, linear skb without cleaning: the device reads the DMA-written bytes from DDR, and any cached payload lines are clean and never read. nixge now passes the DMA buffer on instead of copying it, refilling the descriptor with a new 1536-byte buffer. Frames for a local MAC address are still copied and fully synced. The fast path is opt-in from the device tree:

```dts
&gem0   { microphase,fastpath-dest-mac = [02 00 e3 10 55 32]; };  /* FPGA_MAC */
nixge0: ethernet@40000000 { microphase,bridge-fastpath; };
```

nixge decides "local" at run time from the bridge's and its ports' MAC addresses. macb skips cleaning only when TX checksum offload is off, because `macb_pad_and_fcs()` writes into the frame otherwise. Caveat: a packet capture on the board shows valid headers but stale payload for fast-path frames.

**PS GEM DMA limit.** Once the CPU was fast enough, duplex lost TX packets as GEM `rx_overruns`, one for one with FPGA sequence errors. The GEM's single DMA master cannot write line-rate receive bursts while it also reads a line-rate transmit burst. Measured: TX-only bursts are fine; 15.36 MS/s `sc8` RX with `sc16` TX is fine; `sc16` both ways overruns. Two changes fix it:

* `bridge-bringup.sh` sets PL DMA RX interrupt coalescing to 1 (`e310_netdiag coalesce eth1 1 24`). With 24, each batch left the GEM as a 24-frame line-rate burst. At 15.36 MS/s `sc16` duplex, coalescing 4 gave 1,023 overruns in 10 s and coalescing 1 gave 7.
* The host UHD paces E310 TX packets at 1.25× the sample rate, without catch-up bursts. The GEM receive packet buffer holds fewer than three frames. Pacing busy-waits, so it applies only from 20 MB/s. Without it, 7.68 MS/s `sc16` and 15.36 MS/s `sc8` duplex lost 3 and 1 packets in 60 s; with it, 0. Stream argument `e310_tx_pace=<factor>` changes the factor (1.05–100) or forces pacing at any rate; `e310_tx_pace=0` disables it.

## Tried without benefit

* DDR controller priority for the central-interconnect port: no change. **Do not set bit 19 (HPR) of `0xF800621C`**; that hung the board until a JTAG reboot.
* A smaller TX flow-control window (64 or 32 packets): overruns reduced but not removed.
* Limiting queued GEM TX descriptors to 1 or 2: no overruns, but RX then dropped samples.
* GEM IPG stretch (`NCFGR[28]`, `0xE000B0BC`): within noise once coalescing and pacing were in place; it would also cap board-to-host throughput. Note: register value `0x0001` (ratio 1) already limits TX to about 50% of line rate.

## Remaining work

The 120-second 15.36 MS/s `sc16` duplex run still lost 2 TX packets; any lost TX packet shifts the remainder of a transmitted burst. Both CPUs run at about 75–80% in this mode, and extra board activity (a once-per-second monitor) increases overruns. RF, other master clocks, and runs longer than two minutes are untested.

---

<span id="cn"></span>

# Bridge 转发优化 — 2026-10-13

**15.36 MS/s `sc16` 现已可双向连续传输。** 优化前，仅收丢失 39% 样本、溢出 92 次；双向 5 秒内溢出 106 次、欠载 1,656 次。优化后，仅收和仅发均无错误；三次 15.36 MS/s `sc16` 双向 QPSK 检查逐比特通过；120 秒双向基准接收 18.5 亿样本，无溢出、无欠载，丢失 2 个 TX 包。FPGA 未改动。测试均使用 CODEC 数字回环（`e310_codec_loopback=1`）、单通道、30.72 MHz 主时钟，不代表射频或长期稳定性结论。

## 结果（如无说明为 15.36 MS/s `sc16`）

| 测试 | 优化前 | 优化后 |
| :-- | :-- | :-- |
| 仅收，5 秒／10 秒 | 76.8M 中收到 47.1M，溢出 92 次 | 收到 154.4M，溢出 0、丢失 0 |
| 仅发，5 秒／10 秒 | 欠载 1 次 | 发送 157.7M，欠载 0、序号错误 0 |
| 双向，5 秒／120 秒 | 溢出 106、欠载 1,656、序号错误 1 | 溢出 0、欠载 0、序号错误 2 |
| 双向 QPSK，3 秒 | 未运行（基准已失败） | 3 次均 PASS，每次 2,878,400 比特、0 误码 |
| 7.68 MS/s `sc16` 双向，60 秒 | — | 各类错误均为 0 |
| 15.36 MS/s `sc8` 双向，60 秒 | — | 各类错误均为 0 |

1.92、7.68 MS/s `sc16` 与 15.36 MS/s `sc8` 的 QPSK 检查也均通过。日志见 [results/forwarding](results/forwarding)。

## 瓶颈所在

对仅收传输做时钟中断采样（`CONFIG_PROFILING`，`profile=2`），大部分 CPU 时间不在 bridge 本身（[采样结果](results/forwarding/profile-rx-before.txt)）：

1. **`e310_discovery` 收到每一帧。** 它在 `eth0` 上打开 `ETH_P_ALL` 原始套接字，两个方向的每个采样帧都被克隆、复制到用户态并唤醒进程（`finish_task_switch`、`packet_rcv`、`copy_to_user`，约 30%）。现在挂载经典 BPF 过滤器，只接收未分片的 IPv4 UDP 49100，并设置 `PACKET_IGNORE_OUTGOING`；`reply()` 仍校验全部字段。
2. **macb 用软件计算每帧 FCS。** 开启 TX 校验和卸载时，Linux 5.2 的 `macb_pad_and_fcs()` 对所有非 `CHECKSUM_PARTIAL` 帧（即所有转发帧）执行 `crc32_le`（16.6%）。由于 nixge 不支持该卸载，bridge 从不使用它。`bridge-bringup.sh` 现用 `e310_netdiag txcsum eth0 off` 关闭。
3. **PL310 L2 缓存未启用。** 内核关闭了 `CONFIG_CACHE_L2X0`，A9 只有 32 KiB L1。启用 L2 及 Zynq 所需的 PL310／Cortex-A9 勘误后，仅这一项就让仅收样本从 47.1M 增至 56.0M。
4. **缓存维护。** 两个 DMA 主设备都不一致。每个转发帧在接收时 invalidate 两次、发送时 clean 一次，逐行操作 L1 与 PL310（约占剩余采样的 60%）。

## 改动

**板端内核**（不在本仓库的内核配置中，已改 `work/jtag-linux/kernel-build/.config`）：`CACHE_L2X0`、`PL310_ERRATA_588369/727915/753970/769419`、`ARM_ERRATA_754322/764369/775420`、`PROFILING`（不加 `profile=` 时不采样），以及 `MODULES`、`BPF_SYSCALL`、`BPF_JIT`、`BPF_JIT_ALWAYS_ON`，使发现服务的过滤器被编译执行；本内核没有 sysctl 可开启 JIT。

**转发快路径**（`include/net/e310_fastpath.h`、nixge、macb）。转发只需要帧头。接收驱动识别出将被 bridge 转发的帧时，只为 CPU 同步前 128 字节，并标记 skb；发送驱动对已标记的线性 skb 映射时不做 clean：设备从 DDR 读取 DMA 写入的数据，缓存中的载荷行是干净的且不会被读取。nixge 现在直接传递 DMA 缓冲而不复制，并为描述符换上新的 1536 字节缓冲。发往本地 MAC 的帧仍复制并完整同步。快路径需在设备树中启用：

```dts
&gem0   { microphase,fastpath-dest-mac = [02 00 e3 10 55 32]; };  /* FPGA_MAC */
nixge0: ethernet@40000000 { microphase,bridge-fastpath; };
```

nixge 在运行时依据 bridge 及其端口的 MAC 判断是否为本地帧。只有在 TX 校验和卸载关闭时 macb 才跳过 clean，否则 `macb_pad_and_fcs()` 会写入帧。注意：在板上抓包时，快路径帧的帧头有效，但载荷是旧数据。

**PS GEM DMA 限制。** CPU 足够快之后，双向丢失的 TX 包表现为 GEM `rx_overruns`，与 FPGA 序号错误一一对应。GEM 只有一个 DMA 主设备，无法在读取线速发送突发的同时写入线速接收突发。实测：仅发的突发没有问题；15.36 MS/s RX `sc8` 加 TX `sc16` 没有问题；两个方向都为 `sc16` 时溢出。两项修改解决了它：

* `bridge-bringup.sh` 将 PL DMA RX 中断合并设为 1（`e310_netdiag coalesce eth1 1 24`）。设为 24 时，每批帧都以 24 帧线速突发离开 GEM。15.36 MS/s `sc16` 双向 10 秒内，合并 4 溢出 1,023 次，合并 1 为 7 次。
* 主机 UHD 以 1.25 倍采样率为 E310 的 TX 包定节拍，不做补发突发；GEM 接收包缓冲不足三帧。节拍采用忙等，因此只在 20 MB/s 及以上启用。未启用时，7.68 MS/s `sc16` 与 15.36 MS/s `sc8` 双向 60 秒分别丢 3 和 1 个包；启用后均为 0。流参数 `e310_tx_pace=<倍数>` 可修改倍数（1.05–100）或在任意速率强制启用；`e310_tx_pace=0` 关闭。

## 尝试过但无效

* 提高 DDR 控制器中央互连端口优先级：无变化。**不要设置 `0xF800621C` 的 bit 19（HPR）**，这会使板卡挂死，只能经 JTAG 重启。
* 更小的 TX 流控窗口（64 或 32 包）：溢出减少但未消除。
* 将 GEM TX 排队描述符限制为 1 或 2：不再溢出，但 RX 开始丢样本。
* GEM IPG stretch（`NCFGR[28]`、`0xE000B0BC`）：在中断合并与节拍生效后，差异在噪声范围内，且会限制板到主机的吞吐。注意：寄存器值 `0x0001`（比例 1）已将 TX 限制在约 50% 线速。

## 待完成

120 秒 15.36 MS/s `sc16` 双向仍丢失 2 个 TX 包；丢失任一 TX 包都会使该发送突发的后续部分错位。该模式下两个 CPU 约 75–80% 占用，额外的板端活动（每秒一次的监控）会增加溢出。射频、其他主时钟及超过两分钟的运行尚未测试。
