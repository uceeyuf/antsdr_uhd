#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Check replay equivalence and combiner isolation using a real Wiener capture."""
import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("capture", type=Path)
parser.add_argument("--replay", required=True, type=Path)
args = parser.parse_args()
env = {k: v for k, v in os.environ.items() if not k.startswith("REPLAY_")}


def run(path, **settings):
    return subprocess.run([str(args.replay.resolve()), str(path), "wiener"],
                          env={**env, **settings}, text=True, capture_output=True)


def total(output, prefix):
    lines = [line for line in output.splitlines() if line.startswith(prefix + " ")]
    assert len(lines) == 1, (prefix, lines)
    return dict(part.split("=", 1) for part in lines[0].split()[1:])


baseline = run(args.capture, REPLAY_COMBINE="0", REPLAY_LLR_DIVISOR="1")
assert baseline.returncode == 0, baseline.stderr
raw = total(baseline.stdout, "REPLAY_TOTAL")
retry = total(baseline.stdout, "COMBINED_TOTAL")
assert int(raw["records"]) > 0 and raw["mismatch_records"] == "0", raw
assert retry["attempts"] == raw["blocks"] and retry["errors"] == raw["errors"], (raw, retry)
assert retry["recovered"] == "0", retry

with tempfile.TemporaryDirectory(prefix="e310-si-check-") as tmp:
    root = Path(tmp)
    with args.capture.open("rb") as source:
        header = source.read(48)
        count = struct.unpack("=12I", header)[2]
        size = 16 + count * 8
        records = []
        for i in range(16):
            record = bytearray(source.read(size))
            assert len(record) == size, "Capture must have at least 16 records"
            # Normal-CP CRS and SIB1 subframe remain at index 5; each record is
            # assigned a separate 80 ms period, which must prohibit combining.
            struct.pack_into("=I", record, 0, i * 80 + 5)
            records.append(record)
    boundary = root / "boundary.bin"
    boundary.write_bytes(header + b"".join(records))
    decoded = []
    for mode in ("0", "1"):
        result = run(boundary, REPLAY_COMBINE=mode)
        assert result.returncode == 0, result.stderr
        decoded.append([line for line in result.stdout.splitlines()
                        if line.startswith("COMBINED_RECORD ")])
    assert len(decoded[0]) == 16 and decoded[0] == decoded[1]
    for name, content in (("header", bytes(48)), ("truncated", header + b"\0")):
        path = root / (name + ".bin")
        path.write_bytes(content)
        assert run(path).returncode == 2, name
    for name, value in (("REPLAY_LLR_DIVISOR", "0"), ("REPLAY_CFO_HZ", "bad"),
                        ("REPLAY_CFO_HZ", "nan"), ("REPLAY_CSI", "bad")):
        assert run(boundary, **{name: value}).returncode == 2, (name, value)

print(json.dumps({"baseline_records": int(raw["records"]),
                  "baseline_mismatches": 0, "fresh_decode_matches": True,
                  "period_boundary_reset_records": 16,
                  "malformed_inputs_rejected": True}, indent=2))
