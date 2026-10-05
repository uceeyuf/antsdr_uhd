#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# Requires Icarus Verilog (iverilog and vvp) on PATH.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sim_dir=$(mktemp -d)
trap 'rm -rf -- "$sim_dir"' EXIT
sources=("$root/../lib/packet_proc/ip_hdr_checksum.v"
         "$root/../lib/rfnoc/xport/uoe_packet_gen.v"
         "$root/tests/tb_e310_udp_padding.sv")
iverilog -g2012 -s tb_e310_udp_padding -o "$sim_dir/fixed.vvp" "${sources[@]}"
vvp "$sim_dir/fixed.vvp"
iverilog -g2012 -s tb_e310_udp_padding -Ptb_e310_udp_padding.PAD=0 \
  -o "$sim_dir/old.vvp" "${sources[@]}"
if vvp "$sim_dir/old.vvp" > "$sim_dir/old.log" 2>&1; then
  echo 'ERROR: regression did not detect the old missing-padding behavior' >&2
  exit 1
fi
grep -q 'UDP padding missing' "$sim_dir/old.log"
echo 'PASS: regression rejects the old unpadded UDP packet'
