[English](#en) | [中文](#cn)

<span id="en"></span>

# E310 sc8 UDP tail alignment

An odd number of `sc8` samples gives a CHDR byte count that is two bytes short
of a 32-bit boundary. The UDP generator previously used that byte count as its
physical payload length. UHD's receive handler counts complete 32-bit words,
while its CHDR parser rounds the declared length up. A 962-byte datagram was
therefore compared as 960 received bytes against 964 required bytes and rejected.

This was reproduced during srsRAN stream stop/flush and with a finite CODEC
capture of **192,001 samples**. The old bitstream returned
`ERROR_CODE_BAD_PACKET`; the same host software and capture command serve as
the hardware regression. Other captured examples were 422, 590 and 1,034 bytes.
[Diagnostic excerpts and before/after tests](results/udp-padding/).

There is also a payload reason to fix the sender: `sc8_item32_le` stores the
first sample of each pair in the upper half of a 32-bit word. Trimming the last
word at two bytes removes that sample. Appending zeros at the host would silence
the length check but could not recover those sample bytes.

The old-E310 top now enables `PAD_CHDR_TO_32BIT`. The UDP generator rounds the
physical UDP payload length to four bytes and derives the IP length, checksum
and final valid-byte mask from that padded length. It leaves the CHDR length
and samples unchanged. Other FPGA targets retain their default behavior.
UHD's packet validation is unchanged; this fix requires a rebuilt FPGA image.

## Regression

With Icarus Verilog installed, run:

```sh
firmware/fpga/antsdr_e310/tests/run_udp_padding.sh
```

The test checks 1, 2, 3, 4, 5, 7, 11, 183, 287, 509 and 716 samples, every
sample's byte order including the tail, unchanged CHDR count, UDP/IP lengths,
IP checksum and downstream backpressure. It also verifies that disabling the
fix fails the regression. Rebuild the FPGA using the existing
[port scripts](../README.md); retain the existing pin and timing constraints.

To reproduce the finite CODEC case with the existing diagnostic executable:

```sh
antsdr_e310_digital_loopback 192.168.10.3 0.1000006 1 \
  /tmp/e310-odd.fc32 codec 1920000 qpsk sc8
```

This invokes the driver's RF-isolated digital loopback. No external RF loopback
or RF base-station transmission is involved.

## Hardware results after correction

Vivado 2020.2 synthesis, routing and DRC completed. Routed setup slack is
1.475 ns and hold slack 0.029 ns, with no failing timing endpoints or DRC errors.
The image was loaded over JTAG with the existing Linux #8 kernel and GEM/DMA
IRQ affinity. No pin constraints were changed. Bitstream SHA256:
`bebd1663916409398a959308ee37360b1018de009e5b1473fc9d8355e2c554c8`.

| CODEC regression | RX sample count | Checked symbol bits | Bit errors |
| --- | ---: | ---: | ---: |
| 1.92 MS/s sc8, odd tail | 192,001 | 10,400 | 0 |
| 7.68 MS/s sc16 | 7,680,000 | 478,400 | 0 |
| 15.36 MS/s sc8, odd tail | 1,536,001 | 94,400 | 0 |

All three completed with zero RX errors, TX async errors and timestamp gaps.
The QPSK checker measures symbol-center decisions; the RTL regression separately
checks every sample byte including the final partial word. LTE cell search again
confirmed three matching MIBs for PCI 27 / 50 PRB at 806 MHz.

Three subsequent receive runs each requested 10,000 subframes at gain 35 dB,
15.36 MS/s, `sc8`, `-Q -F` and SI-RNTI `0xffff`, using the commands in
[LTE reception](lte-receive.md) with `-n 10000` and the estimator below:

| Order | Estimator (`-R`) | Detected blocks | CRC failures | Cumulative BLER |
| --- | --- | ---: | ---: | ---: |
| 1 | wiener | 500 | 8 | 1.6% |
| 2 | interpolate | 500 | 4 | 0.8% |
| 3 | wiener | 500 | 0 | 0.0% |

Each had zero RF error callbacks and no bad-VRT exception in the complete log.
The deterministic odd-tail regression establishes the packet fix. Sequential
LTE measurements do not prove that the fix caused the BLER change, nor does the
last run establish long-term error-free reception.

## Receive-quality distinction

The packet-length error and LTE PDSCH CRC failures are separate observations.
Before the FPGA change, two 3,000-subframe `sc16` runs at 15.36 MS/s reported
80 and 79 overflow callbacks. `sc8` avoids that payload-rate limitation in the
short clean runs; it does not guarantee error-free reception.

The same setup's subsequent 10,000-subframe `sc8` runs produced 8/499, 13/499
and 13/500 failed detected blocks (Wiener, interpolation, Wiener respectively).
Those runs still used the old FPGA and included tail-packet errors; two also
had one overflow callback. They demonstrate that the earlier 35.4% BLER is not
a fixed property of the I/Q mapping. Signal conditions and estimator behavior
remain relevant; sequential over-the-air runs do not establish causation.
`-R wiener` is an optional srsRAN comparison, not a proven universal optimum.

---

<span id="cn"></span>

# E310 sc8 UDP 尾部对齐

`sc8` 样本数为奇数时，CHDR 字节数距 32 位边界差 2 字节。
旧 UDP 封装直接使用这个长度，而 UHD 接收器向下取整、CHDR 解析器向上取整：
实际收到 962 字节，却按 960 字节与所需的 964 字节比较，因而报坏包。

问题已在 srsRAN 停流／清空缓冲时复现，也可用 **192,001 个样本**的有限 CODEC
回环确定性复现：旧位流返回 `ERROR_CODE_BAD_PACKET`。
另外抓到了 422、590、1,034 字节的同类包。
[诊断片段及修正前后测试](results/udp-padding/)。

必须修发包端还有一个原因：`sc8_item32_le` 每对样本中的第一个样本放在 32 位字的
高半部，按两字节裁掉尾部会删掉最后一个有效样本。主机补零不能恢复已经丢掉的数据。

老 E310 顶层现在启用 `PAD_CHDR_TO_32BIT`，UDP 封装将实际负载补齐至 4 字节，
并据此计算 IP 长度、校验和及末拍有效字节标志；CHDR 的真实样本长度保持不变。
其他 FPGA 目标默认行为不变，UHD 的坏包检查也保持不变。此修正需要重建 FPGA 位流。

## 回归方法

安装 Icarus Verilog 后执行上方脚本。测试覆盖 11 种长短包，逐个核对样本（包括最后一个）、
CHDR 计数、UDP／IP 长度、IP 校验和及背压，并确认禁用修正时测试失败。
使用现有[移植构建脚本](../README.md#cn)重建 FPGA，保留原有管脚和时序约束。
上方 CODEC 命令可复现 192,001 样本的尾包问题，测试由驱动隔离射频发射链路。

## 修正后的实机结果

Vivado 2020.2 综合、布线和 DRC 完成；建立裕量 1.475 ns、保持裕量 0.029 ns，
无失败时序端点和 DRC 错误。新位流通过 JTAG 加载，沿用 Linux #8 内核与 GEM／DMA
中断分配，未改变管脚约束；位流 SHA256 见英文部分。

1.92 MS/s 的 192,001 样本 `sc8` 回环、7.68 MS/s 的 7,680,000 样本 `sc16`
回环、15.36 MS/s 的 1,536,001 样本 `sc8` 回环全部通过：检查比特错误、RX 错误、
TX 异步错误和时间戳断点均为零。QPSK 检查器验证符号中心，RTL 回归另外逐字节验证
包括末尾在内的全部样本。LTE 搜索再次确认 PCI 27／50 PRB 的三次一致 MIB。

随后三次接收各请求 10,000 子帧，增益 35 dB、15.36 MS/s、`sc8`、`-Q -F`、
SI-RNTI `0xffff`。依次采用 Wiener、插值、Wiener，均检测到 500 个块，
CRC 失败分别为 8、4、0 个，对应 **1.6%、0.8%、0.0%**。三次均无 RF 错误回调，
完整日志也均未出现坏 VRT 包头错误。命令见 [LTE 接收](lte-receive.md#cn)，
将子帧数设为 `-n 10000`，用 `-R` 选择对应估计器。

确定性的奇数尾包回归证明了封装修复；依次进行的 LTE 实收不能证明 BLER 变化全由
此修复造成，最后一次零误块也不能证明长期稳定。

## 与接收质量的区别

包长错误和 LTE PDSCH CRC 失败是两项不同观察。
更换 FPGA 前，15.36 MS/s 的两次 `sc16` 接收分别报告 80 和 79 次溢出回调。
`sc8` 在短时无溢出的测试中避开了这档传输负载限制，但不保证射频解码零误块。

同一配置随后三次 10,000 子帧 `sc8` 实测分别为 8/499、13/499、13/500 个检测块失败，
信道估计依次使用 Wiener、插值、Wiener。它们仍使用旧 FPGA，仍有尾包错误，其中两次
还有一次溢出回调。因此先前 35.4% 不是 I/Q 映射导致的固定误块率；实际信号条件与
估计方法仍需考虑，依次进行的实收实验不能独立证明因果。`-R wiener` 可作对照，
尚不能认定为普遍最优设置。
