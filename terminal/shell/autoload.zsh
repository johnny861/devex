#!/bin/zsh
#
# Loads shell functions from ~/.zsh/functions.
#
# Installed from this repo (terminal/shell/autoload.zsh):
#   cp terminal/shell/autoload.zsh        ~/.zsh/autoload.zsh
#   cp terminal/shell/functions/*.zsh     ~/.zsh/functions/
# and sourced from ~/.zshrc. See terminal/terminal-setup.md.
#
# Files must end in .zsh to be picked up. They are sourced (not autoloaded), so each file
# may define several functions and share private helpers with dashes or underscores in
# their names.

# Glob qualifiers: N = nullglob (no error when empty), . = regular files only.
for func_file in "$HOME"/.zsh/functions/*.zsh(N.); do
  source "$func_file"
done
unset func_file
