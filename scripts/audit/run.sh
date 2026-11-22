#!/bin/sh
# Regenerate the Phase 0 audit artifacts into audit/raw/.
#
# Everything here is read-only with respect to the live config. Variant configs are built in
# a scratch directory and never written into this repo, so no secrets are copied into git.
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out="$repo_root/audit/raw"

echo "== startup attribution =="
python3 "$repo_root/scripts/audit/measure.py" "$out"

echo
echo "== inventory, usage, live state =="
python3 "$repo_root/scripts/audit/inventory.py" "$out"

echo
echo "== correctness and risk checks =="
python3 "$repo_root/scripts/audit/checks.py" "$out"

echo
echo "done: $out"
