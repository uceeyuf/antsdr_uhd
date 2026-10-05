#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Parse opt-in, CRC-passed SI_PDU lines with the matching srsRAN decoder."""
import argparse
import json
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("log", type=Path)
parser.add_argument("--decoder", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
decoder = args.decoder.resolve()
pattern = re.compile(r"SI_(COMBINED_)?PDU tti=(\d+) tb=(\d+) bytes=(\d+) hex=([0-9a-f]+)$")
records, failures = [], []
for line in args.log.read_text().splitlines():
    match = pattern.fullmatch(line)
    if not match:
        continue
    tti, tb, length = map(int, match.groups()[1:4])
    payload = match[5]
    if len(payload) != 2 * length:
        failures.append({"tti": tti, "error": "Length mismatch"})
        continue
    result = subprocess.run([str(decoder), payload], capture_output=True, text=True)
    if result.returncode:
        failures.append({"tti": tti, "error": "ASN.1 decoder rejected block"})
        continue
    records.append({"tti": tti, "tb": tb, "bytes": length,
                    "source": "combined" if match[1] else "independent",
                    "decoded": json.loads(result.stdout)})
unique = {json.dumps(record["decoded"], sort_keys=True) for record in records}
report = {"decoded_sib1_count": len(records), "unique_sib1_count": len(unique),
          "independent_count": sum(r["source"] == "independent" for r in records),
          "combined_count": sum(r["source"] == "combined" for r in records),
          "failures": failures, "records": records}
args.output.write_text(json.dumps(report, indent=2) + "\n")
print(f"SIB1: {len(records)} decoded blocks, {len(unique)} unique contents, {len(failures)} rejected")
raise SystemExit(0 if records and not failures else 1)
