# Correctness and risk checks

## PATH

**Remediated 2026-11-22** (see [changes.md](changes.md)): `~/.zshenv` now adds each entry only
when absent, `~/.local/bin` has a single owner, and `~/.zshrc` ends with a dedupe pass.

| Context | Entries | Unique | Duplicated paths |
| --- | ---: | ---: | ---: |
| Fresh shell, before | 33 | 25 | 6 (8 redundant entries) |
| Fresh shell, after | **25** | 25 | **0** |
| Interactive session, before | 82–83 | 46–47 | 14 |
| Interactive session, after | **46–49** | 46–49 | **0** |

The tables below describe the pre-remediation state and are kept as the record of the defect.

The 82/14 figure is real but includes compounding: `.zshenv` appends four Android paths on every
zsh process, and nested shells inherit the result. The honest statement is **a fresh shell starts
with 6 duplicated paths and 8 redundant entries, and the count grows with every nested shell.**

Duplicates in a fresh shell:

| Count | Path | Cause |
| ---: | --- | --- |
| 4 | `~/Library/Android/sdk/platform-tools` | appended at `.zshenv:5` and prepended at `:10`, twice (double source) |
| 2 | `~/Library/Android/sdk/{emulator,tools,tools/bin}` | `.zshenv:4,6,7`, double source |
| 2 | `~/cuda-gdb-darwin-12.3/bin` | `.zshenv:10`, double source |
| 2 | `~/.local/bin` | `.zprofile:11`, `.zshrc:29`, `.zshrc:123`, `:141` |

## Syntax

All files parse. No action needed:

```
OK .zshrc            OK .zshenv          OK .zprofile
OK .bashrc           OK .bash_profile    OK .profile
OK .zsh/autoload.zsh OK .zsh/zfunctions/{aws,selectoptions,sg-functions,shared-bma-functions}.zsh
```

Note: parse-clean is not the same as correct — the load-order defects in
[load-order.md](load-order.md) all pass `zsh -n`.

## Interactive state

| Property | Value | Assessment |
| --- | --- | --- |
| `compdef` available | yes | now from the explicit `compinit` in `.zshrc`, not from nvm |
| `compinit` in any dotfile | **yes** (since 2026-11-18) | explicit, with `bashcompinit` |
| `HISTSIZE` / `SAVEHIST` | 50000 / 50000 (was 2000 / 1000, unowned) | set explicitly in `.zshrc` |
| `HISTFILE` | `~/.zsh_history` | 33 KB, being migrated to timestamped entries |
| History options | `SHARE_HISTORY`, `EXTENDED_HISTORY`, `HIST_IGNORE_ALL_DUPS`, `HIST_SAVE_NO_DUPS`, `HIST_FIND_NO_DUPS`, `HIST_REDUCE_BLANKS`, `HIST_IGNORE_SPACE` | was: all defaults |
| `AUTO_PUSHD`, `AUTO_CD`, `EXTENDED_GLOB`, `NO_BEEP` | off | defaults (unchanged) |
| Aliases | 13 | `ls`, `ll`, `la`, `gitb`, `7z`, `ipinfo`, `shalias`, `shenv`, `sh-bindkey`, `wz-show-keys` |
| Functions at startup | 1622 | 1441 are completion wrappers; the rest are p10k and fzf internals. No bash-my-aws functions load in zsh. |
| `core.editor` | `code --wait` | matches 35 `code` invocations |

`HISTSIZE=2000`/`SAVEHIST=1000` with no assignment in any dotfile means some sourced third-party
file sets them. Whatever sets them, it is not under your control — a textbook case of "works today,
breaks on upgrade".

## Startup errors

Persistent, every interactive shell:

| Error | Source | Impact |
| --- | --- | --- |
| `(anon):setopt:7: can't change option: monitor` | `mise activate zsh` | cosmetic |
| `[ERROR]: gitstatus failed to initialize` | p10k | git segment degraded; removed with p10k |
| `pyenv: no such command 'virtualenv-init'` | non-login shells | pyenv-virtualenv unavailable outside login shells |
| `command not found: jenv` | `.zshrc:65` in non-login shells | Java version not applied in non-login shells |

The last two only appear when `.zprofile` has not run, which includes many terminal and IDE
invocations. Verify with:

```sh
env -i HOME="$HOME" TERM=dumb zsh -i -c exit 2>&1 >/dev/null
```

## Secrets

**Remediated 2026-11-22.** The exposed key was rotated by the user and the export removed from
`~/.zshenv`. `~/.zshenv` now sources an optional untracked `~/.config/secrets.env` instead, so no
value needs to live in a file that gets copied or committed.

| File | Line | Kind | Variable | Status |
| --- | ---: | --- | --- | --- |
| `~/.zshenv` | 15 (baseline) | static API key, plaintext | `SAKANA_API_KEY` | rotated and removed |

## Other configuration risks

| Item | Finding | Recommendation |
| --- | --- | --- |
| `http.sslVerify` | `false`, in live `~/.gitconfig` **and** in `guides/conf/.gitconfig` | scope to a specific host via `http.<url>.sslVerify`, or remove |
| `~/.inputrc` | one malformed line: `set completion-ignore-case on set show-all-if-ambiguous on TAB: menu-complete` | split into three lines, or delete (zsh ignores it) |
| `.pk10.zsh` in repo | typo; loaded file is `~/.p10k.zsh` | rename, and document the real target |
| WezTerm config | font `MesloLGS Nerd Font Mono`, 14 pt, 0.8 opacity, blur 20; no `default_prog` | fine; `default_prog` omission means the login shell path is used, which is why `.zprofile` runs |
| conda | `conda init` in `.bash_profile` only | see zsh/bash divergence in load-order.md |

## Reproduction

```sh
scripts/audit/run.sh           # rewrites audit/raw/*.json
env -i HOME="$HOME" TERM=dumb zsh -i -c 'print -rl -- ${(s.:.)PATH}'   # clean PATH
zsh -i -x -c exit 2>&1 >/dev/null | grep -c 'ANDROID_SDK='             # proves double source
```
