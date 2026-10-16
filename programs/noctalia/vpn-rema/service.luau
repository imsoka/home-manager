--!nonstrict
-- Servicio: estado de la VPN, keyring (secret-tool) y llamadas a vpn-rema-up vía pkexec.
-- Los comandos llegan del panel por CMD; el estado publicado es STATE.

local CMD = "vpn.command"
local STATE = "vpn.state"
local WRAPPER = "/run/current-system/sw/bin/vpn-rema-up"
local LOG = "/run/vpn-rema.log"
local SERVICE = "vpn-rema"

local attempting = false
local launchedAt = 0

local function setState(patch)
  local s = noctalia.state.get(STATE) or {}
  for k, v in pairs(patch) do s[k] = v end
  noctalia.state.set(STATE, s)
end

local function runtimeDir()
  return (noctalia.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/vpn-rema"
end

local function validUser(u)
  return u ~= nil and u:match("^[%w._@-]+$") ~= nil
end

-- Escribe un valor en un fichero temporal de /run/user (solo lo lee el wrapper).
local function writeSecret(name, value, cb)
  local dir = runtimeDir()
  noctalia.runAsync({ "mkdir", "-p", "-m", "700", dir }, function()
    local path = dir .. "/" .. name
    noctalia.writeFile(path, value)
    noctalia.runAsync({ "chmod", "600", path }, function(r)
      if cb then cb(r.exitCode == 0) end
    end)
  end)
end

local function refreshSaved(user)
  noctalia.runAsync({ "secret-tool", "lookup", "service", SERVICE, "account", user }, function(r)
    setState({ saved = r.exitCode == 0 and r.stdout ~= "" })
  end)
end

local function fail(msg)
  attempting = false
  noctalia.removeFile(runtimeDir() .. "/pass")
  setState({ busy = false, needOtp = false, message = msg })
end

-- Lee el log del wrapper y deduce en qué punto está openfortivpn.
-- Solo se lee si el log es de este intento (el wrapper lo sobrescribe al arrancar).
local function readLog()
  local info = noctalia.fileInfo(LOG)
  if not info or info.mtime < launchedAt then return nil end
  local text = noctalia.readFile(LOG) or ""
  if text:find("Could not authenticate", 1, true) then
    return "rejected"
  elseif text:find("Tunnel is up", 1, true) then
    return "up"
  elseif text:find("[Tt]oken:") or text:find("[Oo]ne.?[Tt]ime") then
    return "otp"
  end
  return nil
end

-- La VPN solo cuenta como conectada con el túnel levantado. El proceso por sí solo
-- aparece también mientras openfortivpn espera el 2FA.
local function refreshConnected()
  noctalia.processMatches(function(matched)
    local phase = attempting and readLog() or nil

    if phase == "rejected" then
      return fail("Contraseña o usuario rechazados (escríbela de nuevo, sin pegar)")
    end

    if not matched then
      if attempting and os.time() - launchedAt > 150 then
        return fail("Sin respuesta de openfortivpn (mira /run/vpn-rema.log)")
      end
      setState({ connected = false, needOtp = false })
      return
    end

    if phase == "up" or (not attempting) then
      attempting = false
      setState({ connected = true, needOtp = false, busy = false, message = "Conectada" })
    elseif phase == "otp" then
      setState({ connected = false, needOtp = true, busy = false, message = "Introduce el código 2FA del email" })
    elseif attempting and os.time() - launchedAt > 150 then
      fail("Sin respuesta de openfortivpn (mira /run/vpn-rema.log)")
    end
  end, "openfortivpn")
end

local function launch(user)
  attempting = true
  launchedAt = os.time()
  setState({ busy = true, needOtp = false, message = "Autentica para conectar…" })
  noctalia.runAsync({ "pkexec", WRAPPER, "start", user }, function(r)
    if r.exitCode ~= 0 then
      local err = (r.stderr or ""):gsub("%s+$", ""):match("([^\n]*)$") or ""
      return fail(err ~= "" and err or "Conexión cancelada o fallida")
    end
    setState({ busy = true, message = "Conectando…" })
  end)
end

-- Envía el usuario, guarda la contraseña en el keyring si toca y lanza el wrapper.
local function connect(user, password, save)
  if not validUser(user) then
    return fail("Usuario no válido")
  end

  local function withPassword(pw)
    writeSecret("pass", pw, function(ok)
      if not ok then return fail("No se pudo preparar la contraseña") end
      if save then
        -- secret-tool lee el secreto de stdin: se pasa el fichero, nunca como argumento
        noctalia.runAsync({ "sh", "-c", 'secret-tool store --label="VPN rema" service ' .. SERVICE
          .. ' account "$2" < "$1"', "sh", runtimeDir() .. "/pass", user }, function(r)
          if r.exitCode ~= 0 then return fail("No se pudo guardar en el keyring") end
          setState({ saved = true })
          launch(user)
        end)
      else
        launch(user)
      end
    end)
  end

  if password and password ~= "" then
    withPassword(password)
  else
    noctalia.runAsync({ "secret-tool", "lookup", "service", SERVICE, "account", user }, function(r)
      if r.exitCode == 0 and r.stdout ~= "" then
        withPassword(r.stdout)
      else
        fail("No hay contraseña guardada para " .. user)
      end
    end)
  end
end

local function sendOtp(code)
  if not code or code == "" then return end
  writeSecret("otp", code, function(ok)
    if ok then setState({ needOtp = false, message = "Código enviado" }) end
  end)
end

local function disconnect()
  attempting = false
  setState({ busy = true, message = "Desconectando…" })
  noctalia.runAsync({ "pkexec", WRAPPER, "stop" }, function(r)
    setState({ busy = false, message = r.exitCode == 0 and "Desconectada" or "No se pudo desconectar" })
    refreshConnected()
  end)
end

local function forget(user)
  noctalia.runAsync({ "secret-tool", "clear", "service", SERVICE, "account", user }, function()
    setState({ saved = false, message = "Contraseña eliminada del keyring" })
  end)
end

noctalia.state.watch(CMD, function(cmd)
  if not cmd or not cmd.id then return end
  if cmd.action == "connect" then connect(cmd.user, cmd.password, cmd.save)
  elseif cmd.action == "otp" then sendOtp(cmd.otp)
  elseif cmd.action == "disconnect" then disconnect()
  elseif cmd.action == "forget" then forget(cmd.user)
  elseif cmd.action == "check" then refreshSaved(cmd.user)
  end
end)

function update()
  refreshConnected()
end

noctalia.setUpdateInterval(3000)
setState({ user = tostring(noctalia.getConfig("vpn_user") or "ogi-varaque") })
refreshConnected()
