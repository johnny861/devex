---
description: Run the full shell audit and report regressions
agent: plan
---

Run `scripts/audit/run.sh` from the repository root.

Then compare `audit/raw/timing.json` with `audit/raw/timing-baseline.json` and report:

1. The startup median delta (interactive and login).
2. Any variant whose attributed cost changed by more than 20%.
3. The clean-environment PATH entry count and duplicate count.
4. Any change in the startup stderr messages.

Finish with the newest entry in `audit/changes.md` and whether the current numbers match what it
claims. Do not edit files.
