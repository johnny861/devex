# Installed utility inventory

Collected with `brew leaves`, `brew list --cask`, `mise ls`, `pipx list`, `npm ls -g`,
`cargo install --list`, and a scan of `~/.local/bin`. 86 shell-relevant installs found; the full
list with versions and which dotfile references each name is in
`raw/inventory-usage.json`.

**Usage counts are from command heads in `~/.zsh_history` only** (1053 entries, no extended
timestamps). They undercount tools reached through aliases, keybindings, or another program — the
main distortions are called out. A zero here is not proof of disuse.

## Shell-facing tools

| Tool | Version | Installed via | Loaded at startup | Direct uses | Verdict |
| --- | --- | --- | --- | ---: | --- |
| eza | 0.23.4 | brew | alias `ls` | 0 (`ls` ×102) | **keep** — carries `ls` |
| bat | 0.26.1 | brew | no | 0 | **wire up or drop** — installed, unaliased, never invoked |
| fzf | 0.67.0 | brew | `.fzf.zsh`, fzf-git | 0 (keybindings) | **keep** |
| ripgrep | 15.2.0 | brew | no | 0 | **keep** — used by editors/agents, not typed |
| git-delta | 0.18.2 | brew | git pager | 0 | **keep** |
| tree | 2.3.2 | brew | no | 0 | **retire** — `eza --tree` covers it |
| zsh-autosuggestions | 0.7.1 | brew | yes (line 80) | — | **keep** |
| zsh-syntax-highlighting | 0.8.0 | brew | yes (line 81) | — | **keep**, move last |
| powerlevel10k | 1.20.0 | brew | yes (lines 77–79) | — | **replace** with starship |
| mise | 2026.7.3 | manual `~/.local/bin` | yes (line 141) | 41 | **keep**, expand (2026.11.9 available) |
| azure-cli | 2.83.0 | brew | path + completion | 93 | **keep** — 2nd most used command |
| awscli | 2.35.15 | brew | no (bma wrapper) | 16 | **keep** |
| gh | 2.101.0 | brew | no | 4 | **keep** |
| opencode | — | manual | path | 51 | **keep** |
| timg | 1.6.3 | brew | no | 0 | **retire candidate** |
| deno | 2.6.8 | brew | no | 0 | **decision** |
| go-task | 3.37.2 | brew | no | 0 | **decision** |
| ast-grep | 0.51.1 | brew | no | 0 | **decision** — likely used by opencode |
| terraform | 1.5.7 | brew | no | 1 | **update or drop** — two minors behind |

Note: `uv` is installed twice — brew `0.9.26` and mise `0.12.19`. Pick one.

## Version managers — the real weight

| Manager | Version | Startup cost | Evidence of use | Verdict |
| --- | --- | ---: | --- | --- |
| nvm | 0.37.0 | **~691 ms** | 7 node versions installed, v26.13.0 active, 6 direct commands | **replaced** by mise 2026-11-18 |
| jenv | 0.5.9 | **~338 ms** | pins 17.0.17; 0 `jenv` commands ever | **replaced** by static `JAVA_HOME` 2026-11-18 |
| pyenv | 2.6.20 | **~177 ms** | `python` resolves to shims; `.python-version` pins 3.11.6; several virtualenvs | **keep**, drop `init --path` |
| pyenv-virtualenv | 1.2.6 | included above | venvs in use (`ansible`, `ddmk-lot`, …) | **keep** |
| mise | — | 36 ms | 41 commands; owns bun, uv, aws-cdk, aube | **keep**, become the default |
| rbenv + ruby-install | 1.3.2 / 0.9.0 | 0 ms | never initialised; `ruby` is `/usr/bin/ruby` | **retire** |
| conda (anaconda cask) | — | bash only | `python` in bash resolves to conda | **decision** — see divergence |

Consolidating nvm + jenv took startup from ~1.4 s to **387–441 ms** on 2026-11-18, before any other
work ([changes.md](../audit/changes.md)).

## Present, no shell presence

These never appear in a startup file, are not aliased, and showed no direct use. None should be
removed on this evidence alone — several are project dependencies rather than shell tools.

| Group | Packages | Note |
| --- | --- | --- |
| Duplicate PHP | `php@8.1` 8.1.33, `php@8.4` 8.4.16, `brew-php-switcher` | two minors + a switcher; pick one |
| Duplicate Java | `microsoft-openjdk@21`, `zulu11`, `zulu@11`, `zulu@17` | plus jenv pinning 17.0.17 — likely stale |
| Duplicate .NET | `dotnet-sdk`, `dotnet-sdk8`, `dotnet-sdk8-0-400` | three SDK casks |
| Local services | `httpd`, `mongosh`, `ollama`, `podman` | `brew services list` shows all stopped |
| Build/ML deps | `cmake`, `ninja`, `bison`, `ccache`, `opencv`, `cpptoml`, `googletest`, `mvfst`, `zbar`, `exif`, `qemu`, `mactex` | probably project-driven; do not guess |
| Vendor CLIs | `alpacahq/tap/cli`, `rtk-ai/tap/rtk`, `azcopy`, `sqlcmd`, `powershell` | keep only if the workflow is live |
| Language toolchains | `rust`, `rustup` (cargo bins), `maven`, `gradle`, `cocoapods`, `composer`, `ddev` | not loaded by the shell |
| Apps | `wezterm`, `orbstack`, `bruno`, `pgadmin4`, `llama-app`, `zap`, `gcloud-cli` + `google-cloud-sdk` (both) | |

## Documented but absent

| Tool | Where documented | Reality |
| --- | --- | --- |
| zoxide | `terminal/terminal-setup.md` | not installed; `alias cd="z"` also absent |

## Absent, under evaluation in Phase 2

`starship`, `fd`, `zsh-completions`, `direnv`, `atuin`, `tmux`/`zellij`, `shellcheck`, `hyperfine`,
`gitleaks`, `fast-syntax-highlighting`, `carapace`.

Rationale for each is in the plan's candidate matrix (§6.3). No more than three should land.
