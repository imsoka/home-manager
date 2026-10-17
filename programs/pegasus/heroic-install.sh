# Uso: heroic-install <legendary|nile> <app_name>
#
# Instala un juego de Epic (legendary) o Amazon (nile) sin pasar por la
# ventana de Heroic, para lanzarlo desde Pegasus con el mando. Usa los mismos
# programas y la misma configuración que Heroic, así que el juego queda
# registrado como instalado en Heroic. Heroic aplica las dependencias de Wine
# y sus ajustes en el primer arranque, igual que si lo hubiera instalado él.
#
# La descarga va en segundo plano (unidad de systemd del usuario).
# - En el escritorio este comando sale enseguida y avisa con notificaciones.
# - Desde Moonshine (Moonlight) las notificaciones no se ven en el stream:
#   muestra el progreso en una ventana y al terminar abre el juego. Con
#   "Seguir en segundo plano" se vuelve a Pegasus mientras sigue
#   descargando, y entonces no se abre nada al acabar.
runner="${1:-}"
app="${2:-}"

heroic_dir="$HOME/.config/heroic"
export LEGENDARY_CONFIG_PATH="$heroic_dir/legendaryConfig/legendary"
export NILE_CONFIG_PATH="$heroic_dir/nile_config"

# Una unidad por juego: así no se instala dos veces a la vez
unit="heroic-install-$runner-$(systemd-escape -- "$app")"
# Salida de la descarga y resultado ("ok" o "error"), para la ventana de
# progreso
state_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/heroic-install"
log="$state_dir/$unit.log"
result="$state_dir/$unit.result"

title_of() {
  local cache="$heroic_dir/store_cache/${runner}_library.json"
  jq -r --arg app "$app" '.library[]? | select(.app_name == $app) | .title' \
    "$cache" 2>/dev/null | head -n1 || true
}

notify() {
  notify-send --app-name=Heroic --icon=heroic "$@" || true
}

# Segunda fase: la propia descarga, ya dentro de la unidad de systemd
if [ "${HEROIC_INSTALL_WORKER:-}" = 1 ]; then
  title="$(title_of)"
  title="${title:-$app}"

  # La ruta de Heroic (home-manager la fija en /games/Heroic)
  config="$heroic_dir/config.json"
  base="$(jq -r '.defaultSettings.defaultInstallPath // empty' "$config" 2>/dev/null || true)"
  base="${base:-/games/Heroic}"
  base="${base/#\~/$HOME}"
  workers="$(jq -r '.defaultSettings.maxWorkers // 0' "$config" 2>/dev/null || true)"
  mkdir -p "$base"

  # Mismos argumentos que usa Heroic al instalar
  case "$runner" in
    legendary)
      cmd=(legendary install "$app" --platform Windows --base-path "$base"
           --skip-dlcs --skip-sdl -y)
      [ "$workers" -gt 0 ] 2>/dev/null && cmd+=(--max-workers "$workers")
      ;;
    nile)
      cmd=(nile install --base-path "$base")
      [ "$workers" -gt 0 ] 2>/dev/null && cmd+=(--max-workers "$workers")
      cmd+=("$app")
      ;;
  esac

  notify "Instalando $title" "Se descarga en segundo plano en $base"
  # tee: la salida va al journal y al log que lee la ventana de progreso
  if "${cmd[@]}" 2>&1 | tee "$log"; then
    echo ok >"$result"
    # Heroic solo lee installed.json al arrancar o al refrescar la biblioteca
    if pgrep -f -- '-heroic-unwrapped-' >/dev/null; then
      notify "$title instalado" \
        "Heroic está abierto: ciérralo para que vea el juego antes de lanzarlo."
    else
      notify "$title instalado" "Ya se puede jugar desde Pegasus."
    fi
  else
    echo error >"$result"
    notify --urgency=critical "No se pudo instalar $title" \
      "Detalles: journalctl --user -u $unit"
    exit 1
  fi
  exit 0
fi

case "$runner" in
  legendary | nile) ;;
  *)
    echo "uso: heroic-install <legendary|nile> <app_name>" >&2
    exit 2
    ;;
esac
if [ -z "$app" ]; then
  echo "uso: heroic-install <legendary|nile> <app_name>" >&2
  exit 2
fi

in_moonshine() { [[ -n "${MOONSHINE_CLIENT_WIDTH:-}" ]]; }

title="$(title_of)"
title="${title:-$app}"

if systemctl --user is-active --quiet "$unit"; then
  # Ya en marcha: en el stream se vuelve a enseñar su progreso
  in_moonshine || { notify "$title ya se está instalando"; exit 0; }
else
  systemctl --user reset-failed "$unit" 2>/dev/null || true
  mkdir -p "$state_dir"
  rm -f "$log" "$result"
  systemd-run --user --unit="$unit" --collect --quiet \
    --description="Instalación de $app ($runner)" \
    --setenv=HEROIC_INSTALL_WORKER=1 \
    --setenv=PATH="$PATH" \
    "$0" "$runner" "$app"
fi

in_moonshine || exit 0

# Progreso en el stream. legendary y nile escriben líneas como
# "= Progress: 12.34% (…), Running for …, ETA: 00:05:12"
progress_lines() {
  local pct eta
  while [ ! -s "$result" ] && systemctl --user is-active --quiet "$unit"; do
    pct="$(grep -oE 'Progress: [0-9.]+' "$log" 2>/dev/null | tail -n1 | grep -oE '[0-9.]+$' || true)"
    eta="$(grep -oE 'ETA: [0-9:]+' "$log" 2>/dev/null | tail -n1 | cut -d' ' -f2 || true)"
    if [ -n "$pct" ]; then
      echo "${pct%.*}"
      echo "# Descargando $title… ${pct%.*}%${eta:+ · quedan $eta}"
    else
      echo "# Preparando la descarga de $title…"
    fi
    sleep 1
  done
  echo 100
}

if ! progress_lines | zenity --progress --title="Instalando" \
    --text="Preparando la descarga de $title…" --percentage=0 --auto-close \
    --cancel-label="Seguir en segundo plano" --width=480 2>/dev/null; then
  # Botón pulsado: la descarga sigue, se vuelve a Pegasus
  exit 0
fi

if [ "$(cat "$result" 2>/dev/null)" = ok ]; then
  # Se ha esperado a que terminara: a jugar. En Pegasus seguirá en "Sin
  # instalar" hasta que se vuelva a abrir (solo lee la biblioteca al arrancar)
  exec "$play_cmd" "$runner" "$app"
else
  zenity --error --title="Error" --timeout=10 --width=420 \
    --text="No se pudo instalar $title.\n\nDetalles: journalctl --user -u $unit" \
    2>/dev/null || true
fi
