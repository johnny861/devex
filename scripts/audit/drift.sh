#!/bin/sh
# Compare the repo's config copies with the live files. Exit 1 when anything drifted.
#
# Usage: scripts/audit/drift.sh
# The repo is canonical; a reported difference means either the live file was edited
# without updating the repo, or the repo was updated without installing it.

set -u

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
status=0

check() { # $1 = repo path, $2 = live path
  if [ ! -e "$2" ]; then
    printf 'missing live: %s\n' "${2/#$HOME/~}"
    status=1
    return
  fi
  if ! diff -q "$1" "$2" >/dev/null 2>&1; then
    printf '\ndrift: %s\n' "${1#"$repo"/}"
    diff -u "$1" "$2" | sed -n '3,24p'
    status=1
  fi
}

check "$repo/terminal/.wezterm.lua"        "$HOME/.wezterm.lua"
check "$repo/terminal/.p10k.zsh"           "$HOME/.p10k.zsh"
check "$repo/terminal/shell/autoload.zsh"  "$HOME/.zsh/autoload.zsh"

for f in "$repo"/terminal/shell/functions/*.zsh; do
  check "$f" "$HOME/.zsh/functions/$(basename "$f")"
done

if [ "$status" -eq 0 ]; then
  echo "no drift: repo configs match the live files"
fi

exit "$status"
