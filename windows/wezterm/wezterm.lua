-- WezTerm en Windows: abre directamente NixOS-WSL. install.ps1 lo copia a
-- %USERPROFILE%\.config\wezterm\wezterm.lua (se recarga solo al guardarlo).
-- Equivalente a programs/kitty/kitty.nix, con Gruvbox como Neovim.
local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.default_domain = "WSL:NixOS"

config.font = wezterm.font("SauceCodePro Nerd Font")
config.font_size = 11

-- Protocolo gráfico de kitty: lo usa snacks.image en Neovim (viene desactivado)
config.enable_kitty_graphics = true

config.colors = {
  background = "#282828",
  foreground = "#ebdbb2",
  cursor_bg = "#ebdbb2",
  cursor_fg = "#282828",
  cursor_border = "#ebdbb2",
  selection_bg = "#504945",
  selection_fg = "#ebdbb2",
  ansi = { "#282828", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#a89984" },
  brights = { "#928374", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#ebdbb2" },
}

config.scrollback_lines = 10000
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"
config.hide_tab_bar_if_only_one_tab = false

return config
