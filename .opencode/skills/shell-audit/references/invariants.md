# Shell config invariants

Rules that have been paid for with measured regressions. Check these before and after any change.

## Loading

- [ ] `~/.zshenv` is non-interactive-safe and **idempotent**. It runs for scripts and nested
      shells; every unconditional `PATH` append is multiplied by every `zsh` started.
- [ ] `~/.zshrc` does not depend on `~/.zprofile` having run. Non-login shells skip it; a
      `brew shellenv`-dependent line in `.zshrc` breaks IDE tasks and `zsh -c`.
- [ ] `compinit` and `bashcompinit` are explicit, before anything that registers completions
      (gcloud, bash-my-aws, fzf).
- [ ] `zsh-syntax-highlighting` is sourced **last**.
- [ ] The transient-prompt plugin (when adopted) is sourced **before** syntax highlighting;
      it binds `zle-line-finish` with `zle -N`, which replaces the highlighter's hook chain.

## PATH

- [ ] One owner per entry: `~/.local/bin` belongs to `~/.zshenv` only.
- [ ] Entries are added only when absent (`[[ ":$PATH:" == *":$dir:"* ]] || PATH=...`).
- [ ] `~/.zshrc` ends with `typeset -U path; path=($path)`.
- [ ] `$JAVA_HOME/bin` is re-fronted after later prepends, or `java` resolves through the
      `/usr/bin/java` stub instead of the selected JDK.
- [ ] `print -rl -- ${(s.:.)PATH} | sort | uniq -d` prints nothing in a clean shell
      (`env -i HOME=$HOME TERM=dumb zsh -c ...`).

## Runtime selection

- [ ] Java: `JAVA_HOME` in `~/.zshenv` (visible to scripts). Per-project JDKs belong in the
      project (`org.gradle.java.home` or a mise config), never in the shell.
- [ ] Node: mise. `.nvmrc` / `.node-version` require
      `mise settings set idiomatic_version_file_enable_tools node`.
- [ ] Python: pyenv shims plus `.python-version`. Do not remove pyenv without confirming that
      `python` still resolves where expected.
- [ ] nvm and jenv are retired. Reinstalling either reintroduces ~1 s of startup cost that the
      audit removed; see `audit/changes.md`.

## History

- [ ] `SHARE_HISTORY`, `EXTENDED_HISTORY`, `HIST_IGNORE_SPACE` stay enabled; the audit relies on
      timestamps for time-window analysis.
- [ ] `HIST_IGNORE_ALL_DUPS` prunes repeats on read. It never removes a distinct command, but it
      does shrink the file; do not "fix" that by disabling it without a replacement.

## Secrets

- [ ] No credential values in any tracked file. `~/.config/secrets.env` is untracked and
      optional (`[[ -r ... ]] && . ...`).
- [ ] `.env` reads ask; `~/.aws/credentials`, `~/.ssh/*` and `~/.config/secrets.env` are denied
      to agents by `opencode.jsonc`.

## Docs

- [ ] A config change and its guide change ship together (`terminal/terminal-setup.md`).
- [ ] Repo copies match the live files. Verify with `/drift`.
