--!nonstrict
-- Alerta a pantalla completa: parpadea en rojo con el porcentaje en grande.
-- Se cierra sola al enchufar el cargador; el botón pospone (el servicio decide cuánto).

local ALERT = "lowbat.alert"
local PANEL = "lowbat.panel"
local CMD = "lowbat.command"
local FLASH_MS = 450

local flashOn = true
local elapsed = 0
local cmdId = 0

local function render()
  local a = noctalia.state.get(ALERT) or {}
  local critical = a.level == "critical"
  local bg = flashOn and "#d00000" or (critical and "#000000" or "#5a0000")
  local fg = flashOn and "#ffffff" or "#ff3b3b"

  local remaining = a.minutesLeft and ("Quedan unos %d minutos de batería"):format(a.minutesLeft)
    or "La batería se está agotando"

  panel.render(ui.column({ flexGrow = 1, fill = bg, align = "center", justify = "center", gap = 24, padding = 48 }, {
    ui.glyph({ name = "battery-exclamation", size = 220, color = fg }),
    ui.label({
      text = critical and "¡BATERÍA CRÍTICA!" or "¡BATERÍA BAJA!",
      fontSize = 96, fontWeight = "heavy", color = fg, textAlign = "center",
    }),
    ui.label({ text = ("%d%%"):format(a.percent or 0), fontSize = 180, fontWeight = "heavy", color = fg }),
    ui.label({
      text = "ENCHUFA EL CARGADOR YA · " .. remaining,
      fontSize = 32, fontWeight = "bold", color = fg, textAlign = "center",
    }),
    ui.label({
      text = "Guarda lo que estés haciendo: el teclado sigue llegando a la ventana de detrás (Ctrl+S).",
      fontSize = 20, color = fg, textAlign = "center",
    }),
    ui.button({
      text = ("Posponer %d min"):format(a.snoozeMinutes or 3),
      glyph = "clock-pause",
      variant = "secondary",
      controlSize = "lg",
      fontSize = 18,
      onClick = function()
        cmdId += 1
        noctalia.state.set(CMD, { id = cmdId, action = "snooze" })
      end,
    }),
  }))
end

noctalia.state.watch(ALERT, function(a)
  if not a or not a.active then
    panel.close()
    return
  end
  render()
end)

function onFrameTick(deltaMs)
  elapsed += deltaMs
  if elapsed >= FLASH_MS then
    elapsed = 0
    flashOn = not flashOn
    render()
  end
end

function onOpen()
  noctalia.state.set(PANEL, { open = true })
  flashOn, elapsed = true, 0
  panel.setNeedsFrameTick(true)
  render()
end

function onClose()
  panel.setNeedsFrameTick(false)
  noctalia.state.set(PANEL, { open = false })
end
