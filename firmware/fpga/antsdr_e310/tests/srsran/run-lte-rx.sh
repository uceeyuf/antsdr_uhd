#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Receive public LTE system information only; requires rx-diagnostics.patch.
set -euo pipefail
: "${SRSRAN_BUILD:?Set SRSRAN_BUILD to the patched srsRAN build directory}"
: "${UHD_BUILD:?Set UHD_BUILD to the fork UHD build directory}"
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
receiver="$SRSRAN_BUILD/lib/examples/pdsch_ue"
decoder=${SIB1_DECODER:-"$SRSRAN_BUILD/e310-decode-sib1"}
[[ -x "$receiver" && -x "$decoder" ]] || {
  echo 'Build pdsch_ue and e310-decode-sib1 as described in README.md.' >&2; exit 2;
}
iterations=${RX_SUBFRAMES:-120000}
[[ "$iterations" =~ ^[1-9][0-9]*$ && ${#iterations} -le 7 ]] || {
  echo 'RX_SUBFRAMES must be a positive integer of at most seven digits.' >&2; exit 2;
}
cfo=${RX_CFO_REF:-0}
[[ "$cfo" = 0 || "$cfo" = 1 ]] || { echo 'RX_CFO_REF must be 0 or 1.' >&2; exit 2; }
output_parent=${RX_OUTPUT_DIR:-"$PWD"}
mkdir -p -- "$output_parent"
run_dir=$(mktemp -d "$output_parent/lte-rx.XXXXXX")
export LD_LIBRARY_PATH="$SRSRAN_BUILD/lib/src/phy/rf:$UHD_BUILD/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SRSRAN_RX_COMPACT=1 SRSRAN_DUMP_SI=1
export SRSRAN_SI_COMBINE=${RX_SI_COMBINE:-1}
[[ "$SRSRAN_SI_COMBINE" = 0 || "$SRSRAN_SI_COMBINE" = 1 ]] || {
  echo 'RX_SI_COMBINE must be 0 or 1.' >&2; exit 2;
}
printf 'SRSRAN_SI_COMBINE=%s\n' "$SRSRAN_SI_COMBINE" > "$run_dir/settings.txt"
args="type=ant,addr=${E310_ADDR:-192.168.10.3},master_clock_rate=30.72e6,rx_only=1,otw_format=sc8"
if [[ -n "${RX_BANDWIDTH_HZ:-}" ]]; then args+=",rx_bandwidth_hz=$RX_BANDWIDTH_HZ"; fi
options=(-I UHD -a "$args" -f "${RX_FREQ_HZ:-806000000}" -g "${RX_GAIN_DB:-35}"
         -Q -R "${RX_ESTIMATOR:-wiener}" -r 0xffff -n "$iterations")
if [[ "$cfo" = 1 ]]; then options+=(-F); fi
printf '%q ' "$receiver" "${options[@]}" > "$run_dir/command.txt"
printf '\n' >> "$run_dir/command.txt"
set +e
timeout --signal=INT --kill-after=5 "$((iterations / 1000 + 60))" \
  "$receiver" "${options[@]}" 2>&1 | tee "$run_dir/receive.log"
status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$status" > "$run_dir/exit-code.txt"
if [[ "$status" -ne 0 ]]; then echo "Receive failed or timed out; logs: $run_dir" >&2; exit "$status"; fi
python3 "$here/decode-si-log.py" "$run_dir/receive.log" \
  --decoder "$decoder" --output "$run_dir/sib1.json"
echo "Receive logs and decoded SIB1: $run_dir"
