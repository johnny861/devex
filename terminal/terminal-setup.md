# Terminal Setup using Wezterm

## MacOs

## Install Fonts
Install Meslo Nerd Font for showing icons in the terminal.

```sh
brew install font-meslo-lg-nerd-font
```

## Install Wezterm

```sh
brew install --cask wezterm
```

### Setup Wezterm Config

Copy **.wezterm.lua** configuration file to ~/
Command assumes root.

```sh
cp ./terminal/.wezterm.lua ~/
```

## Install Powerlevel10k theme
```sh
brew install powerlevel10k
echo "source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme" >> ~/.zshrc

#reload .zshrc
source ~/.zshrc

# start wizard
p10k configure
```

During wizard setup, select:
 - Color Scheme - Rainbow
 - Character Set - Unicode
 - Show current time - 24-hour format.
 - Prompt seperator - Round
 - Prompt heads - Round
 - Prompt tails - Blurred
 - Prompt height - 1 line
 - Prompt spacing - sparse
 - Icons - many icons
 - Prompt flow - concise
 - Enable transient prompt - yes
 - Instant prompt mode - (optional) verbose

## Install Console Utils

Ehanced ls and cd
```sh
brew install zsh-autosuggestions
brew install zsh-syntax-highlighting

# enhanced ls
brew install eza
# enchanced cd
brew install zoxide

echo "source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc

echo "source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
```

append to ~/.zshrc

```sh
# ---- Eza (ls) -----
alias ls="eza --icons=always"
# ---- Zoxide (cd) ----
eval "$(zoxide init zsh)"
alias cd="z"

```

## Git Console Utils

Install git-delta for better diffs

```sh
# install git if not already installed
brew install git

brew install git-delta
```

Edit ~/.gitconfig and add the following

```config
[core]
    editor = code
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
