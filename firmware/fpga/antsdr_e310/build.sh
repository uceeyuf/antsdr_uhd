#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
vivado=${VIVADO:-/tools/Xilinx/Vivado/2020.2/bin/vivado}
mkdir -p "$root/vivado/logs"
cd "$root/vivado/logs"
case "${1:-project}" in
 rebuild) script=rebuild.tcl ;;
 project) script=create_e310_project.tcl ;;
 synth) script=synth.tcl ;;
 place) script=place_check.tcl ;;
 route) script=route_check.tcl ;;
 bitstream) script=bitstream.tcl ;;
 test) script=test_transport.tcl ;;
 *) echo "Usage: $0 {project|synth|place|route|bitstream|rebuild|test}" >&2; exit 2 ;;
esac
"$vivado" -mode batch -nojournal -log "${script%.tcl}.log" -source "$root/scripts/vivado/$script"
