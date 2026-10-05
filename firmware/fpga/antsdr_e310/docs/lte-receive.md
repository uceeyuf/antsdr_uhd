[English](#en) | [中文](#cn)

<span id="en"></span>

# LTE reception and native I/Q correction

Original Micro-USB ANTSDR E310, 2026-10-05. This records two independent tests:
real LTE broadcast reception through E310/UHD, and a software-only srsUE/eNB/EPC
network over ZeroMQ. No programmable physical SIM was needed for either test.

## I/Q correction

The old board profile passed CODEC loopback but produced a mirrored receive
spectrum. Conjugating host samples allowed LTE synchronization. The corrected
profile clears AD9361 `PP_RX_SWAP_IQ` and sets `PP_TX_SWAP_IQ`: register `0x010`
is now `0x88` in 1R1T, previously `0x48` (`0x8c` in 2R2T). RX ordering is now a
board-profile option; other profiles retain their defaults. This is a UHD host
change and uses the existing E310 FPGA image.

A digital round trip can hide complementary TX/RX ordering errors. ADI also
[documents different I/Q behavior for BIST and normal operation](https://ez.analog.com/rf/wide-band-rf-transceivers/design-support/f/q-a/547687/ad9361-iq-swap-setting).
External LTE reception provides an independent check: corrected UHD detects
PCI 27 and confirms three matching MIBs **without software conjugation**.
The TX setting preserves CODEC loopback; RF transmit orientation remains untested.
Register and CODEC startup checks remain enabled.

| Native-I/Q regression | Duration | Checked QPSK bits | Bit errors | RX/TX errors / timestamp gaps |
| --- | ---: | ---: | ---: | ---: |
| 1.92 MS/s, `sc16` | 1 s | 118,400 | 0 | 0 |
| 7.68 MS/s, `sc16` | 2 s | 958,400 | 0 | 0 |
| 15.36 MS/s, `sc8` | 2 s | 1,918,400 | 0 | 0 |

These are AD9361 digital-port loopbacks with TX DAC/mixer power-down and
89.75 dB attenuation, not an external RF loopback. See the
[logs and summary](results/rf-iq-fix/).

## Broadcast reception

A rubber antenna on RX1 received **806 MHz, Band 20, EARFCN 6300, PCI 27,
50 PRB / 10 MHz, two cell antenna ports**, using one receive channel.
The cell search required three matching, valid MIB decodes. Initial candidates
and unrepeatable MIBs are not counted as confirmed cells.

The longer SI-RNTI (`0xffff`) receive test requested 20,000 subframes with
`sc8`, 15.36 MS/s, gain 35 dB and reference-signal CFO tracking. It detected
**1,000 PDSCH transport blocks: 646 CRC passes, 354 failures (35.4%)**.
This denominator includes detected transport blocks, not all transmitted data
or missed grants. This is partial broadcast decoding, not a stable LTE link or
proof that every SIB was parsed.

RF callbacks reported zero overflow, late and other errors, but stderr contained
one `bad vrt header or packet fragment` exception. Those callbacks do not count
every UHD parser error. The packet error and variable decoding quality remain
unresolved; neither an lwIP fault nor antenna limitations have been established
as their cause. The current data path is the Linux GEM/bridge/DMA path.

The upstream example resets its displayed BLER counters when the 10-bit SFN
wraps. Our patch adds separate cumulative counters; use `PDSCH_TOTAL`, not the
last screen's BLER, for a whole-run ratio. Printed RF-power labels are not
calibrated measurements. Short runs at different gains showed varying BLER;
no optimal gain or error-free reception is claimed.

## Reproduce

Use this fork's UHD and the matching E310 FPGA/Linux setup from the
[port instructions](../README.md). Set `UHD_SOURCE`, `UHD_BUILD`,
`SRSRAN_SOURCE` and `SRSRAN_BUILD` to absolute source/build directories.
The diagnostic patch targets srsRAN_4G commit
`bef8680d5f9714f3e040e6f9cbc88d7888439b6d` (25.10).
Apply it to a clean checkout at that revision:

```sh
git -C "$SRSRAN_SOURCE" apply --check \
  "$UHD_SOURCE/firmware/fpga/antsdr_e310/tests/srsran/rx-diagnostics.patch"
git -C "$SRSRAN_SOURCE" apply \
  "$UHD_SOURCE/firmware/fpga/antsdr_e310/tests/srsran/rx-diagnostics.patch"
cmake --build "$UHD_BUILD" --target uhd -j4
cmake -S "$SRSRAN_SOURCE" -B "$SRSRAN_BUILD" \
  -DCMAKE_BUILD_TYPE=Release -DENABLE_UHD=ON -DENABLE_RF_PLUGINS=ON \
  -DENABLE_GUI=OFF \
  -DUHD_INCLUDE_DIRS="$UHD_SOURCE/host/include;$UHD_BUILD/include" \
  -DUHD_LIBRARIES="$UHD_BUILD/lib/libuhd.so"
cmake --build "$SRSRAN_BUILD" --target cell_search pdsch_ue -j4
export LD_LIBRARY_PATH="$SRSRAN_BUILD/lib/src/phy/rf:$UHD_BUILD/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$SRSRAN_BUILD/lib/examples/cell_search" -d UHD \
  -a 'type=ant,addr=192.168.10.3,master_clock_rate=30.72e6,rx_only=1' \
  -b 20 -s 6300 -e 6301 -g 35 -n 100
"$SRSRAN_BUILD/lib/examples/pdsch_ue" -I UHD \
  -a 'type=ant,addr=192.168.10.3,master_clock_rate=30.72e6,rx_only=1,otw_format=sc8' \
  -f 806000000 -g 35 -Q -F -r 0xffff -n 20000
```

`rx_only=1` is provided by this patch: it avoids constructing the TX streamer
and TX async worker. `-Q` selects standard LTE rates (15.36 MS/s for 50 PRB)
instead of 11.52 MS/s; `-F` enables reference-signal frequency tracking.
`sc8` reduces Ethernet load. The optional `rx_conjugate=1` switch is retained
only for comparison with the old driver; **omit it with corrected UHD**.
The examples only receive broadcast signals and do not perform UE attachment.

## Separate software LTE test

With srsRAN's software Milenage USIM and a matching local subscriber entry,
srsUE attached to srsENB/EPC over ZeroMQ and received IP `172.16.0.2`.
Both ping directions delivered 10/10 packets (mean RTT 29.375 ms downlink,
28.862 ms uplink). E310 and RF were absent from this path. This demonstrates
protocol-stack experimentation without a physical programmable SIM; it does
not demonstrate phone attachment or an E310 base station. A subsequent PRACH
configuration adjustment was not part of that recorded passing run.

---

<span id="cn"></span>

# LTE 接收与原生 I/Q 修正

2026-10-05，Micro-USB 老款 ANTSDR E310。这里记录两项独立实验：
E310/UHD 实收 LTE 广播，以及通过 ZeroMQ 连接的软件 srsUE/eNB/EPC。
两者都不需要实体可编程 SIM。

## I/Q 修正

旧配置虽能通过 CODEC 回环，实际接收频谱却出现镜像，必须在主机对采样共轭才能同步 LTE。
修正后的板级配置清除 AD9361 的 `PP_RX_SWAP_IQ`、设置 `PP_TX_SWAP_IQ`：
1R1T 模式下 `0x010` 从 `0x48` 改为 `0x88`，2R2T 为 `0x8c`。
RX 顺序成为板级选项，其余配置保留默认值；重新构建 UHD 即可使用现有 FPGA 镜像。

数字往返链路可能掩盖互相抵消的 TX/RX 顺序错误，
[ADI 也说明了 BIST 与正常工作时的 I/Q 行为差异](https://ez.analog.com/rf/wide-band-rf-transceivers/design-support/f/q-a/547687/ad9361-iq-swap-setting)。
外部 LTE 信号提供独立证据：修正后**无需软件共轭**即可确认 PCI 27 的三次一致 MIB。
TX 配置保证数字回环通过，但射频发射方向仍未验证。寄存器与 CODEC 启动自检均保留。

上表的 1.92、7.68、15.36 MS/s 三档回归均为零检查比特错误、零传输错误和时间戳断点。
测试采用 AD9361 数字端口回环，关闭 TX DAC／混频器并设置 89.75 dB 衰减，
未使用外部射频回环。[日志与汇总](results/rf-iq-fix/)保留了本次结果。

## 广播接收

RX1 连接普通胶棒天线，确认 **806 MHz、Band 20、EARFCN 6300、PCI 27、
50 PRB／10 MHz、两发射端口**，本机使用一路接收。
搜索必须通过三次有效且一致的 MIB；初始候选和无法复现的 MIB 不计为确认小区。

较长的 SI-RNTI（`0xffff`）实验请求 20,000 个子帧，使用 `sc8`、15.36 MS/s、
35 dB 增益与参考信号频偏跟踪。累计检测到 **1,000 个 PDSCH 传输块，646 个 CRC 通过、
354 个失败，误块率 35.4%**。分母仅包含检测到的块，不包含全部实际发射的数据或漏检授权。
这是部分广播解码，尚不能称为稳定 LTE 链路，也未证明全部 SIB 已完成解析。

RF 回调的 overflow／late／other 均为零，但标准错误日志出现一次
`bad vrt header or packet fragment`；该类 UHD 解析错误不全部进入 RF 回调。
坏包与波动的解码质量仍待定位，目前不能归因于 lwIP 或天线。
当前数据链路使用 Linux GEM／bridge／DMA。

原示例会在 10 位 SFN 回卷时清零屏幕上的 BLER 计数，补丁另加了不清零的累计计数。
全程误块率应使用末尾 `PDSCH_TOTAL`，不能使用最后一屏 BLER。
软件输出的射频功率未经校准；不同增益短测的误块率有波动，尚未确定最佳增益。

## 复现

按英文部分命令设置绝对目录、向指定 srsRAN 提交应用补丁并构建。
`rx_only=1` 由补丁提供，避免创建 TX streamer 和 TX 异步线程。
`-Q` 选择标准 LTE 采样率（50 PRB 对应 15.36 MS/s），`-F` 开启参考信号频偏跟踪，
`sc8` 降低网口负载。`rx_conjugate=1` 仅留作旧驱动对照，**新驱动不要加此参数**。
这些示例只接收广播，不执行 UE 入网。

## 独立的软件 LTE 实验

使用软件 Milenage USIM 和本地匹配的用户记录，srsUE 经 ZeroMQ 成功接入 srsENB/EPC，
获得 `172.16.0.2`。双向 ping 均为 10 发 10 收，平均 RTT 分别为下行 29.375 ms、
上行 28.862 ms。该链路不经过 E310 或射频，证明无实体可编程 SIM 也能进行协议栈实验，
但不代表手机入网或 E310 基站已经完成。后续 PRACH 配置调整不属于该次已通过的测试。
