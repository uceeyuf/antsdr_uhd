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
