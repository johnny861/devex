#!/bin/zsh
#
# Install the shell function library from this repo into ~/.zsh.
#
# Usage: ./terminal/setup.zsh
#
# Copies (does not symlink) so ~/.zsh keeps working if the repo is moved or deleted.
# Existing files are overwritten; back up ~/.zsh first if you have local edits.

set -eu

repo=${0:A:h:h}
target="$HOME/.zsh"

mkdir -p "$target/functions"

cp "$repo/terminal/shell/autoload.zsh"    "$target/autoload.zsh"
cp "$repo"/terminal/shell/functions/*.zsh "$target/functions/"

function_count=$(ls "$repo"/terminal/shell/functions/*.zsh | wc -l | tr -d ' ')
print -r -- "Installed autoload.zsh and $function_count function file(s) into $target"
print -r -- "Reload with: exec zsh"
