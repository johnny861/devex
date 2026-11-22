# Shell & Terminal Modernization — Audit and Migration Plan

Status: draft · Scope: macOS host, zsh (interactive) + bash (occasional), WezTerm
Goal: replace Powerlevel10k with Starship, and put the rest of the shell tooling on a
deliberate, measured footing instead of accumulated `>> ~/.zshrc` edits.

---

## 1. Objectives and non-goals

Objectives

1. Retire Powerlevel10k (and its `gitstatus` daemon) in favor of Starship with feature parity
   where it matters and an explicit, written list of accepted gaps.
2. Produce a **verified inventory** of shell startup files, installed CLI utilities, and version
   managers — current, not reconstructed from the docs.
3. Cut interactive shell startup time measurably (baseline today: **~1.4 s**; target **< 300 ms**).
4. Make this repo the source of truth for the shell config, so docs cannot drift again.
5. Leave a repeatable audit/benchmark harness (`make audit`, `make bench`) that can be re-run
   quarterly.

Non-goals (this pass)

- Switching shells (no fish/nushell migration). zsh stays.
- Replacing WezTerm or its Lua config unless the audit surfaces a concrete problem.
- Rewriting `~/.bash-my-aws` or the AWS workflows built on it.
- Cleaning up every Homebrew formula on the machine. Only what the shell loads or aliases.

---

## 2. Verified current state (baseline)

Captured 2026-11-18 on this host. Re-verify at the start of Phase 0; these numbers are the
"before" side of the before/after table in §9.

### 2.1 Startup files

| File | Lines | Role today |
| --- | --- | --- |
| `~/.zshenv` | 18 | Android SDK vars, cargo env, AWS profile, **plaintext API key**; also re-sourced from `.zshrc` |
| `~/.zprofile` | 19 | brew shellenv, pipx/dotnet/ByteBlower PATH, OrbStack init |
| `~/.zshrc` | 142 | everything else: p10k, pyenv, nvm, jenv, pnpm, gcloud, bun, bash-my-aws, fzf, mise, aliases |
| `~/.zsh/autoload.zsh` | 17 | sources `~/.zsh/zfunctions/*.zsh` |
| `~/.zsh/zfunctions/` | 4 files | `aws.zsh`, `selectoptions.zsh`, `sg-functions.zsh`, `shared-bma-functions.zsh` |
| `~/.bash_profile` | 20 | conda init, PATH additions, cargo env |
| `~/.bashrc` | 1 | fzf only |
| `~/.profile` | 1 | cargo env (third load of the same file) |
| `~/.inputrc` | 2 | readline settings — appears to put several directives on one line |
| `~/.p10k.zsh` | 1827 | live p10k config |
| `~/.wezterm.lua` | — | font, opacity, blur; no `default_prog` |

### 2.2 Measured facts

Full detail and reproduction in [`audit/`](../audit/README.md).

| Metric | Value | Note |
| --- | --- | --- |
| `zsh -i -c exit` | **1.36–1.42 s** (two 20-run passes) | warm |
| `zsh -f -c exit` | ~6 ms | no rc files |
| Empty `.zshrc` | ~17 ms | everything above this is config |
| Version managers | **~1.27 s** | nvm 675, jenv 329, pyenv 169, mise 40 ms |
| Powerlevel10k | **9–35 ms** | not the startup problem |
| `compinit` | not isolated; ~67 ms residual covers it + plugins | never called by the config; runs from nvm's bash completion |
| `PATH` entries | **33, 6 duplicated paths (clean shell)**; 82/14 in a used session | `.zshenv` appends 4 Android paths and is sourced twice |
| Functions defined at startup | 1739 | mostly bash-my-aws + completion system |
| `compdef` available | yes, **but no `compinit` in any dotfile** | loaded incidentally via nvm |
| History options | none set in dotfiles | no `SHARE_HISTORY`, `EXTENDED_HISTORY`, or `INC_APPEND_HISTORY`; no timestamps in the 33 KB file |
| `gitstatus` | **fails to initialize** on startup | p10k cannot render git status reliably |
| Alias count | 13 | `ls`, `ll`, `la`, `gitb`, `ipinfo`, `7z`, … |
| Syntax | all 11 startup/zfunction files parse | defects are semantic, not syntactic |

### 2.3 Tooling present vs. documented

Installed and used: `eza`, `bat`, `git-delta`, `fzf 0.67`, `ripgrep 15.2`, `tree`, `powerlevel10k`,
`zsh-autosuggestions`, `zsh-syntax-highlighting`, `mise`, `pyenv`+`virtualenv`, `nvm`, `jenv`,
`rbenv`+`ruby-install`, `conda` (bash only), `uv`, `pipx`, `pnpm`, `bun`, `rustup`, `deno`, OrbStack.

Documented but **not installed**: `zoxide` (and the documented `alias cd="z"` therefore does not
exist). Referenced in commented-out config: `fd` — also not installed.

Installed but shell-unused (candidates for retirement, subject to usage evidence): `tree`
(superseded by `eza --tree`), `timg`, `httpd`, `mongosh` (if no local mongo work), duplicate
`php@8.1`/`php@8.4`, duplicate dotnet SDK casks, `zulu11` vs `zulu@11` vs `zulu@17`.

Not installed, deliberately under evaluation: `starship`, `fd`, `direnv`, `atuin`, `tmux`/`zellij`,
`shellcheck`, `hyperfine`, `zoxide`, `fast-syntax-highlighting`, `carapace`.

### 2.4 Doc drift (why the plan exists)

| Doc claim | Reality |
| --- | --- |
| `terminal/terminal-setup.md` installs zoxide and `alias cd="z"` | zoxide not installed, alias absent |
| `terminal/.pk10.zsh` → copy to `~/` as p10k config | Real file is `~/.p10k.zsh`; the committed name is a typo and would never load |
| Committed `.pk10.zsh` matches live config | Differs (1826 vs 1827 lines) |
| Setup guide ends at p10k + 4 tools | `.zshrc` also loads mise, bun, uv, pnpm, jenv, pyenv, nvm, OrbStack, bash-my-aws, opencode |
| README lists sample `.gitconfig` as the copy-to-home source | Home config has drifted (`editor = code --wait`, extra aliases) |
| No mention of secrets handling | `SAKANA_API_KEY` is exported in plaintext from `~/.zshenv` |

**Risk to close early:** that key is in a dotfile that gets copied, screenshotted, and possibly
committed. Rotate it and move it to a secret store or a `chmod 600` `~/.config/secrets.env`
sourced only when present. Treat as Phase 0 work, not Phase 5.

---

## 3. Method

Four rules, applied to every change in this plan:

1. **Evidence before edits.** No tool is added, replaced, or removed without a recorded reason
   (startup cost, benchmark, actual usage in history, or a documented feature gap).
2. **One variable per commit.** Every change is a separate commit in this repo, so any regression
   is bisectable and revertible.
3. **Measure twice.** Every phase records numbers in the §9 table before and after.
4. **Reversible.** Nothing is deleted from `~/` until its replacement has survived one week of
   normal use. Old config is archived under `archive/` in this repo, not in `~/`.

---

## 4. Phase 0 — Baseline and inventory (≈1 session)

**Status: complete (2026-11-18).** Results in [`audit/`](../audit/README.md). Headline: p10k
costs 9–35 ms of a ~1.36 s startup; nvm alone costs ~675 ms, jenv ~329 ms, pyenv ~169 ms. The
< 300 ms target is reached by version-manager work, not by the prompt change. `compinit` is a
side effect of nvm, not of the config. Reproduce with `scripts/audit/run.sh`.

Remediation applied the same day ([`audit/changes.md`](../audit/changes.md)): nvm → mise,
jenv → static `JAVA_HOME`. **Startup is now 387–441 ms** (login ~430 ms), with a one-line rollback.

Output: `audit/` artifacts committed to this repo.

### 0.1 Startup baseline

```sh
# warm timing, statistical
hyperfine --warmup 5 --runs 20 'zsh -i -c exit' 'zsh -f -c exit' --export-json audit/startup.json

# per-file cost: comment out blocks cumulatively in a scratch copy of .zshrc
ZDOTDIR=$PWD/audit/zdotdir zsh -i -c exit
```

Use `zsh -x` (or `PS4='+%D{%s.%N} '`) into a log to attribute wall time per sourced file.
Record the top five offenders; expect pyenv `init`, nvm, p10k `gitstatus`, and mise activation.

### 0.2 File and load-order map

- List every file zsh reads, in order, and every file those source transitively
  (`grep -nE '^\s*(source|\.)\s'` across all of them, resolved to a tree).
- Flag: double-sourcing (`~/.zshenv` from `.zshrc`), triple cargo env, conda in bash only,
  `bashcompinit` commented out while bash-my-aws completions are sourced.
- Produce `audit/load-order.md` with the tree and the owner of each variable it exports.

### 0.3 Installed utility inventory

Collect into `audit/inventory.md` (and a CSV for sorting):

```sh
brew leaves; brew list --versions; brew list --cask
mise ls --global; mise ls
npm ls -g --depth=0; pipx list --short; cargo install --list
ls ~/.local/bin ~/bin /usr/local/bin 2>/dev/null
```

For each entry record: version, how installed (brew/cask/mise/npm/pipx/cargo/manual),
what loads it at startup, and last-used evidence from §0.4. Anything with no loader and no
usage in 90 days is a retirement candidate — not an automatic removal.

### 0.4 Usage telemetry

The point is to stop guessing which aliases and tools matter.

```sh
# top commands, all history
fc -R ~/.zsh_history 2>/dev/null; history 1 | awk '{print $2}' | sort | uniq -c | sort -rn | head -40

# who actually uses the "modern" tools
for c in eza ls bat cat fd find rg grep zoxide cd git delta tree; do
  printf '%-8s %s\n' "$c" "$(grep -cE "(^| )[^ ]*${c}( |$)" ~/.zsh_history)"
done
```

Deliverable: a keep/replace/retire column in the inventory, each with a reason.

### 0.5 Correctness and risk checks

```sh
zsh -n ~/.zshrc ~/.zshenv ~/.zprofile ~/.zsh/autoload.zsh   # syntax
bash -n ~/.bashrc ~/.bash_profile ~/.profile
shellcheck ~/.zsh/zfunctions/*.zsh 2>/dev/null || true      # install shellcheck first
printf '%s\n' "$PATH" | tr ':' '\n' | sort | uniq -cd       # duplicate PATH
gitleaks detect --no-git --source ~ --verbose               # secrets in dotfiles
```

Also record: interactive-only breakage (`monitor`/`zle` errors when non-interactive), the
`gitstatus` failure, and whether completion still works in a fresh shell.

---

## 5. Phase 1 — Configuration audit (≈1 session)

Audit the config itself, independent of which tools win.

### 5.1 Structure

Current `.zshrc` mixes environment, PATH, plugin loading, prompt, and aliases in one 142-line
file with ordering hazards (mise activated last, after the prompt and plugins). Proposed layout,
sourced in lexical order from `.zshrc`:

```
shell/
  zshenv        # non-interactive env only: PATH core, AWS, language roots
  zprofile      # login-only: brew shellenv, OrbStack
  zshrc         # orchestrator: compinit, conf.d/*, prompt, plugins (ordered)
  conf.d/
    00-options.zsh      # setopt block, history, keybindings
    10-path.zsh         # PATH assembly, one function, dedup at the end
    20-completion.zsh   # compinit, zstyles, completion caches
    30-tools.zsh        # mise, pyenv/nvm/jenv (if kept), zoxide, direnv, fzf
    40-plugins.zsh      # autosuggestions, syntax-highlighting (last)
    50-prompt.zsh       # starship init
    90-aliases.zsh      # aliases + small functions
```

### 5.2 Specific defects to resolve

| Item | Finding | Decision needed |
| --- | --- | --- |
| PATH | **fixed 2026-11-22**: entries added only when absent, `~/.local/bin` single owner, dedupe pass at end of `.zshrc` | Clean shell 25 entries / 0 dupes; interactive 49 / 0 |
| Version managers | pyenv, nvm, jenv, rbenv, conda, mise, uv, pipx, pnpm all active or half-active | nvm and jenv replaced 2026-11-18; pyenv/conda/rbenv still open (see §7) |
| Completion | No `compinit` in dotfiles; it runs only because nvm's `bash_completion` calls it | **fixed 2026-11-18**: explicit `compinit` + `bashcompinit`, independent of nvm |
| History | No options set; `HISTSIZE` unowned | **fixed 2026-11-22**: `SHARE_HISTORY`, `EXTENDED_HISTORY`, no-dup options, `HIST_IGNORE_SPACE`, 50k entries |
| bash parity | conda in `.bash_profile`, absent from zsh; cargo env 3× | Decide whether bash is a real workflow or a fallback; if fallback, make it minimal and document it |
| `.inputrc` | Multiple directives on one line; only affects bash/readline | Fix or delete (zsh ignores it) |
| Secrets | `SAKANA_API_KEY` in `.zshenv` | **fixed 2026-11-22**: rotated by user, export removed, untracked `~/.config/secrets.env` hook added |
| Git | `http.sslVerify = false` in live *and* committed config | Confirm intent; scope to a host if truly needed |
| Dead code | Large commented pyenv/conda/android blocks | Delete; git history is the archive |

---

## 6. Phase 2 — Research and evaluation (≈1 session)

### 6.1 Rubric

Score every candidate 1–5 on: startup cost, per-invocation latency, maintenance activity
(last release, open critical issues), Homebrew/mise installability, config surface, reversibility,
and overlap with something already installed. A tool must beat the current one on at least one
axis and lose on none that matter.

### 6.2 Benchmark protocol

```sh
hyperfine --warmup 3 --runs 20 \
  'find . -maxdepth 3 | wc -l' 'fd --max-depth 3 | wc -l'
hyperfine --warmup 3 --runs 20 'ls -R >/dev/null' 'eza -R >/dev/null'
hyperfine --warmup 3 --runs 20 'starship prompt' 'starship module git_status'
```

For prompt work specifically: `starship timings` (per-module), and time-to-first-prompt in a
fresh WezTerm window (not just `zsh -c exit`).

### 6.3 Candidate matrix (starting point, to be confirmed by measurement)

| Category | Current | Candidates | Default inclination |
| --- | --- | --- | --- |
| Prompt | p10k + gitstatus | **starship**, oh-my-posh, pure | starship (decision already made) |
| Directory jump | none | zoxide, `cdr`/`AUTO_PUSHD` | zoxide if usage justifies; else plain `AUTO_PUSHD` |
| `ls`/`find`/`grep` | eza, (none), rg | eza (`--tree`), fd | keep eza, rg; add fd only if `find` usage is high |
| File preview | bat | bat (+ `MANPAGER`, `BAT_THEME`) | keep, wire into fzf previews |
| Fuzzy find | fzf 0.67 | fzf (`--tmux`), skim | keep fzf; modernize integration (`fzf --zsh`) |
| History search | Ctrl-R (readline) | fzf history, atuin, mcfly | fzf-based first; atuin only if cross-machine sync wanted |
| Completions | incidental compinit | zsh-completions, carapace | explicit compinit + zsh-completions; carapace only if needed |
| Highlighting | zsh-syntax-highlighting | fast-syntax-highlighting | benchmark; keep if no clear win (ordering constraints) |
| Autosuggest | zsh-autosuggestions | zsh-autocomplete | keep; do not stack both |
| Env/direnv | none | direnv, mise env | direnv only if per-project env is a real workflow |
| Multiplexer | none | tmux, zellij | skip unless remote/persistent sessions are needed (WezTerm domains cover local) |
| Extra `ls`-alikes | tree | dust, duf, procs | skip; avoid bloat |
| Shell itself | zsh 5.9 (system) | brew zsh | keep system unless a 5.9.1 feature is needed |
| bash | 3.2 (system) | brew bash 5 | decide based on whether bma scripts need 4+ |

Rule: at most **three** new tools land in this pass beyond starship. Everything else goes to a
"considered, deferred" table with the reason — that table is what keeps the next audit honest.

---

## 7. Phase 3 — Powerlevel10k → Starship migration

### 7.1 Feature parity map

Derive this from `~/.p10k.zsh` (the wizard answers recorded in `terminal-setup.md`: rainbow,
unicode, 24h time, round separators, 1-line, sparse, many icons, concise, transient prompt on).

| p10k element | Starship equivalent | Notes |
| --- | --- | --- |
| Left prompt: dir, git branch/status, aws, kube, node/python | `$directory`, `$git_branch`, `$git_status`, `$aws`, `$kubernetes`, `$nodejs`, `$python` | Watch `$aws` cost — it can invoke the credential process |
| Right prompt: time (24h) | `right_format = '$time'` + `[time] time_format = "%R"` | Set `ZLE_RPROMPT_INDENT=0` for alignment |
| Rainbow/round separators | `[directory] style`, `format` with `\ue0b0` etc. | Reproduce the look, not the exact theme |
| Transient prompt | **no native zsh support** | Gap — see 7.3 |
| Instant prompt | n/a | Replaced by fixing startup time; starship renders in ms |
| `p10k configure` | `starship preset <name>` + hand edits | Pick a preset, then tune |
| vi-mode indication | `$character` with `vimcmd_symbol`/`vicmd` | Requires `bindkey -v` decision |

### 7.2 Steps

1. `brew install starship` (do **not** remove `powerlevel10k` yet).
2. Generate `~/.config/starship.toml` from a preset, then map the table above. Commit it as
   `shell/starship.toml` here.
3. Create `shell/conf.d/50-prompt.zsh` containing `eval "$(starship init zsh)"`,
   `ZLE_RPROMPT_INDENT=0`, and the vendored transient-prompt plugin (§7.3). Source order:
   `compinit` → tools → prompt + transient plugin → `zsh-syntax-highlighting` (always last).
   Verify keybindings still work.
4. Comment out the p10k instant-prompt block (`~/.zshrc` lines 1–6), the theme source, and the
   `~/.p10k.zsh` source. Keep the files.
5. Run both prompts side by side for one week via a `STARSHIP=0/1` switch or a git branch.
6. Only then: `brew uninstall powerlevel10k`, archive `.p10k.zsh` under `archive/`,
   delete the p10k references from the docs.

### 7.3 Known gaps and how to handle them

- **Transient prompt — decision: keep it.** Implement with
  [`olets/zsh-transient-prompt`](https://github.com/olets/zsh-transient-prompt) vendored at a
  pinned version (MIT, ~90 lines, derived from p10k's algorithm). It snapshots `PROMPT`/`RPROMPT`
  at load and swaps in the transient pair from a `zle-line-finish` widget, which works with
  starship's command-substitution prompt.
  - **Load it before `zsh-syntax-highlighting`.** The plugin binds `zle-line-finish` with
    `zle -N`, replacing any existing widget. Loaded last, it silently drops the highlighter's
    `add-zle-hook-widget` chain; loaded first, zsh preserves the plugin's widget and calls both.
  - Use native escapes (`%(?.%F{green}.%F{red})❯%f`) rather than `$(starship module character)`:
    no extra process per command, and it can see the previous exit status.
  - Set the transient right prompt explicitly. It defaults to the full `RPROMPT`, which is what
    keeps the timestamp in scrollback (`TRANSIENT_PROMPT_TRANSIENT_RPROMPT='%F{242}%D{%H:%M:%S}%f'`).
  - Cost: one extra prompt render per accepted command; measure it in Phase 4.
- **Instant prompt.** Real fix is the §4 startup work; a 1.4 s shell makes any prompt feel slow.
- **Per-prompt fork.** Starship shells out per render. Measure with `starship timings`; disable
  `git_status` in very large repos, raise `command_timeout`, and avoid `$aws` if it stalls.

### 7.4 Rollback

Branch `shell/starship` in this repo, p10k files untouched in `~/`, uninstall deferred to step 6.
Rollback = comment one line in `50-prompt.zsh` and uncomment the p10k block.

---

## 8. Phase 4 — Implementation and validation

Sequence (one commit each):

1. Archive current live configs into `archive/2026-11-18/` (so the repo matches reality).
2. Introduce the `shell/` layout with **behavior-preserving** content; verify startup time is
   within noise of baseline.
3. Fix defects from §5.2 (PATH dedup, compinit, history options) — measure after each.
4. Add starship per §7; measure prompt render and total startup.
5. Add at most three evaluated tools; measure and record.
6. Update `terminal/terminal-setup.md` and `README.md` to match, delete/replace stale claims,
   fix the `.pk10.zsh` filename bug.
7. Add `make audit` / `make bench` targets wrapping the commands in §0 and §6.

Validation checklist (each item green before the phase closes):

- Fresh WezTerm window reaches a usable prompt in < 300 ms.
- `zsh -i -c exit` has no stderr output (today: `monitor`/`zle` errors + gitstatus failure).
- `PATH` has zero duplicates; `which -a` resolves each tool once.
- `compdef` works in a fresh shell; `git`, `mise`, `gh`, `aws` completions load.
- History: shared across windows, `Ctrl-R` search returns results from other sessions.
- Prompt: git repo, dirty state, exit status, duration, aws profile all render correctly.
- bash: `.bash_profile`/`.bashrc` still work for scripts and bash-my-aws.
- Secrets: no key material in any dotfile under version control.

---

## 9. Before/after measurement log

Fill during Phases 0–4; this is the only acceptable proof of "modernized".

| Metric | Baseline | Target | After |
| --- | --- | --- | --- |
| `zsh -i -c exit` (median, 20 runs) | 1.36–1.52 s | < 300 ms | **387–441 ms** (login 428–442 ms) |
| First prompt in new WezTerm window | ~1.5 s | < 400 ms | ~390 ms (matching `zsh -i`) |
| Prompt render time | n/a | < 20 ms | not measured (still p10k) |
| `PATH` entries / duplicated paths | 33 / 6 (clean shell) | ≤ 40 / 0 | **25 / 0** (interactive 49 / 0) |
| Startup stderr lines | 8 | 0 | 8 — unchanged |
| Tools installed, shell-loaded | ~20 | ≤ 15 | 19 (nvm, jenv dropped from startup) |
| Lines in startup path | ~142 + 1827 (p10k) | < 200 + starship.toml | 145 + 1827 |

---

## 10. Keeping it from drifting again

The docs went stale because the config lived outside the repo. Fix the cause:

- **Option A (recommended):** move `shell/` to being the real source, symlinked into `~`
  (`stow` or a small `install.sh`), so editing `~/.zshrc` edits the repo file.
- **Option B:** adopt `chezmoi` for templating and secret handling (it also solves §2.4 secrets).
- **Either way:** `make audit` regenerates `audit/inventory.md`, and CI runs `zsh -n`,
  `bash -n`, `shellcheck`, and a startup-time budget check so regressions are caught on PR.

Doc rule going forward: any change to a file in `shell/` must update the guide in the same PR.
The paired-file convention already in `CLAUDE.md` is right — it just needs the files to actually
be here.

---

## 11. Decisions needed from you

1. ~~**Transient prompt:** required, or acceptable to lose?~~ **Resolved: keep.** Vendored
   `zsh-transient-prompt`, loaded before `zsh-syntax-highlighting` (see §7.3).
2. **Version managers (partly resolved):** nvm → mise and jenv → static `JAVA_HOME` landed
   2026-11-18 (−1.1 s). Still open: pyenv (keep, but drop `init --path`), conda (bash-only
   divergence), rbenv/ruby-install (unused).
3. **bash:** a real workflow, or a compatibility fallback? Determines how much audit effort §5.2
   bash parity gets. Note python resolves to conda in bash but pyenv in zsh.
4. **atuin / direnv / tmux:** any of these already wanted, or evaluate from scratch?
5. **Dotfile mechanism:** symlink/stow (simple) vs chezmoi (templating + secrets)?
6. ~~**Secrets:** rotate the exposed key now, and where should it live?~~ **Resolved: rotated and
   removed.** `~/.zshenv` now sources an optional untracked `~/.config/secrets.env`.
7. **Retirements:** `rbenv` + `ruby-install` (never initialised, `ruby` is system) and `tree`
   (superseded by `eza --tree`) have zero evidence of use — confirm removal?

---

## Appendix A — Copy-paste audit block

```sh
mkdir -p audit

# 1. startup timing
hyperfine --warmup 5 --runs 20 'zsh -i -c exit' --export-json audit/startup.json

# 2. path hygiene
printf '%s\n' "$PATH" | tr ':' '\n' > audit/path.txt
sort audit/path.txt | uniq -cd | sort -rn > audit/path-dupes.txt

# 3. sourced files
grep -nE '^[[:space:]]*(source|\.)[[:space:]]' ~/.zshenv ~/.zprofile ~/.zshrc \
  ~/.zsh/autoload.zsh ~/.zsh/zfunctions/*.zsh > audit/sources.txt

# 4. inventory
{ brew leaves; brew list --cask; mise ls; pipx list --short; ls ~/.local/bin; } > audit/inventory-raw.txt

# 5. usage
history 1 | awk '{$1=""; print $2}' | sort | uniq -c | sort -rn | head -50 > audit/top-commands.txt

# 6. lint
zsh -n ~/.zshrc ~/.zshenv ~/.zprofile ~/.zsh/autoload.zsh
bash -n ~/.bashrc ~/.bash_profile ~/.profile

# 7. secrets
gitleaks detect --no-git --source ~ --verbose > audit/secrets.txt 2>&1 || true
```

## Appendix B — Evidence behind this plan

Commands run against the live host on 2026-11-18 (abbreviated):

```sh
zsh --version                      # zsh 5.9 (arm64-apple-darwin25.0)
sw_vers -productVersion            # 26.5.2
/usr/bin/time -p zsh -i -c exit    # real 1.36–1.47 (5 runs)
zsh -f -c exit                     # real 0.00
echo $PATH | tr ':' '\n' | wc -l   # 80
... | sort | uniq -d | wc -l       # 14
fc -l | wc -l                      # history present, 33 KB file
brew leaves                        # see §2.3
```

Prompt-init verification: `src/init/starship.zsh` from the starship repository contains no
`transient` handling (only `precmd`/`preexec` hooks, `zle-keymap-select`, `PROMPT`/`RPROMPT`
assignments) — hence §7.3.
