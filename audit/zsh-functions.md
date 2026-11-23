# Shell functions review (`~/.zsh`)

Scope: `~/.zsh/autoload.zsh` and every file in `~/.zsh/zfunctions/`. Method: read each file,
traced where the functions actually come from at runtime (`whence -w`), and checked 1053 history
entries for real use. Consolidated copies now live in
[`../terminal/shell/`](../terminal/shell/).

## Inventory before

| File | Lines | Defines | Loaded by |
| --- | ---: | --- | --- |
| `autoload.zsh` | 17 | loader | sourced from `.zshrc:126` |
| `zfunctions/aws.zsh` | 59 | `aws-profiles`, `asp`, `asr`, `alp` | the loader |
| `zfunctions/selectoptions.zsh` | 183 | `selectoptions` | the loader |
| `zfunctions/sg-functions.zsh` | 273 | `sg-rule-add`, `sg-rule-remove`, `sg-rules` + 3 private | the loader |
| `zfunctions/shared-bma-functions.zsh` | 90 | `skim-stdin`, `columnise`, `__bma_error`, `__bma_usage`, `__bma_read_inputs`, `__bma_read_stdin`, `__bma-using-aws-cli-v1` | the loader |

## Findings

### Redundancy and dead weight

1. **`shared-bma-functions.zsh` existed to provide three helpers.** Of its seven functions:
   `skim-stdin` is never called by any zsh file; `__bma_read_inputs` and `__bma_read_stdin` are
   labelled "deprecated" in their own comments; `__bma-using-aws-cli-v1` is unused. Only
   `__bma_error`, `__bma_usage` and `columnise` were reachable (from `sg-functions.zsh`).
   The file is also a partial copy of `~/.bash-my-aws/lib/shared-functions`, so it would drift.
2. **`autoload.zsh` set `FPATH` for a directory it then sourced.** Nothing is autoloaded from
   `~/.zsh/zfunctions`, so the `FPATH` entry was inert.
3. **The repo copy was not loadable.** `terminal/shell/functions/selectoptions.sh` had a `.sh`
   extension while the loader globs `*.zsh`, and its content was 154 lines against 182 live.
   Installing it as-is would have silently produced no `selectoptions`.
4. **`~/.bash-my-aws/bin/aws-profiles` is shadowed** by the zsh function of the same name.
   Harmless, but it is now dead weight on `PATH`.

### Bugs

| # | Where | Bug | Impact |
| ---: | --- | --- | --- |
| 1 | `selectoptions` | The first argument was assigned to `option_type` *before* the option loop, then reprocessed by it, so the same word became the `action`. | `cmd \| selectoptions FOO` — documented to print the value — instead ran a command named `FOO`. Masked because all 11 historical uses pass `--mise`, which returns before the action branch. |
| 2 | `selectoptions` | Fallback mode ran `exec < /dev/tty`. | Permanently replaced the calling shell's stdin, not just the menu's. |
| 3 | `selectoptions` | Help advertises `[-m]`; only `--mise` was implemented. | `-m` was rejected as an unknown flag. |
| 4 | `selectoptions` | Action invoked as unquoted `$action "$opt_val"`. | Multi-word commands worked by accidental word splitting; a quoted command with arguments could not work at all. |
| 5 | `aws.zsh` | `profiles=` and `available_profiles=` not declared `local`. | Leaked into the session environment. |
| 6 | `aws.zsh` | `if [[ $? -ne 0 ]]` after a pipeline; unquoted `echo $profiles`; `grep -w`. | Fragile status handling, word-splitting/globbing, and substring matches on profile names. |
| 7 | both | `fallback_opt`, `split_items` used without declaration. | Leaked into the session. |

### Gaps

- **bash-my-aws is effectively inert in zsh.** `source ~/.bash-my-aws/aliases` is commented out
  (`.zshrc:122`), and `~/.bash-my-aws/bin` contains only 6 scripts — `instances`, `stacks` and the
  rest are not resolvable. What remains is a `PATH` entry, the `BMA_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT`
  variable, and `bash_completion.sh`. Either load `aliases` or remove the three lines.
- **`AWS_REGION` is set by `asr` but not by `~/.zshenv`**, which only sets `AWS_DEFAULT_REGION`.
  A fresh shell and a post-`asr` shell therefore differ in which variables exist.
- **None of these functions exist in bash.** A `bash -l` session has no `asp`, `selectoptions` or
  `sg-*`. Part of the broader bash-parity decision.
- **`selectoptions` index is 1-based**, and `--index 0` silently keeps the whole line. Preserved
  rather than fixed, because it changes what gets stored by `--mise`; now documented in `--help`.
- **No tests.** `sg-*` mutate AWS resources. `--dry-run` exists but nothing exercises it.

## What changed

| Before | After |
| --- | --- |
| 5 files, 622 lines | 4 files, ~470 lines |
| `zfunctions/` | `functions/` (matches the repo layout) |
| `shared-bma-functions.zsh` (90 lines) | deleted; 3 helpers inlined as `__sg_*` |
| `selectoptions.sh`, stale, never loaded | `selectoptions.zsh`, synced and fixed |
| `FPATH` + source-everything | source-everything only |

`sg-functions.zsh` still honours `BMA_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT`, so piped output
behaviour is unchanged.

## Verification

| Check | Result |
| --- | --- |
| All files pass `zsh -n` | yes |
| Loader picks up all four functions in a fresh shell | `selectoptions`, `asp`, `asr`, `alp`, `aws-profiles`, `sg-rules`, `sg-rule-add`, `sg-rule-remove` |
| `columnise` (the bma dependency) is gone | `whence -w columnise` → none |
| `selectoptions` default mode prints instead of executing | `printf 'a\nb\n' \| selectoptions VAR` → `b` |
| Action receives the value as the final argument | `... \| selectoptions VAR printf '%s!'` → `b!`; with flags: `print -r -- PRE` → `PRE b` |
| `--delimiter $'\t' --index 2` | returns field 2; `--index 0` keeps the whole line |
| `-h` exits 0; missing argument and empty stdin exit 1 | yes |
| `asp` with no args clears and returns 0; unknown profile returns 1 | yes |
| `asr eu-west-1` sets both region variables | yes |
| `aws-profiles` lists `default`, `j861`, `vektor`, `stars` | yes |
| `__sg_ip_permissions tcp 8000-8080 0.0.0.0/0 https` | valid JSON with `FromPort`/`ToPort`/`IpRange` |
| `sg-rules` with no ids prints usage and exits 1 | yes |
| Startup time | 373 ms (unchanged) |

## Open decisions

1. **bash-my-aws:** load `aliases` (restores `instances`, `stacks`, …) or remove the `PATH`,
   `BMA_*` variable and completion source. Current state is the worst of both.
2. **`selectoptions` index:** keep 1-based (current, and what existing stored values were produced
   with) or switch to 0-based with a migration note.
3. **Function parity in bash:** mirror these in `.bashrc`, or document zsh as the only supported
   interactive shell.
