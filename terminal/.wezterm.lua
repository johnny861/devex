-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 160
config.initial_rows = 48

-- or, changing the font size and color scheme.
config.font_size = 14
-- config.font = wezterm.font('MesloLGS NF')
config.font = wezterm.font("MesloLGS Nerd Font Mono")

-- config.color_scheme = 'AdventureTime'
-- config.color_scheme = 'GitHub Dark'

config.colors = {
	foreground = "#CBE0F0",
	background = "#011423",
	cursor_bg = "#47FF9C",
	cursor_border = "#47FF9C",
	cursor_fg = "#011423",
	selection_bg = "#033259",
	selection_fg = "#CBE0F0",
	ansi = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7" },
	brights = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#A277FF", "#a277ff", "#24EAF7", "#24EAF7" },
}

config.window_background_opacity = 0.8
config.macos_window_background_blur = 20


-- https://wezterm.org/config/default-keys.html
local act = wezterm.action
config.keys = {
	{ mods = "OPT", key = "LeftArrow", action = act.SendKey({ mods = "ALT", key = "b" }) },
	{ mods = "OPT", key = "RightArrow", action = act.SendKey({ mods = "ALT", key = "f" }) },
	{ mods = "CMD", key = "LeftArrow", action = act.SendKey({ mods = "CTRL", key = "a" }) },
	{ mods = "CMD", key = "RightArrow", action = act.SendKey({ mods = "CTRL", key = "e" }) },
	{ mods = "CMD", key = "Backspace", action = act.SendKey({ mods = "CTRL", key = "u" }) },
	{ mods = "CMD|OPT", key = "LeftArrow", action = act.ActivateTabRelative(-1) },
	{ mods = "CMD|OPT", key = "RightArrow", action = act.ActivateTabRelative(1) },
	{ mods = "CMD|SHIFT", key = "LeftArrow", action = act.ActivateTabRelative(-1) },
	{ mods = "CMD|SHIFT", key = "RightArrow", action = act.ActivateTabRelative(1) },

  { mods = "CMD", key = "+", action = act.IncreaseFontSize },
  { mods = "CMD", key = "-", action = act.DecreaseFontSize },  
}


-- Finally, return the configuration to wezterm:
return config

