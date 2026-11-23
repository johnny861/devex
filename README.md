# DevEx Resources

A collection of developer tooling, guides, cheat sheets, and dotfile/config
files.

## Contents

### Guides

| Guide |  |
| --- | --- |
| [guides/aws-cli-commands.md](guides/aws-cli-commands.md) | aws-cli cheat sheet — install and common commands. |
| [guides/git.md](guides/git.md) | git cheat sheet — aliases and workflows (companion to `.gitconfig`). |
| [guides/tar-commands.md](guides/tar-commands.md) | tar cheat sheet — create, inspect, extract, and encrypt archives. |
| [terminal/terminal-setup.md](terminal/terminal-setup.md) | WezTerm + zsh setup: mise/pyenv, CLI utilities, prompt, shell functions (macOS). |

### Shell

| Doc |  |
| --- | --- |
| [terminal/shell-modernization-plan.md](terminal/shell-modernization-plan.md) | Audit → research → migration plan: Powerlevel10k to Starship, version-manager consolidation. |
| [audit/README.md](audit/README.md) | Measured baseline: startup attribution, load order, tool inventory, usage, correctness checks. |
| [audit/changes.md](audit/changes.md) | Applied changes with before/after numbers and rollback. |
| [audit/zsh-functions.md](audit/zsh-functions.md) | Review of the shell function library and what was consolidated. |
| [scripts/audit/run.sh](scripts/audit/run.sh) | Regenerates `audit/raw/*` (startup timing, inventory, checks). |

### Config files

| File |  |
| --- | --- |
| [guides/conf/.gitconfig](guides/conf/.gitconfig) | Git config with aliases → `~/.gitconfig` |
| [terminal/.wezterm.lua](terminal/.wezterm.lua) | WezTerm config → `~/.wezterm.lua` |
| [terminal/.p10k.zsh](terminal/.p10k.zsh) | Powerlevel10k config → `~/.p10k.zsh` |
| [terminal/shell/autoload.zsh](terminal/shell/autoload.zsh) | Shell function loader → `~/.zsh/autoload.zsh` |
| [terminal/shell/functions/](terminal/shell/functions) | Shell functions → `~/.zsh/functions/` |
| [terminal/setup.zsh](terminal/setup.zsh) | Installs the shell config into `~/.zsh` |
