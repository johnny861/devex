# Terminal Setup using Wezterm

## MacOs
alias ls="eza --icons=always"

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





