# Startup baseline

Measured with `zsh -i -c exit`, 20 warm runs per variant, median. Each variant is a copy of the
real `.zshrc` with specific lines **deleted**, validated with `zsh -n` before measurement, so a
variant can never abort on a parse error and report a fake win.

## Results

| Variant | Run A | Run B (`scripts/audit`) | Δ vs full (B) |
| --- | ---: | ---: | ---: |
| `zsh -f` (no rc files) | 6.0 ms | 5.3 ms | −1357 ms |
| Empty `.zshrc` | 16.7 ms | 17.1 ms | −1345 ms |
| Full config | 1409 ms | **1362 ms** | — |
| Full − p10k | 1382 ms | 1354 ms | **−9 ms** (−35 ms in run A) |
| Full − nvm | 718 ms | 688 ms | **−675 ms** |
| Full − jenv | 1071 ms | 1034 ms | **−329 ms** |
| Full − pyenv | 1232 ms | 1194 ms | **−169 ms** |
| Full − mise | 1373 ms | 1323 ms | −40 ms |
| Full − bash-my-aws | 1422 ms | 1348 ms | −14 ms |
| Full − autosuggestions/highlighting | 1446 ms | 1343 ms | −20 ms |
| Full − all version managers | 97 ms | 98 ms | **−1265 ms** |

Run B is the canonical one because it is reproducible with `scripts/audit/run.sh`; run A was an
earlier pass on the same host. The p10k delta is the noisiest measurement (9–35 ms) and is
reported as a range rather than a point.

Individual version-manager deltas sum to 1211 ms against a combined 1265 ms, so there is ~54 ms of
overlap (each pays for `compinit` and `manpath` work the others also trigger).

## Attribution

```
1362 ms  full
├─ 1265 ms  version managers
│   ├─ 675 ms  nvm + nvm bash_completion
│   ├─ 329 ms  jenv
│   ├─ 169 ms  pyenv (init --path spawns bash) + virtualenv-init
│   └─  40 ms  mise activate
├─    9 ms  powerlevel10k (theme + .p10k.zsh)
└─   67 ms  compinit, plugins, fzf, bash-my-aws (residual: 98 − 17 − 9)
```

`compinit` is not separately isolated from that residual; `zprof` attributes ~150 ms of
instrumented time to `compdump` + the 951 `compdef` calls, which supports it being the largest
piece of the 67 ms.

`zprof` confirms the shape. It counts only time inside zsh functions, so subprocess costs (the
`pyenv init --path` bash spawn, jenv's shim scripts) are missing from its total (~1.08 s against a
1.36 s wall clock). Compare rows within this table, not against the table above.

| Function | Cumulative | Self |
| --- | ---: | ---: |
| `nvm_auto` | 664 ms | 136 ms |
| `nvm` | 528 ms | 328 ms |
| `nvm_ensure_version_installed` | 179 ms | 165 ms |
| `compinit` | 246 ms | 80 ms |
| `compdump` | 79 ms | 79 ms |
| `compdef` ×951 | 72 ms | 72 ms |
| `_jenv_export_hook` | 81 ms | 81 ms |
| `_mise_hook` | 46 ms | 46 ms |
| `_p9k_init_ssh` | 8.5 ms | 8.5 ms |

## What this means for the plan

**The prompt migration will not make the shell faster.** p10k is 9–35 ms of a ~1360–1420 ms
startup; starship will replace roughly that. The plan's < 300 ms target is reached by the
version-manager work, not by starship — and the target is conservative: ~98 ms is achievable with
the current config minus p10k and the version managers.

Order of value:

1. **nvm → mise** (`node` is already a mise-managed runtime elsewhere in the config): −675 ms.
   **Done 2026-11-18.**
2. **jenv → a static `JAVA_HOME`**: −329 ms. The active version is pinned to 17.0.17 and has never
   been switched from the shell (0 `jenv` commands in 1053 history entries), so a shim manager is
   buying nothing. **Done 2026-11-18.**
3. **pyenv**: −169 ms, mostly `pyenv init --path` shelling out to `bash`. Keep pyenv (it is
   load-bearing: `python` resolves through its shims and a `.python-version` pin is in use) but
   drop `--path` and let the shims stay on `PATH`.
4. **compinit**: give it its own file with a cache and `-C`; today it is a side effect of nvm.

## After remediation (2026-11-18)

| Shell | Before | After |
| --- | ---: | ---: |
| `zsh -i -c exit` | 1362–1525 ms | **387–441 ms** |
| `zsh -l -i -c exit` | — | 428–442 ms |

Remaining cost is dominated by pyenv (~294 ms) and mise activation (~40 ms). Details, diff, and
rollback in [changes.md](changes.md).

## Startup errors

Three messages, eight non-empty lines, on every interactive start:

```
(anon):setopt:7: can't change option: monitor
[ERROR]: gitstatus failed to initialize.
  Add the following parameter to ~/.zshrc for extra diagnostics on error: GITSTATUS_LOG_LEVEL=DEBUG
  Restart Zsh to retry gitstatus initialization: exec zsh
(eval):1: can't change option: zle
(eval):1: can't change option: zle
```

- `monitor` and the two `zle` errors come from `mise activate zsh` running `setopt` where the
  option does not apply.
- The `gitstatus` failure means p10k's git segment has been degraded or absent. Root cause not
  pursued: the component is being removed. It is recorded so that "the prompt works now" is not
  mistaken for a regression later. Removing p10k also removes that error block from every startup.

In a **non-login** shell (`zsh -i` without `.zprofile`) there are two more:

```
pyenv: no such command `virtualenv-init'
/Users/michaelhunter/.zshrc:65: command not found: jenv
```

`.zshrc` assumes `.zprofile` already ran `brew shellenv` to put `jenv` and the pyenv-virtualenv
plugin on `PATH`. Terminals, IDE tasks, and `zsh -c` invocations that are not login shells get a
degraded environment. See [load-order.md](load-order.md).

## Method notes

- `zsh -i -c exit` measures full rc evaluation plus one prompt render. It does **not** isolate
  time-to-first-paint; p10k's instant prompt means perceived startup is better than this number.
  Since immediately after this change there is no instant prompt, the *felt* difference will be
  worse than the p10k delta alone unless the version-manager work lands first.
- Numbers were taken with the same warm `~/.zcompdump` and warm page cache.
- The harness's own parent shell already had a polluted `PATH`; PATH counts in
  [checks.md](checks.md) report both the inherited and the clean-environment figures.
