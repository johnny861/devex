# Usage telemetry

Source: `~/.zsh_history`, 33 KB, **1053 commands**, parsed from command heads.

## Limitation first

The file has **no extended timestamps**. `EXTENDED_HISTORY` was never enabled, so entries are
stored as bare command text with no start time. Consequences for this audit:

- No time window: "used in the last 90 days" cannot be computed.
- No per-command frequency-over-time, only totals.
- `fc -li` history review is unavailable to you as well, not just to this audit.

Enabling `setopt EXTENDED_HISTORY SHARE_HISTORY INC_APPEND_HISTORY` is therefore a Phase 1 item
that pays off at the *next* audit, not this one.

## Top commands

| Command | Count | Reading |
| --- | ---: | --- |
| `ls` | 102 | reaches eza through the alias |
| `cd` | 95 | — |
| `az` | 93 | Azure CLI is the second-biggest workflow |
| `adb` | 57 | Android tooling is live; the SDK `PATH` block is not dead |
| `git` | 55 | plus `st` ×16 |
| `opencode` | 51 | |
| `mise` | 41 | plus `shenv` ×31, `shalias` ×22 (mise shell aliases) |
| `code` | 35 | matches `core.editor = code --wait` |
| `select-az-dev` | 32 | custom function in `~/.zsh/zfunctions` |
| `exit` | 31 | |
| `echo` | 29 | |
| `source` | 26 | shell reloading — consistent with an unstable config |
| `curl` | 17 | |
| `aws` | 16 | |
| `st` | 16 | git status alias |
| `claude` | 14 | |
| `7z` | 10 | |
| `az-account-list`, `copy-bacpac-to-dev` | 8, 6 | more custom Azure/SQL functions |

## Tool-level counts

| Command | Count | Note |
| --- | ---: | --- |
| `az` | 93 | |
| `git` | 55 | |
| `opencode` | 51 | |
| `mise` | 41 | |
| `code` | 35 | |
| `aws` | 16 | |
| `cat` | 6 | plain `cat`, not bat |
| `brew` | 6 | |
| `nvm` | 6 | against ~691 ms of every shell start |
| `python` | 5 | |
| `gh` | 4 | |
| `docker` | 3 | podman installed but never invoked |
| `grep` | 3 | plain grep, not rg |
| `npm` | 2 | |
| `terraform` | 1 | |
| `eza`, `z`, `bat`, `rg`, `fzf`, `fd`, `tree`, `delta`, `jenv`, `pyenv`, `rbenv`, `kubectl`, `pnpm`, `bun`, `uv`, `pipx`, `gcloud` | 0 | see caveats |

## Reading zeroes correctly

- **`eza` = 0 but `ls` = 102**: the alias carries it. Do not retire eza on this number.
- **`fzf` = 0**: used through keybindings (`Ctrl-R`, `Ctrl-T`, `Alt-C`) and fzf-git, which never
  appear as a command head. Do not retire fzf on this number.
- **`rg` = 0**: editors and agent tooling call it directly; not a shell habit.
- **`jenv`/`pyenv` = 0**: expected. Both work through shims, not through their CLI. But the
  asymmetry matters: pyenv's shim is doing real work (`python` → 3.11.6 pinned), while jenv pins a
  version that never changes.
- **`nvm` = 6**: the only version manager you actually operate by hand, and it is the most
  expensive. The 6 invocations are mostly `nvm use`, which mise covers with a `.nvmrc`-compatible
  `mise use`.

## What the history supports

| Decision | Supported by |
| --- | --- |
| Keep eza, fzf, delta, azure-cli, awscli, and the custom zsh functions | direct or aliased use |
| Decide on bash-my-aws | its binaries are on `PATH` but its `aliases` file is not sourced, so its functions never load in zsh |
| Replace nvm | 691 ms cost vs 6 manual invocations; node already exists in mise |
| Replace jenv | 338 ms cost vs 0 invocations; version is pinned, not switched |
| Keep pyenv | `python` resolves through its shims; pin file and venvs in use |
| Retire rbenv/ruby-install | zero invocations *and* never initialised |
| Retire tree | zero invocations, superseded by eza |
| Investigate bat/grep/rg | plain `cat` and `grep` still used; the modern replacements are installed but unaliased |

That last row is the most interesting gap: you have `bat` and `rg` installed and are still running
`cat` and `grep` by hand. Either wire them up (aliases, `MANPAGER`, `BAT_THEME`) or remove them.
Leaving them unaliased means paying install and update cost for nothing.
