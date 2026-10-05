[English](#en) | [中文](#cn)

<span id="en"></span>

# Long receive tests and SIB1 decoding

The corrected E310 FPGA received **1,843,206,368 samples at 15.36 MS/s** in a
120,000-iteration LTE test with no observed timestamp discontinuities, RF error
callbacks or loss of subframe alignment. Eight initial search iterations preceded
119,992 aligned subframes. The stream remained continuous while **975 of 5,329
detected PDSCH blocks failed CRC (18.30%)**. Transport continuity and successful
radio decoding are distinct results.

The receive-only diagnostic now checks the timestamps supplied by the srsRAN RF
API, counts aligned/searching/error iterations and prints cumulative plus
10,000-iteration block counters. It includes samples read for timing alignment;
sample-count differences between runs are expected. Timestamp gaps are flagged
above 0.51 sample, and metadata errors and stderr are checked separately.
No FPGA or UHD source changes were made for these tests. The
[UDP-tail correction](udp-padding.md) remained loaded, with the Linux #8 kernel.

## What the comparisons establish

All instrumented runs in [the result set](results/long-rx/summary.json) had zero
timestamp gaps, RF error callbacks and sync-loss events. The pre-instrumentation
baseline has no timestamp-continuity measurement and is labeled separately.

| Comparison | Detected blocks / CRC failures | BLER |
| --- | ---: | ---: |
| 120,000 iterations, Wiener, reference CFO enabled | 5,329 / 975 | 18.30% |
| PSS CFO only, 60,000 iterations | 2,999 / 343 | 11.44% |
| Reference CFO enabled, 60,000 iterations | 2,970 / 1,249 | 42.05% |
| PSS CFO only, repeated | 2,993 / 615 | 20.55% |

Changing CFO tracking did not remove the variation. Gain tests at 35, 45, 55,
45 and 35 dB also varied. The 55 dB run had 5,118 near-full-scale I/Q components
in 322,560 sampled complex values, with a component peak of 1.000030. At 35 and
45 dB none of the sampled components reached the diagnostic 0.99 threshold.
These are uncalibrated host sample levels, not ADC-overload sensor readings or
absolute RF power. Only one receive callback per 1,000 was sampled for level
statistics; unsampled peaks are not excluded.

At gain 45 dB, requested RX filter bandwidths of 10, 56 and 10 MHz produced
9.75%, 1.47% and 23.80% BLER respectively. The 56 MHz request is the UHD default;
AD9361 filter calibration is constrained by its internal sample clock, so this
is a requested setting, not a measured analog passband. Narrowing the filter
did not establish a cure. These sequential over-the-air tests do not isolate
RF fading, interference or tracking effects; they establish neither an optimal
gain/filter nor a single cause of the remaining CRC failures.

## SIB1 is now decoded

The diagnostic can export the first 16 **CRC-passed SI-RNTI** blocks in a run.
A small helper uses the pinned srsRAN ASN.1 implementation to parse
BCCH-DL-SCH and require the SIB1 message type. Six real receive runs produced 96/96 parsed blocks with
identical SIB1 contents including PLMN identities, tracking area code, cell
identity, Band 20, cell access information and SI scheduling.

This verifies actual broadcast content, beyond PSS/SSS and MIB detection. It
requires no SIM and sends no UE attach or RF uplink. It does not verify SIB2,
phone attachment, an E310 eNB, or sustained error-free reception. Live cell
identifiers are kept in local JSON output; the public result files contain
measurement counters only.

## Reproduce

Apply the updated [srsRAN diagnostic patch](../tests/srsran/rx-diagnostics.patch)
and build the receiver and decoder using
[the test instructions](../tests/srsran/README.md). The patch still targets
`bef8680d5f9714f3e040e6f9cbc88d7888439b6d`. Replace an older patch in a clean
checkout rather than applying the new patch on top of it.

`run-lte-rx.sh` creates a separate local run directory containing the exact
receiver command, `receive.log`, exit status and decoded `sib1.json`.
Defaults are 806 MHz, gain 35 dB, `sc8`, 120,000 iterations, Wiener estimation
and PSS-only CFO tracking. These are reproducible starting settings, not an
optimal RF configuration. The bounded run exits on timeout or process failure;
SIB1 decode failure is also reported as failure. A successful script exit means
the receiver completed and exported blocks parsed as SIB1; inspect counters
separately for transport and decoding quality.

Available diagnostic controls:

| Setting | Meaning |
| --- | --- |
| `SRSRAN_RX_COMPACT=1` | Replace the 100 Hz terminal display with periodic cumulative metrics |
| `SRSRAN_DUMP_SI=1` | Export up to 16 CRC-passed SI-RNTI transport blocks |
| `RX_CFO_REF=1` | Have the runner add `-F`; default is PSS-only tracking |
| `RX_GAIN_DB`, `RX_ESTIMATOR` | Runner overrides for gain and channel estimator |
| `RX_BANDWIDTH_HZ` | Optional runner override for `rx_bandwidth_hz`; omitted by default |
| `RX_SUBFRAMES` | Positive receiver iteration limit, approximately milliseconds after acquisition |

The direct receiver prints `RX_CONTINUITY`, `SYNC_TOTAL`, `PDSCH_TOTAL`,
`RX_DIAGNOSTICS` and sampled `RX_LEVEL` counters. `RX_PROGRESS` provides
10,000-iteration windows; the old screen BLER still resets at SFN wrap.

---

<span id="cn"></span>

# 长时间接收与 SIB1 解析

修正后的 E310 位流在 120,000 次迭代的 LTE 测试中，以 15.36 MS/s 接收了
**1,843,206,368 个样本**，未发现时间戳断点、RF 错误回调或子帧失步。
初始搜索占 8 次迭代，随后有 119,992 个对齐子帧。
但检测到的 5,329 个 PDSCH 块中仍有 975 个 CRC 失败，**误块率 18.30%**。
传输连续和无线解码成功是两项不同结论。

接收诊断现已检查 RF API 时间戳，统计对齐、搜索、错误与失步，并每 10,000 次迭代
输出累计和分段误块计数。统计包含同步算法为调整时间而额外读取的样本，所以每次
样本总量可能不同；时间戳偏差超过 0.51 样本会记为断点，元数据错误及标准错误日志
另行核对。本轮没有修改 FPGA／UHD 行为，继续使用[尾包修正版](udp-padding.md#cn)
和 Linux #8 内核。

## 对照结果

[结果集](results/long-rx/summary.json)中带新诊断的各次测试均无时间戳断点、
RF 错误回调或失步。最早一轮基线尚未加入时间戳统计，不能据此声明其时间戳连续。

三次 60,000 次迭代的频偏对照，依次关闭参考信号跟踪、开启、再关闭，
误块率为 **11.44%、42.05%、20.55%**。改变这个开关没有消除波动。
增益按 35、45、55、45、35 dB 对照，也未获得稳定的零误块结果。
55 dB 时，抽查的 322,560 个复数样本中有 5,118 个 I/Q 分量达到 0.99 阈值，
峰值 1.000030；35、45 dB 抽查中没有达到该阈值的分量。
这些是未经校准的主机样本电平，不是 ADC 过载传感器或绝对射频功率。
每 1,000 次接收回调只抽查一次，不能排除未抽查区间的峰值。

45 dB 增益下，请求滤波带宽依次为 10、56、10 MHz，误块率为 9.75%、1.47%、23.80%。
56 MHz 是 UHD 默认请求值，实际 AD9361 滤波校准受内部采样时钟限制，不能理解为已测得
56 MHz 模拟通带。收窄带宽没有证明能解决问题。依次进行的空口实验无法独立排除
衰落、干扰或跟踪影响，因此目前没有确定最佳增益／带宽或剩余误块的单一原因。

## 已真正解析 SIB1

新诊断可导出每次运行前 16 个 **CRC 通过的 SI-RNTI 块**。辅助程序使用指定版本
srsRAN 的 ASN.1 解码器，解析 BCCH-DL-SCH 并确认消息为 SIB1。
六次实收共 96/96 个块成功解析为同一份 SIB1，包括 PLMN、TAC、小区标识、Band 20、
小区接入及 SI 调度信息。

这一步验证了实际广播内容，超过了同步信号和 MIB 检测；不需要 SIM，也不发送入网或
射频上行。尚未验证 SIB2、手机入网、E310 基站或长期零误块。真实小区标识保存在
本地 JSON，公开结果文件只保留测量计数。

## 复现

按[测试说明](../tests/srsran/README.md#cn)应用更新后的补丁并构建。
补丁仍对应 `bef8680d5f9714f3e040e6f9cbc88d7888439b6d`；已有旧补丁时应在干净的
该版本源码上应用新补丁，不能直接叠加。

`run-lte-rx.sh` 自动创建独立目录，保存完整命令、日志、退出状态和 `sib1.json`。
默认 806 MHz、35 dB、`sc8`、120,000 次迭代、Wiener 估计、仅 PSS 频偏跟踪，
这些是可复现的起点，不代表最佳射频设置。超时、接收进程失败或 SIB1 解析失败均返回失败。
脚本成功只表示运行完成且导出的广播块解析为 SIB1，传输与解码质量仍需分别查看计数。

可用 `RX_CFO_REF=1` 开启 `-F`，用 `RX_GAIN_DB`、`RX_ESTIMATOR`、
`RX_BANDWIDTH_HZ` 作对照，`RX_SUBFRAMES` 控制迭代上限。
`SRSRAN_RX_COMPACT=1` 输出简洁的周期统计，`SRSRAN_DUMP_SI=1` 导出最多 16 个
CRC 通过的 SI-RNTI 块。累计结果以 `RX_CONTINUITY`、`SYNC_TOTAL`、`PDSCH_TOTAL`、
`RX_DIAGNOSTICS` 为准；旧屏幕 BLER 仍会在 SFN 回卷时清零。
