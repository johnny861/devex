---
description: Quick shell startup timing
agent: plan
---

Run `scripts/audit/after.py` and report the three medians it prints (interactive, login, clean
non-login), plus the last recorded figures from `audit/changes.md`.

State whether interactive startup is inside the plan's < 300 ms target and, if it is not, name
the largest remaining variant cost from `audit/raw/timing.json`.
