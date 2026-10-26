--!nonstrict
-- Servicio: vigila BAT0 y, si se descarga por debajo del umbral, abre la alerta a
-- pantalla completa y hace sonar la alarma hasta que se enchufe o se posponga.
-- Publica ALERT para el panel; el panel publica PANEL (abierto/cerrado) y manda CMD.

local ALERT = "lowbat.alert"
local PANEL = "lowbat.panel"
local CMD = "lowbat.command"
local PANEL_ID = "soka/low-battery-alarm:alert"
local SOUND = "lowbat-alarm"
local BAT = "/sys/class/power_supply/BAT0/"

local soundReady = false
local usePwPlay = noctalia.commandExists("pw-play")
local snoozeUntil = 0
local lastLevel = nil
local toggledAt = 0
local tick = 0
local fakePercent = nil -- `noctalia msg plugin soka/low-battery-alarm:watcher all test 9`

local function readNumber(name)
  local s = noctalia.readFile(BAT .. name)
  return s and tonumber(noctalia.string.trim(s)) or nil
end

local function readBattery()
  if fakePercent then
    return { percent = fakePercent, discharging = true, minutesLeft = fakePercent * 2 }
  end
  local percent = readNumber("capacity")
  local status = noctalia.string.trim(noctalia.readFile(BAT .. "status") or "")
  if not percent then return nil end
  -- energy_now (µWh) / power_now (µW) = horas restantes
  local energy, power = readNumber("energy_now"), readNumber("power_now")
  local minutesLeft = nil
  if energy and power and power > 0 then minutesLeft = math.floor(energy / power * 60) end
  return { percent = percent, discharging = status == "Discharging", minutesLeft = minutesLeft }
end

local function panelOpen()
  return (noctalia.state.get(PANEL) or {}).open == true
end

-- togglePanel es lo único que hay: solo se usa cuando el panel informa del estado
-- contrario, y no se repite mientras el anterior aún no ha surtido efecto.
local function setPanel(open)
  if panelOpen() == open or noctalia.nowMs() - toggledAt < 3000 then return end
  toggledAt = noctalia.nowMs()
  noctalia.togglePanel(PANEL_ID)
end

-- pw-play va directo a PipeWire: noctalia.sound respeta [audio] enable_sounds del
-- shell y, con los sonidos desactivados, reproduce a volumen 0.
local function playAlarm()
  if usePwPlay then
    noctalia.runAsync({ "pw-play", "--volume", "1.0", noctalia.pluginDir() .. "/sounds/alarm.wav" })
  elseif soundReady then
    noctalia.sound.play(SOUND)
  end
end

local function evaluate()
  local warn = tonumber(noctalia.getConfig("warn_percent")) or 15
  local critical = tonumber(noctalia.getConfig("critical_percent")) or 7
  local bat = readBattery()

  if not bat or not bat.discharging or bat.percent > warn then
    lastLevel, snoozeUntil = nil, 0
    noctalia.state.set(ALERT, { active = false })
    setPanel(false)
    return
  end

  local level = bat.percent <= critical and "critical" or "low"
  if level ~= lastLevel then
    -- Al empeorar (o al empezar) se ignora cualquier posposición anterior
    snoozeUntil = 0
    lastLevel = level
    noctalia.notifyError(
      level == "critical" and "¡Batería CRÍTICA!" or "Batería baja",
      ("Queda un %d%%. Enchufa el cargador."):format(bat.percent))
  end

  local snoozed = os.time() < snoozeUntil
  noctalia.state.set(ALERT, {
    active = not snoozed,
    level = level,
    percent = bat.percent,
    minutesLeft = bat.minutesLeft,
    snoozeMinutes = level == "critical" and 1 or (tonumber(noctalia.getConfig("snooze_minutes")) or 3),
  })
  setPanel(not snoozed)

  -- Alarma: cada tick en crítico, cada dos en bajo
  tick += 1
  if not snoozed and noctalia.getConfig("sound") == true
      and (level == "critical" or tick % 2 == 0) then
    playAlarm()
  end
end

noctalia.state.watch(CMD, function(cmd)
  if not cmd or cmd.action ~= "snooze" then return end
  local alert = noctalia.state.get(ALERT) or {}
  snoozeUntil = os.time() + (alert.snoozeMinutes or 3) * 60
  evaluate()
end)

function onIpc(event, payload)
  if event == "test" then
    fakePercent = tonumber(payload) or 5
    lastLevel = nil
  elseif event == "test-off" then
    fakePercent = nil
  end
  evaluate()
end

function onConfigChanged()
  evaluate()
end

function update()
  evaluate()
end

noctalia.sound.load(SOUND, "sounds/alarm.wav", function(ok, err)
  soundReady = ok
  if not ok then noctalia.log("low-battery-alarm: no se pudo cargar el sonido: " .. tostring(err)) end
end)

noctalia.state.set(PANEL, { open = false })
noctalia.setUpdateInterval(3000)
evaluate()
