--!nonstrict
-- Servicio: estado de la VPN, keyring (secret-tool) y llamadas a vpn-rema-up vía pkexec.
-- Los comandos llegan del panel por el estado CMD; el estado publicado es STATE.

local CMD = "vpn.command"
local STATE = "vpn.state"
local WRAPPER = "/run/current-system/sw/bin/vpn-rema-up"
local SERVICE = "vpn-rema"

local function setState(patch)
  local s = noctalia.state.get(STATE) or {}
  for k, v in pairs(patch) do s[k] = v end
  noctalia.state.set(STATE, s)
end

local function runtimeDir()
  return (noctalia.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/vpn-rema"
end

local function account()
  return tostring(noctalia.getConfig("account") or "rema")
end

-- Escribe un secreto en un fichero temporal de /run/user (solo lo lee el wrapper).
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

local function refreshSaved()
  noctalia.runAsync({ "secret-tool", "lookup", "service", SERVICE, "account", account() }, function(r)
    setState({ saved = r.exitCode == 0 and r.stdout ~= "" })
  end)
end

local function refreshConnected()
  noctalia.processMatches(function(matched)
    local s = noctalia.state.get(STATE) or {}
    if matched ~= s.connected then
      setState({ connected = matched })
    end
  end, "openfortivpn")
end

local function fail(msg)
  noctalia.removeFile(runtimeDir() .. "/pass")
  setState({ busy = false, needOtp = false, message = msg })
end

local function launch()
  setState({ busy = true, message = "Autentica para conectar…" })
  noctalia.runAsync({ "pkexec", WRAPPER, "start" }, function(r)
    if r.exitCode ~= 0 then
      return fail("Conexión cancelada o fallida")
    end
    setState({ busy = false, needOtp = true, message = "Introduce el código 2FA del email" })
  end)
end

-- Guarda la contraseña en el keyring y después lanza el wrapper.
local function connect(password, save)
  local function withPassword(pw)
    writeSecret("pass", pw, function(ok)
      if not ok then return fail("No se pudo preparar la contraseña") end
      if save then
        -- secret-tool lee el secreto de stdin: se pasa el fichero, nunca como argumento
        noctalia.runAsync({ "sh", "-c", 'secret-tool store --label="VPN rema" service ' .. SERVICE
          .. ' account "$2" < "$1"', "sh", runtimeDir() .. "/pass", account() }, function(r)
          if r.exitCode ~= 0 then return fail("No se pudo guardar en el keyring") end
          setState({ saved = true })
          launch()
        end)
      else
        launch()
      end
    end)
  end

  if password and password ~= "" then
    withPassword(password)
  else
    noctalia.runAsync({ "secret-tool", "lookup", "service", SERVICE, "account", account() }, function(r)
      if r.exitCode == 0 and r.stdout ~= "" then
        withPassword(r.stdout)
      else
        fail("Falta la contraseña (no hay ninguna guardada)")
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
  setState({ busy = true, message = "Desconectando…" })
  noctalia.runAsync({ "pkexec", WRAPPER, "stop" }, function(r)
    setState({ busy = false, message = r.exitCode == 0 and "Desconectada" or "No se pudo desconectar" })
    refreshConnected()
  end)
end

local function forget()
  noctalia.runAsync({ "secret-tool", "clear", "service", SERVICE, "account", account() }, function()
    setState({ saved = false, message = "Contraseña eliminada del keyring" })
  end)
end

noctalia.state.watch(CMD, function(cmd)
  if not cmd or not cmd.id then return end
  if cmd.action == "connect" then connect(cmd.password, cmd.save)
  elseif cmd.action == "otp" then sendOtp(cmd.otp)
  elseif cmd.action == "disconnect" then disconnect()
  elseif cmd.action == "forget" then forget()
  end
end)

function update()
  refreshConnected()
end

noctalia.setUpdateInterval(5000)
refreshSaved()
refreshConnected()
