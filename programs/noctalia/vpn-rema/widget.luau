--!nonstrict
-- Botón de barra: muestra el estado y abre el panel de la VPN.

local STATE = "vpn.state"
local PANEL_ID = "soka/vpn-rema:panel"

local function render()
  local s = noctalia.state.get(STATE) or {}
  local color = "on_surface_variant"
  local glyph = "shield"
  if s.busy then
    color = "secondary"
  elseif s.connected then
    color = "primary"
    glyph = "shield-check"
  end
  barWidget.render(ui.button({
    glyph = glyph,
    variant = "ghost",
    color = color,
    tooltip = s.connected and "VPN rema conectada" or "VPN rema desconectada",
    onClick = function() noctalia.togglePanel(PANEL_ID) end,
  }))
end

noctalia.state.watch(STATE, render)
render()
