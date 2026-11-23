# Terminal Setup — WezTerm + zsh (macOS)

What is actually on this machine today. Every version and setting here was verified against the
live configuration; the measurements behind the decisions are in [`../audit/`](../audit/README.md)
and the migration work in progress is in
[`shell-modernization-plan.md`](shell-modernization-plan.md).

Stack: WezTerm, zsh 5.9 (system), no oh-my-zsh, no framework. mise + pyenv for runtimes, Powerlevel10k
for the prompt (Starship migration planned), fzf/eza/bat/ripgrep/delta for the shell.

## 1. Fonts and terminal

```sh
brew install font-meslo-lg-nerd-font
brew install --cask wezterm
cp terminal/.wezterm.lua ~/.wezterm.lua
```

The config sets MesloLGS Nerd Font Mono at 14 pt, 0.8 background opacity with macOS blur, and adds
three keybinds on top of the defaults:

| Keys | Action |
| --- | --- |
| `CMD-d` | split pane horizontally |
| `CMD-SHIFT-d` | split pane vertically |
| `CMD-SHIFT-Backspace` | clear the screen |

WezTerm reloads the config when the file is saved.

## 2. Shell files

zsh reads these in order; each has one job:

| File | Runs | Holds |
| --- | --- | --- |
| `~/.zshenv` | every zsh process | `PATH` (idempotent, one owner per entry), AWS profile/region, secrets hook |
| `~/.zprofile` | login shells | `brew shellenv`, OrbStack, dotnet/ByteBlower paths |
| `~/.zshrc` | interactive shells | completion, history, tools, plugins, prompt, aliases |
| `~/.zsh/autoload.zsh` | sourced by `.zshrc` | loads `~/.zsh/functions/*.zsh` |

Rules that keep startup honest:

- `.zshenv` must be idempotent. It runs for scripts and nested shells too, so an unconditional
  `PATH` append multiplies with every `zsh` you start. Add entries with an "only if absent" guard.
- `.zshrc` must not depend on `.zprofile` having run. Non-login shells (IDE tasks, `zsh -c`) skip
  `.zprofile`.
- Nothing in `.zshrc` should call `compinit` implicitly. It is explicit, right after the toolchain
  block, together with `bashcompinit` for bash-style completions.

## 3. Runtimes: mise, pyenv

Deliberately split, not accidental:

```sh
brew install mise pyenv pyenv-virtualenv

mise use -g node@26.13.0 bun@latest uv@latest
mise settings set idiomatic_version_file_enable_tools node   # honour .nvmrc / .node-version
```

- **mise** owns node, bun, uv and npm CLIs. `mise activate zsh` runs at the end of `.zshrc`.
- **pyenv** owns Python, because `python` resolves through its shims and projects pin versions with
  `.python-version`.

nvm and jenv were removed (November 2026): together they cost ~1 s per shell to resolve versions
that never changed. Java is a static `JAVA_HOME` pointing at `zulu-17.jdk`.
See [`../audit/changes.md`](../audit/changes.md) for the diffs and rollback.

## 4. CLI utilities

```sh
brew install eza bat ripgrep fzf git-delta tree
brew install zsh-autosuggestions zsh-syntax-highlighting
```

| Tool | Used for |
| --- | --- |
| eza | `ls`/`ll`/`la` via alias |
| bat | `cat` replacement (wire into `MANPAGER` if you want it) |
| ripgrep | search, also used by editors and agents |
| fzf | `Ctrl-R`, `Ctrl-T`, `Alt-C`, plus `fzf-git` |
| git-delta | pager for diffs |
| zsh-autosuggestions | inline history suggestions |
| zsh-syntax-highlighting | command colouring; must be sourced last |

**zoxide is not installed.** `cd` is plain zsh. If you want jump-to-directory, either
`setopt AUTO_PUSHD` plus `cdr`, or install zoxide and wire it explicitly — do not add an alias
that points at a binary that is not there (the previous version of this guide did exactly that).

```zsh
# aliases that pair with the tools above
alias ls="eza --icons=always"
alias ll="ls -l"
alias la="ls -la"
```

## 5. Prompt

Powerlevel10k is the current prompt (`~/.p10k.zsh`, also kept at `terminal/.p10k.zsh`). The
migration to Starship, including keeping the transient prompt with a vendored plugin, is specified
in [`shell-modernization-plan.md`](shell-modernization-plan.md) §7. Do not install Starship until
that section's sequencing is followed: the version-manager work is what buys the speed.

## 6. Shell functions

```sh
mkdir -p ~/.zsh/functions
cp terminal/shell/autoload.zsh    ~/.zsh/autoload.zsh
cp terminal/shell/functions/*.zsh ~/.zsh/functions/
```

Files must end in `.zsh`; the loader globs `*.zsh` and sources each file. Currently provided:

| Function | Purpose |
| --- | --- |
| `selectoptions` | pick one value from piped input (fzf or `select`), then print it, run a command with it, or `mise set` it |
| `aws-profiles`, `asp`, `asr`, `alp` | list/set AWS profile and region for the session |
| `sg-rules`, `sg-rule-add`, `sg-rule-remove` | inspect and modify EC2 security group rules, pipe-friendly, with `--dry-run` |

Examples:

```sh
az account list --query "[].{id:id,name:name}" --output tsv \
  | selectoptions AZ_ACCOUNT_DEV --delimiter $'\t' --index 2 --mise

asp prod                       # set AWS_PROFILE/AWS_DEFAULT_PROFILE
instances wordpress | instance-sg | sg-rule-add tcp 443 0.0.0.0/0 "https" | sg-rules
```

Changes and verification for the function library are in
[`../audit/zsh-functions.md`](../audit/zsh-functions.md).

## 7. Git

```sh
brew install git git-delta
```

```gitconfig
[core]
    editor = code --wait
    pager = delta
[interactive]
    diffFilter = delta --color-only
[delta]
    navigate = true
    side-by-side = true
[merge]
    conflictstyle = diff3
[diff]
    colorMoved = default
```

The full sample is at [`../guides/conf/.gitconfig`](../guides/conf/.gitconfig).

## 8. Verify

```sh
zsh -n ~/.zshenv ~/.zshrc ~/.zprofile
scripts/audit/after.py                 # startup median, should be ~0.4 s
scripts/audit/run.sh                   # full audit, writes audit/raw/
printf '%s\n' $PATH | tr ':' '\n' | sort | uniq -d    # should print nothing
```

Targets and current status are in the before/after table of
[`shell-modernization-plan.md`](shell-modernization-plan.md) §9.
