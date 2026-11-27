# Load order and ownership

Derived from the live files plus `zsh -i -x` traces (`ANDROID_SDK=` appears twice per shell,
`.zshenv` is read twice).

## Files zsh reads

```
/etc/zshenv
~/.zshenv                        always, every zsh process (including scripts)
~/.zprofile                      login shells only
~/.zshrc                         interactive shells only
~/.zsh/autoload.zsh              sourced by .zshrc:122
  ~/.zsh/zfunctions/aws.zsh
  ~/.zsh/zfunctions/selectoptions.zsh
  ~/.zsh/zfunctions/sg-functions.zsh
  ~/.zsh/zfunctions/shared-bma-functions.zsh
```

## What `.zshrc` loads, in order

| Line | Loads | Note |
| --- | --- | --- |
| 1–6 | p10k instant prompt | reads a cache file; no cost when absent |
| 9 | `~/.wezterm/wezterm.sh` | WezTerm shell integration (20 KB); present and valid |
| 18–21 | pyenv + pyenv-virtualenv | line 20 spawns `bash --norc -ec`; ~177 ms |
| 24–26 | nvm + **`~/.nvm/bash_completion`** | the completion script calls `compinit`; ~691 ms |
| 29 | `~/.local/bin` | third owner of this path |
| 47–53 | pnpm | |
| 56–60 | gcloud path + completion | completion registers `compdef` before compinit? No — compinit already ran at line 26 |
| 63–65 | jenv | `eval "$(jenv init -)"`; ~338 ms; fails in non-login shells |
| 77–79 | p10k theme + `~/.p10k.zsh` | ~35 ms |
| 80 | zsh-autosuggestions | |
| 81 | zsh-syntax-highlighting | **should be last; it is not** |
| 83–84 | fzf-git, fzf | defines widgets *after* syntax highlighting loaded |
| 104–113 | bash-my-aws | relies on `bashcompinit`, which only exists because nvm loaded it |
| 114–119 | bun completions + PATH | |
| 121 | **`source ~/.zshenv`** | second read; re-appends PATH, re-exports secret |
| 122 | `~/.zsh/autoload.zsh` | 4 function files |
| 123 | `~/.local/bin` (again) | fourth owner |
| 126–139 | aliases | `ls`→eza, `gitb`, `ipinfo`, opencode PATH |
| 141 | `mise activate zsh` | last: after the prompt and all plugins |

## Ordering hazards

1. **`zsh-syntax-highlighting` is sourced at line 81, not last.** fzf (83–84), bash-my-aws
   (113), bun (115) and mise (141) all define widgets or completions afterwards. Widgets created
   after the highlighter cannot be wrapped by it, so those command lines are not highlighted.
2. **`compinit` is a side effect of nvm.** `~/.nvm/bash_completion:88-91` autoloads and runs
   `compinit`, which also provides `bashcompinit` for bash-my-aws. Removing nvm without adding an
   explicit `compinit` silently removes all completion. This is the single most important hidden
   coupling in the config.
3. **`.zshenv` is sourced twice** (startup and `.zshrc:121`) and mutates `PATH` in five places. A
   clean shell therefore starts with 33 `PATH` entries, 8 duplicated; nested shells compound it.
4. **`.zshrc` depends on `.zprofile`.** `jenv` (line 65) and the pyenv-virtualenv plugin are only
   on `PATH` after `.zprofile` runs `brew shellenv`. Non-login shells fail with
   `command not found: jenv` and `pyenv: no such command 'virtualenv-init'`.
5. **`mise activate` runs last**, after the prompt is built and completions are cached. Tool
   resolution before line 141 uses the pre-mise `PATH`, so the shell briefly has two truths about
   which `node`/`python` is active.

## PATH ownership

23 `PATH=` assignments across the files (`.zshenv` 5, `.zprofile` 4, `.zshrc` 14), plus pyenv,
nvm and jenv rewriting `PATH` internally — 28 mutations observed in a single startup.

| Path | Written by |
| --- | --- |
| Android SDK (4 entries) | `.zshenv:4-7`, plus `PLATFORM_TOOLS` prepend at `:10` |
| CUDA gdb | `.zshenv:10` |
| cargo | `.zshenv:11`, `.bash_profile:20`, `.profile:1` |
| `~/.local/bin` | `.zprofile:11`, `.zshrc:29`, `.zshrc:123` |
| pyenv shims/bin | `.zshrc:19` + `pyenv init --path` |
| pyenv-virtualenv shims | `.zshrc:21` |
| nvm | `.zshrc:25` (and `nvm` rewrites `PATH` + `MANPATH` at runtime) |
| pnpm | `.zshrc:48-52` |
| gcloud | `.zshrc:57` |
| jenv bin/shims | `.zshrc:64` + `jenv init -` |
| bun | `.zshrc:118-119` |
| bash-my-aws | `.zshrc:105` |
| opencode | `.zshrc:139` |
| mise | `.zshrc:141` |
| dotnet, ByteBlower | `.zprofile:13,15` |
| OrbStack | `.zprofile:19` |

No single owner. Phase 1 replaces this with one ordered assembly function and a dedup pass.

## zsh vs bash divergence

| Runtime | interactive zsh | login bash |
| --- | --- | --- |
| python | `~/.pyenv/shims/python` (3.11.6 via `.python-version`) | `/opt/miniconda3/bin/python` |
| java | `~/.jenv/shims/java` (17.0.17) | `/usr/bin/java` |
| node | nvm v26.13.0 | nvm v26.13.0 |
| ruby | `/usr/bin/ruby` | `/usr/bin/ruby` (rbenv installed but never initialised) |

Also: `conda init` is in `.bash_profile` only; the equivalent block in `.zshrc` is commented out.
`~/.inputrc` affects bash/readline only and appears to put several directives on one line.
