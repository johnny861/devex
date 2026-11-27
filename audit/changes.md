# Change log

Live-config changes, each with before/after measurements and a rollback path. Everything here is
reversible from a timestamped backup; nothing has been uninstalled.

## Summary

| Area | Before | After | Date |
| --- | --- | --- | --- |
| Startup (`zsh -i -c exit`) | 1362–1525 ms | **387–441 ms** | 2026-11-18 |
| Startup (login `zsh -l -i`) | — | 428–442 ms | 2026-11-22 |
| `PATH` (clean shell) | 33 entries, 6 duplicated paths | **25 entries, 0 duplicates** | 2026-11-22 |
| `PATH` (interactive session) | 82–83 entries, 14 duplicated paths | **49, 0 duplicates** | 2026-11-22 |
| History | 30-entry default, no timestamps, no sharing | 50 000 entries, timestamped, shared, deduped | 2026-11-22 |
| Secrets in dotfiles | 1 plaintext API key | **0** | 2026-11-22 |

---

## 2026-11-18

### Change 1 — jenv → static `JAVA_HOME`

jenv cost ~330 ms per shell to resolve a version that had never been switched: `~/.jenv/version`
pinned `17.0.17`, and `17.0.17` was a symlink to `zulu-17.jdk`. Zero `jenv` commands in 1053
history entries.

```diff
-## jenv
-export PATH="$HOME/.jenv/bin:$PATH"
-eval "$(jenv init -)"
+## java (static: jenv cost ~330 ms per shell for a version that never changed)
+export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
+export PATH="$JAVA_HOME/bin:$PATH"
```

### Change 2 — nvm → mise, with explicit completion

nvm cost ~675 ms and was also supplying `compinit` and `bashcompinit` as a side effect.
Removing it without replacing that would have silently killed all completion.

```diff
-export NVM_DIR="$HOME/.nvm"
-[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
-[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
+## completion (explicit; was previously only a side effect of nvm's bash_completion)
+autoload -Uz compinit && compinit
+autoload -Uz bashcompinit && bashcompinit
```

Outside `.zshrc`:

```sh
mise use -g node@26.13.0
mise settings set idiomatic_version_file_enable_tools node
```

The second line was required: mise ignores `.nvmrc` by default. Verified with a directory pinned to
`22.19.0` before (resolved 26.13.0) and after (resolved 22.19.0).

Paired prototype: 1525 ms → 1164 ms (jenv only) → 452 ms (jenv + nvm).

---

## 2026-11-22

### Change 3 — leaked API key removed

The key was rotated by the user and the export deleted from `~/.zshenv`. A guarded hook now reads
an optional untracked file instead, so no value needs to live in a copied/committed dotfile:

```zsh
# ~/.zshenv
[[ -r "$HOME/.config/secrets.env" ]] && . "$HOME/.config/secrets.env"
```

Create `~/.config/secrets.env` (mode 600) with `export NAME=value` lines if you need it. Verified:
`grep -c SAKANA ~/.zshenv` → 0.

### Change 4 — PATH cleanup

Three defects: `.zshenv` appended four Android paths on **every** read (and it was read twice, once
by zsh and again from `.zshrc`), platform-tools was additionally prepended, and `~/.local/bin` had
three owners. Each append is now conditional, `~/.local/bin` has one owner, the redundant
`source ~/.zshenv` is gone, and `.zshrc` ends with a dedupe pass.

```diff
-# ~/.zshenv
-export PATH=$PATH:$ANDROID_HOME/emulator
-export PATH=$PATH:$ANDROID_HOME/platform-tools
-...
-export PATH=$PLATFORM_TOOLS:$CUDA_GDB:$PATH
+# add only when absent; this file runs for every zsh, including nested shells
+path_append()  { [[ ":$PATH:" == *":$1:"* ]] || PATH="$PATH:$1" }
+path_prepend() { [[ ":$PATH:" == *":$1:"* ]] || PATH="$1:$PATH" }
+
+path_prepend "$HOME/.local/bin"
+path_append  "$ANDROID_HOME/emulator"
+path_append  "$PLATFORM_TOOLS"
...
+unfunction path_append path_prepend
```

```diff
-# ~/.zshrc
-source  ~/.zshenv
-source ~/.zsh/autoload.zsh
-export PATH="$HOME/.local/bin:$PATH" # wezcld
+source ~/.zsh/autoload.zsh
+
+# end of .zshrc, after mise activate
+typeset -U path
+path=($path)
+export PATH
```

`~/.zprofile` no longer adds `~/.local/bin` either. Result: 25 entries / 0 duplicates in a clean
shell (from 33 / 6); 49 / 0 interactive (from 82 / 14).

Tool resolution unchanged: `python` → pyenv shim, `node` → mise, `java` → zulu 17, `mise`,
`opencode`, `az`, `brew` all resolve as before.

### Change 5 — history options

Previously `HISTSIZE`/`SAVEHIST` were 2000/1000 and set by **no file**; every history option was at
its default (30 entries in memory, no timestamps, no cross-window sharing).

```zsh
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY      # timestamps -> `fc -li`
setopt SHARE_HISTORY         # one history across panes (implies INC_APPEND_HISTORY)
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE     # leading space = not recorded
```

Verified in a live pty shell:

| Check | Result |
| --- | --- |
| Entry written with a timestamp | `: 1795389238:0;: history-check-…` |
| Visible while the shell is still running (sharing) | yes |
| Leading-space command recorded | no (`HIST_IGNORE_SPACE` working) |
| `HISTSIZE` / `SAVEHIST` in a new shell | 50000 / 50000 |
| `setopt` shows all seven options | yes |

**One-time accounting of the existing history.** `HIST_IGNORE_ALL_DUPS` pruned the file on first
read: 1063 lines → 555 entries. No distinct command was lost — the backup contains 526 unique
commands and the current file contains 529 unique commands, with **zero** unique commands present
only in the backup. What disappeared was repeats.

**Timestamp artifact.** Entries that predate this change had no timestamps, so on rewrite they carry
the rewrite time (all clustered within ~50 s of 2026-11-22 17:14). Real timestamps start from now;
the old entries cannot be recovered chronologically because the data never existed. If you want the
old file verbatim it is at `~/.zsh_history.bak.2026-11-22`.

**Behaviour change to be aware of:** prefixing a command with a space keeps it out of history — and
therefore out of `Ctrl-R` and cross-window search. That is the intent (it is how you run a command
containing a secret), but it is new.

---

## Verification (all changes)

| Check | Result |
| --- | --- |
| `zsh -n` on `.zshenv`, `.zshrc`, `.zprofile` | passes |
| `node -v` / `command -v node` | `v26.13.0` from mise |
| `npm -v` | `11.20.0` |
| `java -version` | 17.0.17 (Zulu), `JAVA_HOME` set |
| `compdef` / `bashcompinit` | both defined |
| `_git`, `_aws` completions | present |
| `nvm` function | absent (intended) |
| `.nvmrc` in a project dir | honoured (`24.18.0` → `v24.18.0`) |
| `PATH` duplicates | 0 in both clean and interactive shells |
| secrets in dotfiles | 0 |
| startup stderr | still 8 lines: mise `setopt` ×3, p10k `gitstatus` block |

## Rollback

```sh
# 2026-11-22 changes (secrets, PATH, history)
cp ~/.zshenv.bak.2026-11-22  ~/.zshenv
cp ~/.zshrc.bak.2026-11-22   ~/.zshrc
cp ~/.zprofile.bak.2026-11-22 ~/.zprofile
cp ~/.zsh_history.bak.2026-11-22 ~/.zsh_history   # only if the history file itself is a problem

# 2026-11-18 changes (jenv, nvm)
cp ~/.zshrc.bak.2026-11-18 ~/.zshrc
mise unuse -g node
```

`powerlevel10k`, `jenv`, `~/.nvm` and all node versions remain installed, so rollback needs no
downloads.

## Current attribution (after both changes)

Measured by re-running `scripts/audit/run.sh` against the remediated config (variants are built
from the current `.zshrc`; the `full` figure here reads 441 ms against 387 ms standalone because
the variant pass is noisier):

| Variant | Median | Δ |
| --- | ---: | ---: |
| full | 441 ms | — |
| no pyenv | 148 ms | **−294 ms** |
| no mise | 402 ms | −39 ms |
| no p10k | 435 ms | −6 ms |
| no bash-my-aws | 438 ms | −3 ms |
| empty `.zshrc` | 17.5 ms | −424 ms |

pyenv is now the dominant cost — larger than its original 169 ms estimate because
`pyenv init --path` rewrites an already-long `PATH` and spawns `bash` to do it.

## What is still on the table

| Item | Cost | Note |
| --- | ---: | --- |
| pyenv | **~294 ms** | dominant cost; `init --path` spawns `bash` and is likely removable |
| p10k → starship | 6–35 ms | prompt change, not a speed change |
| mise `setopt` errors | — | 3 stderr lines per shell |
| bash parity | — | fresh `bash -l` has no `node` on `PATH` (pre-existing) |
| `.inputrc` | — | malformed single line; affects bash only |
| `http.sslVerify = false` | — | still in live and committed git config |

Next target is pyenv, which should land the shell near 150 ms.
