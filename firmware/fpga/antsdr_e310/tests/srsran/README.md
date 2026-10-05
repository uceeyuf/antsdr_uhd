[English](#en) | [中文](#cn)

<span id="en"></span>

# srsRAN RF API CODEC loopback

This standalone test uses srsRAN_4G commit
`bef8680d5f9714f3e040e6f9cbc88d7888439b6d` and this fork's UHD.
Build srsRAN with the UHD headers and library from this fork, then build its
`srsran_rf` target. It must include the UHD RF plugin.

Set `SRSRAN_SOURCE`, `SRSRAN_BUILD`, and `UHD_BUILD` to absolute paths. From this directory:

```sh
cc -std=gnu11 -O2 -I"$SRSRAN_SOURCE/lib/include" -I"$SRSRAN_BUILD/lib/include" \
  srsran-rf-loopback.c -L"$SRSRAN_BUILD/lib/src/phy/rf" \
  -Wl,-rpath,"$SRSRAN_BUILD/lib/src/phy/rf" -lsrsran_rf -lm -lpthread \
  -o /tmp/e310-srsran-rf-loopback
export LD_LIBRARY_PATH="$SRSRAN_BUILD/lib/src/phy/rf:$UHD_BUILD/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd /tmp
./e310-srsran-rf-loopback
```

The source fixes the PL endpoint to `192.168.10.3`, the master clock to
30.72 MHz, and the sample rate to 1.92 MS/s. Adjust the endpoint in `args`
if required. It explicitly selects `e310_codec_loopback=1`; use the matching
E310 FPGA and this fork's diagnostic isolation implementation.
It writes `srsran_rf_capture.fc32` to the current directory.

PASS requires exact TX/RX counts, no RF callbacks reporting errors, continuous
RX timestamps, coherent tone power >99%, and image rejection >40 dB.
This exercises the srsRAN RF abstraction and UHD plugin, not the LTE protocol stack.

For receive-only LTE examples, native I/Q validation and the optional AGPL-3.0
srsRAN diagnostic patch, see [LTE reception](../../docs/lte-receive.md).

## Receive-only LTE and SIB1

Apply `rx-diagnostics.patch` to the clean pinned srsRAN source as described in
[LTE reception](../../docs/lte-receive.md). After configuring that build with this
fork's UHD, build the Linux receiver and the ASN.1 helper from this directory:

```sh
cmake --build "$SRSRAN_BUILD" --target pdsch_ue rrc_asn1 asn1_utils srslog -j4
${CXX:-c++} -std=c++14 -O2 \
  -I"$SRSRAN_SOURCE/lib/include" -I"$SRSRAN_BUILD/lib/include" decode-sib1.cc \
  -Wl,--start-group "$SRSRAN_BUILD/lib/src/asn1/librrc_asn1.a" \
  "$SRSRAN_BUILD/lib/src/asn1/libasn1_utils.a" \
  "$SRSRAN_BUILD/lib/src/srslog/libsrslog.a" -Wl,--end-group -lpthread \
  -o "$SRSRAN_BUILD/e310-decode-sib1"
export SRSRAN_BUILD UHD_BUILD
./run-lte-rx.sh
```

The runner forces `rx_only=1`, `sc8` and SI-RNTI `0xffff`. Default center frequency
is 806 MHz, with a 120,000-iteration limit. Set `RX_SUBFRAMES=10000` for a short
check, or set `RX_OUTPUT_DIR` to the parent directory for generated runs. Each run
has a unique `lte-rx.*` directory; these are ignored by Git.

`SIB1_DECODER` can override the helper path. The decoder accepts one hexadecimal
CRC-validated transport block and requires a SIB1 ASN.1 message; it does not itself
check the physical-layer CRC. `decode-si-log.py` processes only opt-in `SI_PDU`
lines exported by the patched receiver after CRC success. A smoke test decoded
16/16 real blocks with one consistent SIB1, and rejected malformed/truncated helper
inputs. Full test interpretation and optional gain/CFO/filter controls:
[long receive tests](../../docs/long-rx.md).

---

<span id="cn"></span>

# srsRAN RF API CODEC 回环

独立测试使用 srsRAN_4G 提交 `bef8680d5f9714f3e040e6f9cbc88d7888439b6d`
和本 fork 的 UHD。配置 srsRAN 时指定本 fork 的 UHD 头文件及库，然后构建
`srsran_rf` 目标，确保包括 UHD RF 插件。

将 `SRSRAN_SOURCE`、`SRSRAN_BUILD`、`UHD_BUILD` 设为对应绝对路径，
在本目录执行上方英文部分的编译／运行命令。

源码固定 PL 端点为 `192.168.10.3`、主时钟 30.72 MHz、采样率 1.92 MS/s；
可按需修改 `args` 中的端点地址。它明确指定 `e310_codec_loopback=1`，
必须配合匹配的 E310 FPGA 和本 fork 的诊断隔离实现。
捕获写入当前目录的 `srsran_rf_capture.fc32`。

PASS 要求 TX/RX 数量准确、RF 回调无错误、RX 时间戳连续、
单音相干功率占比大于 99%、镜像抑制大于 40 dB。
验证对象是 srsRAN RF 抽象层与 UHD 插件，尚未包含 LTE 协议栈。

仅接收 LTE 示例、原生 I/Q 验证与 AGPL-3.0 srsRAN 诊断补丁见
[LTE 接收](../../docs/lte-receive.md#cn)。

## 仅接收 LTE 与 SIB1

按 [LTE 接收说明](../../docs/lte-receive.md#cn)，在干净的指定版本 srsRAN 源码上
应用 `rx-diagnostics.patch`，配置时链接本 fork 的 UHD。
在本目录执行英文部分命令，构建 `pdsch_ue` 和 ASN.1 辅助程序，然后运行 `run-lte-rx.sh`。

脚本固定 `rx_only=1`、`sc8` 和 SI-RNTI `0xffff`，默认 806 MHz、120,000 次迭代。
可设 `RX_SUBFRAMES=10000` 做短测，`RX_OUTPUT_DIR` 指定结果父目录。
每次创建独立的 `lte-rx.*` 目录，Git 会忽略这些本地输出。

`SIB1_DECODER` 可覆盖辅助程序路径。辅助程序输入十六进制传输块并要求 ASN.1 消息
为 SIB1，它本身不校验物理层 CRC；`decode-si-log.py` 只处理接收器在 CRC 成功后
明确导出的 `SI_PDU` 行。整套脚本已实测解析 16/16 个一致的 SIB1；辅助程序也已验证
会拒绝格式错误或截断输入。统计含义、增益／频偏／滤波选项和限制见
[长时间接收](../../docs/long-rx.md#cn)。
