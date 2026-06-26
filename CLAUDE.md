# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal DevEx repository — a collection of developer tooling guides, cheat sheets, and dotfile/config files. There is **no application code, build system, package manager, or test suite**. Content is plain Markdown plus config files meant to be copied into a user's environment (e.g. `~/`).

## Structure

- `guides/` — Markdown cheat sheets for CLI tools (`aws-cli-commands.md`, `tar-commands.md`).
- `guides/conf/` — Shareable config files referenced by the guides (e.g. `.gitconfig`).
- `terminal/` — Terminal setup. `terminal-setup.md` is the install/setup walkthrough; `.wezterm.lua` (WezTerm) and `.pk10.zsh` (Powerlevel10k) are the configs it tells the reader to copy to `~/`.

A guide and the config(s) it documents are paired: edits to one usually need a matching edit to the other. The config files in this repo are the canonical copies — the guides instruct readers to `cp` them into their home directory.

## Conventions

- Cheat-sheet guides are organized as `##` sections with fenced ```sh code blocks containing copy-paste-ready commands, often annotated with `#` comments.
- Dotfiles are committed with their leading-dot names intact (`.gitconfig`, `.wezterm.lua`, `.pk10.zsh`); they live in the repo without the dot stripped.
- Note `guides/conf/.gitconfig` contains a real name/email and `[http] sslVerify = false` — it is a personal config sample, not a security default to propagate.
