--!nonstrict
-- Panel: usuario, contraseña (opcional si ya está en el keyring), 2FA y botones de conectar/desconectar.

local STATE = "vpn.state"
local CMD = "vpn.command"

local s = noctalia.state.get(STATE) or {}
local user = s.user or tostring(noctalia.getConfig("vpn_user") or "ogi-varaque")
local password = ""
local otp = ""
local save = true
local reqId = 0

local function dispatch(action, extra)
  reqId += 1
  local cmd = { action = action, id = tostring(noctalia.nowMs()) .. "-" .. tostring(reqId) }
  for k, v in pairs(extra or {}) do cmd[k] = v end
  noctalia.state.set(CMD, cmd)
  password = ""
end

local function connectNow()
  dispatch("connect", { user = user, password = password, save = save })
end

local function render()
  s = noctalia.state.get(STATE) or s
  local children = {}

  children[#children + 1] = ui.label({
    text = s.connected and (s.needOtp and "Esperando código 2FA" or "Conectada")
      or (s.busy and "Conectando…" or "Desconectada"),
    fontSize = 14,
    fontWeight = "bold",
    color = s.connected and "primary" or "on_surface_variant",
  })

  if s.message and s.message ~= "" then
    children[#children + 1] = ui.label({ text = s.message, fontSize = 11, color = "on_surface_variant" })
  end

  -- El usuario se ve siempre; solo se bloquea mientras hay un intento o una conexión activa.
  local idle = not s.connected and not s.busy and not s.needOtp
  children[#children + 1] = ui.input({
    value = user,
    placeholder = "Usuario VPN",
    enabled = idle,
    onChange = function(text) user = text end,
    onSubmit = function() dispatch("check", { user = user }) end,
  })

  -- Mientras conecta, los campos y el botón siguen visibles pero deshabilitados.
  if not s.needOtp and not s.connected then
    children[#children + 1] = ui.input({
      value = password,
      password = true,
      placeholder = s.saved and "Contraseña (guardada en el keyring)" or "Contraseña VPN",
      enabled = idle,
      onChange = function(text) password = text end,
      onSubmit = connectNow,
    })
    children[#children + 1] = ui.row({ gap = 8, align = "center" }, {
      ui.toggle({ checked = save, enabled = idle, onChange = function(v) save = (v == "true") end }),
      ui.label({ text = "Guardar en el keyring", fontSize = 11 }),
    })
    children[#children + 1] = ui.button({
      text = s.busy and "Conectando…" or "Conectar",
      variant = "primary",
      enabled = idle,
      onClick = connectNow,
    })
  end

  if s.needOtp then
    children[#children + 1] = ui.input({
      value = otp,
      placeholder = "Código 2FA del email",
      onChange = function(text) otp = text end,
      onSubmit = function() dispatch("otp", { otp = otp }); otp = "" end,
    })
    children[#children + 1] = ui.button({
      text = "Enviar código",
      variant = "primary",
      onClick = function() dispatch("otp", { otp = otp }); otp = "" end,
    })
  end

  if s.connected and not s.needOtp then
    children[#children + 1] = ui.button({
      text = "Desconectar",
      variant = "destructive",
      onClick = function() dispatch("disconnect") end,
    })
  end

  if s.saved and not s.connected and not s.busy then
    children[#children + 1] = ui.button({
      text = "Olvidar contraseña guardada",
      variant = "ghost",
      onClick = function() dispatch("forget", { user = user }) end,
    })
  end

  panel.render(ui.column({ gap = 10, padding = 16 }, children))
end

noctalia.state.watch(STATE, function(v)
  s = v or {}
  render()
end)
render()
