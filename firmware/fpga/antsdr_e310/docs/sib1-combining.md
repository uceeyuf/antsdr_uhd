[English](#en) | [中文](#cn)

<span id="en"></span>

# SIB1 replay and soft combining

On 2026-10-05, two live receive-only tests completed **2,248 full SIB1 periods**.
Independent decoding missed every transmission in **153 periods**; adding soft
combining reduced that to **2 periods**. The raw CRC failures remain visible.
This is an improvement to the diagnostic receiver's broadcast acquisition, not
a correction to the antenna, FPGA, UHD or Ethernet transport.

## Fixed-input diagnosis

Earlier [sequential RF comparisons](long-rx.md) could not separate decoder
settings from changing reception conditions. The receiver can now capture the
synchronized, CFO-corrected samples immediately before SIB1 decoding, together
with TTI, cell configuration and the original decode result. The new
`e310_replay_sib1` target decodes those same samples without the radio.

Two 1,000-occasion captures reproduced the live result **exactly, record by
record**, using Wiener estimation:

| Capture | Independent CRC failures | Fresh CRC failures after combining | Original failures recovered |
| --- | ---: | ---: | ---: |
| Gain 35 dB | 200 / 1,000 | 2 / 1,000 | 198 |
| Gain 45 dB | 486 / 1,000 | 6 / 1,000 | 481 |

The two columns use different evidence: independent decodes use one transmission;
combined decodes accumulate repetitions within the same period. The latter is
not an independent-transmission BLER. A combined failure also does not erase an
independent success; group delivery uses either CRC-passed result.

On the first capture, ordinary interpolation failed 332 of 999 detected blocks;
average estimation failed 194 of 957, with 43 missed grants. Disabling timing
correction, increasing turbo iterations to 16, enabling CSI weighting, and
residual-CFO corrections did not match the combining improvement. The original
200 failures were distributed by redundancy version as RV0: 2, RV1: 65,
RV2: 0, RV3: 133 (250 attempts each). This establishes a repetition-dependent
pattern in this capture, not a universal RF root cause.

## What changed

The pinned upstream `srsran_ue_dl_find_and_decode()` resets its softbuffer for
each detected block. It does not combine SIB1 repetitions. Ordinary FDD SIB1
has an 80 ms period and four scheduled occasions, 20 ms apart; see
[3GPP TS 36.331 §5.2.1.2, via ETSI](https://www.etsi.org/deliver/etsi_ts/136300_136399/136331/13.03.00_60/ts_136331v130300p.pdf).

The optional diagnostic combiner consumes the descrambled QPSK LLRs after the
normal independent decode. It uses a separate softbuffer, scales input LLRs by
1/4 and clears cached CRC flags before every combined attempt, so every reported
pass requires a fresh turbo/CRC computation. It resets at each 80 ms boundary,
a missing occasion, a TBS change, or unsupported input. It supports normal-CP
FDD SIB1, one enabled codeword and the 16-bit LLR path. It does not combine SIB2
or arbitrary SI messages and does not modify the upstream general decoder API.

Scaling matters in this fixed-point path: unscaled accumulation produced
260 failures on the first capture; divisors 2 and 4 both produced 2. Dividing
individual, uncombined LLRs by 4 alone still produced 198 failures. These tests
support the chosen bounded combining configuration; they do not isolate every
internal numerical effect or establish an optimal scale for all signals.

## Live validation

| Run | Raw blocks / CRC failures | Combined attempts / failures | Complete periods missed: raw → with combining |
| --- | ---: | ---: | ---: |
| 120,000 iterations, gain 35 dB | 5,987 / 2,172 | 5,987 / 213 | 99 / 1,499 → 0 / 1,499 |
| 60,000 iterations, gain 45 dB | 2,997 / 990 | 2,997 / 132 | 54 / 749 → 2 / 749 |

Combining recovered 1,967 and 860 independent failures respectively. The tests
received 1,843,205,764 and 921,614,138 samples, with zero observed timestamp gaps,
RF error callbacks or sync losses. No packet-parser errors appeared in either
log. Each run had one partial period, excluded from complete-period statistics.
Counters include missed PDCCH occasions in group delivery, while per-block CRC
ratios include only detected transport blocks.

The receiver exported 16 normal and 16 recovered CRC-passed blocks from each run.
All **64 blocks, including 32 recovered blocks**, parsed as the same SIB1 with
zero ASN.1 failures. This samples recovered payload contents; it does not claim
that every recovered block was separately ASN.1-parsed. Full counts, capture
hashes and concise logs are in [the result set](results/sib1-combining/).
Live identifiers and IQ snapshots remain in local output.

The remaining two failed periods in the second run are real. There is no claim
of sustained error-free reception, RF uplink, SIB2 decoding, phone attachment,
or a working E310 eNB.

## Reproduce

Apply the latest [diagnostic patch](../tests/srsran/rx-diagnostics.patch) to a
clean srsRAN checkout at `bef8680d5f9714f3e040e6f9cbc88d7888439b6d`, replacing
older versions of the patch. Build `pdsch_ue` and `e310_replay_sib1`:

```sh
cmake --build "$SRSRAN_BUILD" --target pdsch_ue e310_replay_sib1 -j4
```

The [receiver runner](../tests/srsran/run-lte-rx.sh) enables combining by default;
set `RX_SI_COMBINE=0` to disable it. Direct `pdsch_ue` runs keep the original
independent behavior unless `SRSRAN_SI_COMBINE=1` is set. `PDSCH_TOTAL` always
reports independent results; `SI_COMBINING` reports fresh accumulated decodes;
`SIB1_GROUPS` reports period delivery and `SI_RV` splits independent results by RV.
`SI_COMBINED_PDU` exports only blocks that passed combining after the independent
attempt failed. `decode-si-log.py` tags the two sources separately.

To capture, set `SRSRAN_SI_CAPTURE` to a **new** local filename and optionally
`SRSRAN_SI_CAPTURE_LIMIT` to 1–2,000 (default 500). Use single-channel,
normal-CP FDD SI-RNTI reception without MBSFN. The receiver continues its requested
run after the capture limit. Capture writes may affect host timing; inspect
continuity counters. At 50 PRB / 15.36 MS/s, 1,000 records occupy about 123 MB.

```sh
# Use the same RF environment as run-lte-rx.sh.
SRSRAN_SI_CAPTURE=/tmp/e310-sib1.bin SRSRAN_SI_CAPTURE_LIMIT=1000 \
  RX_SUBFRAMES=20000 ./run-lte-rx.sh
"$SRSRAN_BUILD/lib/examples/e310_replay_sib1" /tmp/e310-sib1.bin wiener
REPLAY_COMBINE=1 "$SRSRAN_BUILD/lib/examples/e310_replay_sib1" /tmp/e310-sib1.bin wiener
python3 check-si-replay.py /tmp/e310-sib1.bin \
  --replay "$SRSRAN_BUILD/lib/examples/e310_replay_sib1"
```

The capture is a same-host diagnostic format: twelve native-endian uint32 words
(magic `0x31534945`, version 1, samples/record, PCI, PRB, ports, CP, PHICH length,
PHICH resources, frame type, standard-rate flag, reference-CFO flag); each record
has a uint32 TTI, complex-float samples and three uint32 original result values
(return code, blocks, errors). It is neither a raw continuous RF recording nor
a portable interchange format. The replay assumes the example's baseline
single-channel decoder configuration; exact equivalence is checked rather than
assumed.

Replay arguments select estimator, timing correction (0/1, default 1) and turbo
iterations (1–16, omitted for library default). Optional diagnostic environment
variables are `REPLAY_CFO_HZ` (−7500…7500 or `cp`), `REPLAY_CSI=0|1`,
`REPLAY_MMSE=0|1`, `REPLAY_COMBINE=0|1`, and `REPLAY_LLR_DIVISOR=1…256`
(default 4). `REPLAY_COMBINE=0` explicitly re-decodes each block with a fresh
buffer; leaving it unset skips the extra decode. Settings are printed in the log.
The regression checks replay equivalence, fresh-decode equivalence, period-boundary
isolation and rejection of truncated/invalid inputs.

---

<span id="cn"></span>

# SIB1 回放与软合并

2026-10-05 的两次仅接收实测共覆盖 **2,248 个完整 SIB1 周期**。
仅独立解码时，**153 个周期**内的各次发送全部失败；加入软合并后降为 **2 个周期**。
原始 CRC 失败数仍单独保留。这是诊断接收器广播获取能力的改善，不能据此说天线、
FPGA、UHD 或以太网已被进一步修好。

## 固定输入定位

之前顺序进行的[空口对照](long-rx.md#cn)无法排除信号随时间变化。
新功能在同步和频偏校正之后、SIB1 信道估计之前，保存样本、TTI、小区配置和原始结果。
`e310_replay_sib1` 无需连接设备，即可反复解码同一输入。
两批各 1,000 个时隙的 Wiener 回放均逐条复现原始结果，差异为零：

| 采样批次 | 独立解码 CRC 失败 | 软合并后新计算的 CRC 失败 | 补回原始失败 |
| --- | ---: | ---: | ---: |
| 增益 35 dB | 200 / 1,000 | 2 / 1,000 | 198 |
| 增益 45 dB | 486 / 1,000 | 6 / 1,000 | 481 |

合并结果使用了前面的重复发送，不能称为独立单次传输的误块率。
合并失败也不会推翻已经成功的独立结果；周期交付统计接受其中任一路的 CRC 通过结果。
第一批样本中，普通插值为 332/999 失败；平均估计为 194/957，另漏掉 43 个授权。
关闭定时校正、增加至 16 次 Turbo 迭代、CSI 加权及残余频偏校正均未达到合并的改善幅度。
原始 200 次失败按 RV 分别为 RV0：2、RV1：65、RV2：0、RV3：133，每种均有 250 次尝试。
这确认了本批数据中与重复版本有关的规律，但没有确定全部射频误块的根因。

## 实现范围

指定版本的 `srsran_ue_dl_find_and_decode()` 每次检测到传输块都会重置软缓存，
没有合并 SIB1 重复发送。普通 FDD SIB1 的周期为 80 毫秒，每隔 20 毫秒一个发送时隙；
依据见上方链接的 3GPP TS 36.331 §5.2.1.2。

新诊断在原始独立解码之后，使用已解扰的 QPSK 软判决，另设软缓存，将输入缩放为 1/4。
每次清除已缓存的 CRC 标志，重新执行 Turbo／CRC 计算，避免把历史成功冒充新解码。
跨 80 毫秒边界、漏掉一个时隙、TBS 改变或输入不支持时重置。
仅支持普通 CP、FDD SIB1、单个有效码字和 16 位 LLR；不合并任意 SI 消息或 SIB2，
没有修改通用解码 API。

定点输入缩放有影响：第一批数据不缩放直接累加失败 260 次，除以 2 或 4 均只失败 2 次。
仅将独立块的 LLR 除以 4、但不合并，仍失败 198 次。因此改善并非单独缩放即可获得；
目前也没有声称已完全定位内部数值效应或找到适合所有信号的最佳缩放系数。

## 实时验证

| 测试 | 原始块数／CRC 失败 | 合并尝试／失败 | 完整周期全部失败：原始 → 加入合并 |
| --- | ---: | ---: | ---: |
| 120,000 次迭代，35 dB | 5,987 / 2,172 | 5,987 / 213 | 99 / 1,499 → 0 / 1,499 |
| 60,000 次迭代，45 dB | 2,997 / 990 | 2,997 / 132 | 54 / 749 → 2 / 749 |

分别补回 1,967 和 860 次独立解码失败；接收 1,843,205,764 和 921,614,138 个样本，
均无观测到的时间戳断点、RF 错误回调、失步或包解析异常。
每轮有一个不完整周期，未计入完整周期统计。周期失败会计入没有检测到控制授权的时隙，
而每块 CRC 比率的分母仅包含已检测到的传输块。

每轮导出 16 个普通成功块和 16 个补回块。共 **64 个块，其中 32 个补回块**，
全部解析为一致的 SIB1，没有 ASN.1 失败；并非对全部补回块逐一做了 ASN.1 解析。
[结果集](results/sib1-combining/)包含计数、采样文件哈希及摘要日志；实际小区标识和 IQ
仍在本地输出中。
第二轮剩余的两个失败周期是真实结果，不能宣称长期零误块；SIB2、射频上行、手机入网
和 E310 基站仍未验证。

## 复现与开关

在干净的指定版本 srsRAN 上应用最新补丁，按英文部分命令构建 `pdsch_ue` 和
`e310_replay_sib1`。新版 `run-lte-rx.sh` 默认启用合并，`RX_SI_COMBINE=0` 可关闭。
直接运行 `pdsch_ue` 时需设 `SRSRAN_SI_COMBINE=1` 才启用。
`PDSCH_TOTAL` 始终保留原始结果，`SI_COMBINING` 记录重新计算的合并结果，
`SIB1_GROUPS` 记录周期交付，`SI_RV` 按冗余版本统计原始结果。
`SI_COMBINED_PDU` 只导出独立失败、合并后 CRC 成功的块，解析脚本会标明来源。

设置 `SRSRAN_SI_CAPTURE` 为不存在的新文件名即可捕获；`SRSRAN_SI_CAPTURE_LIMIT`
默认 500、允许 1～2,000 个记录，到上限只停止写文件，不会提前停止接收。
必须使用单接收通道、普通 CP 的 FDD SI-RNTI，且不开 MBSFN；文件写入可能影响时序，
须同时检查连续性统计。50 PRB、15.36 MS/s 下 1,000 条记录约 123 MB。
它是同一主机上的诊断快照格式，不是连续原始 IQ 文件；布局及完整回放命令见英文部分。

回放支持估计器、定时校正、Turbo 迭代数，以及频偏、CSI、MMSE、软合并和 LLR 缩放对照。
`REPLAY_COMBINE=0` 显式用全新缓存再次独立解码，不设置则跳过额外解码。
`check-si-replay.py` 验证原始结果复现、独立重解码一致性、跨周期隔离和非法／截断输入拒绝。
