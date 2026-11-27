---
name: Shell Audit
description: Measure, audit, and safely change this repo's zsh, WezTerm, and shell-function configuration
---

# Shell audit

Use this when a task touches anything under `terminal/`, `audit/`, or `scripts/audit/`, or when
the user asks about shell startup speed, zsh configuration, WezTerm, or the shell function
library.

## Layout

| Path | What it is |
| --- | --- |
| `audit/startup.md`, `audit/load-order.md` | Measurements and load-order map of the config |
| `audit/changes.md` | Every applied change, with before/after numbers and rollback |
| `audit/inventory.md`, `audit/usage.md` | Installed tooling and how it is actually used |
| `audit/zsh-functions.md` | Function-library review and invariants |
| `scripts/audit/run.sh` | Full audit: startup attribution, inventory, checks |
| `scripts/audit/after.py` | Fast startup-only measurement |
| `terminal/shell/` | Canonical shell function library, installed by `terminal/setup.zsh` |
| `terminal/shell-modernization-plan.md` | The plan; check its status before proposing work |

## Workflow

1. **Establish the current number.** Run `scripts/audit/after.py` before changing anything.
   Never claim an improvement without a before/after pair from the same machine state.
2. **Read the relevant audit doc first.** `audit/changes.md` usually already records why a line
   exists, including the rollback. Do not undo a documented decision without addressing it.
3. **Back up before editing `~/`.** `cp ~/.zshrc ~/.zshrc.bak.YYYY-MM-DD` (also `.zshenv`,
   `.zprofile` when touched). The repo is documentation; the live config is the system of record
   until Phase 4 of the plan lands.
4. **Apply one change at a time**, measure, then update `audit/changes.md` with a dated section
   and the before/after table in `terminal/shell-modernization-plan.md` §9.
5. **Verify with the checklist** in `references/invariants.md`.

## Measurement rules

See `references/measurement.md`. The short version: paired deltas are signal, absolute medians
are not; a variant run is noisier than a standalone run; p10k is 9–35 ms, so a prompt change is
not a perf change.

## Common traps in this repo

- `.zshenv` runs for every zsh process, including scripts. Unconditional `PATH` appends multiply.
- `compinit` used to be a side effect of nvm. It is explicit now; do not remove it.
- `zsh-syntax-highlighting` must be sourced last, after the transient-prompt plugin.
- `~/.p10k.zsh` is the live prompt config; `terminal/.p10k.zsh` mirrors it. The old `.pk10.zsh`
  name was a typo that never loaded.
- Documentation drift is this repo's recurring failure. If you change a config file, update its
  guide in the same change.
