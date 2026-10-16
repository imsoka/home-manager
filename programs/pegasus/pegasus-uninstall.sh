# Uso: pegasus-uninstall <steam|legendary|nile|gog|zoom> <id>
#      pegasus-uninstall --queue
#
# Desinstala un juego de Steam o Heroic sin abrir sus ventanas, para hacerlo
# desde Pegasus con el mando. El tema no puede ejecutar comandos: escribe una
# petición en $queue_dir (dos líneas: tienda e id) y una unidad .path de
# systemd lanza "pegasus-uninstall --queue", que las atiende. El estado de
# cada una ("running", "ok" o "error") queda en $status_dir para que el tema
# lo enseñe.
#
# Se conservan las partidas guardadas que no están junto al juego: el prefijo
# de Proton de Steam (compatdata) y los prefijos de Wine de Heroic.
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pegasus-uninstall"
queue_dir="$state_dir/queue"
status_dir="$state_dir/status"

steam_root="$HOME/.local/share/Steam"
real_steam=/run/current-system/sw/bin/steam
heroic_dir="$HOME/.config/heroic"
export LEGENDARY_CONFIG_PATH="$heroic_dir/legendaryConfig/legendary"
export NILE_CONFIG_PATH="$heroic_dir/nile_config"

notify() { notify-send -a Pegasus -i pegasus-frontend "$@" || true; }

steam_running() { pgrep -f 'ubuntu12_32/steam' >/dev/null; }

# Nombre del juego para los avisos: las fichas que guarda pegasus-library
title_of() {
  local source="$1" id="$2" cache
  case "$source" in
    steam)
      jq -r '.name // empty' "$HOME/.cache/pegasus-library/steam-store/$id.json" 2>/dev/null || true
      ;;
    *)
      case "$source" in
        legendary) cache="$heroic_dir/store_cache/legendary_library.json" ;;
        nile) cache="$heroic_dir/store_cache/nile_library.json" ;;
        gog) cache="$heroic_dir/store_cache/gog_library.json" ;;
        zoom) cache="$heroic_dir/store_cache/zoom_library.json" ;;
      esac
      jq -r --arg id "$id" '(.library // .games)[]? | select(.app_name == $id) | .title' \
        "$cache" 2>/dev/null | head -n1 || true
      ;;
  esac
}

libraries() {
  grep -oE '"path"[[:space:]]+"[^"]+"' "$steam_root/steamapps/libraryfolders.vdf" \
    2>/dev/null | sed -E 's/.*"([^"]+)"$/\1/' || true
}

acf_field() {
  grep -oE "\"$1\"[[:space:]]+\"[^\"]*\"" "$2" | head -n1 | sed -E 's/.*"([^"]*)"$/\1/'
}

steam_uninstall() {
  local appid="$1" lib manifest="" installdir pid restart_env=()
  for lib in $(libraries); do
    if [ -f "$lib/steamapps/appmanifest_$appid.acf" ]; then
      manifest="$lib/steamapps/appmanifest_$appid.acf"
      break
    fi
  done
  # Ya desinstalado (p. ej. se pide otra vez antes de reiniciar Pegasus)
  if [ -z "$manifest" ]; then
    echo "steam: $appid ya no está instalado" >&2
    return 0
  fi
  installdir="$(acf_field installdir "$manifest")"
  # Lo que se va a borrar con rm -rf: nada de rutas raras
  if [ -z "$installdir" ] || [[ "$installdir" == */* || "$installdir" == . || "$installdir" == .. ]]; then
    echo "steam: installdir inválido en $manifest: '$installdir'" >&2
    return 1
  fi
  # El reaper de Steam lleva el appid del juego en marcha
  if pgrep -f "AppId=$appid( |$)" >/dev/null; then
    echo "steam: $appid está en marcha" >&2
    return 1
  fi

  # Steam guarda los manifiestos en memoria: tiene que estar cerrado. Se
  # vuelve a abrir en la misma pantalla (escritorio o stream de Moonshine)
  if steam_running; then
    pid="$(pgrep -f 'ubuntu12_32/steam' | head -n1)"
    mapfile -t restart_env < <(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null |
      grep -E '^(DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|MOONSHINE_[A-Z_]*)=' || true)
    "$real_steam" -shutdown >/dev/null 2>&1 &
    for _ in $(seq 1 30); do
      steam_running || break
      sleep 1
    done
    if steam_running; then
      echo "steam: no se ha cerrado" >&2
      return 1
    fi
  fi

  lib="${manifest%/steamapps/*}"
  rm -rf -- "$lib/steamapps/common/$installdir" \
    "$lib/steamapps/downloading/$appid" \
    "$lib/steamapps/temp/$appid" \
    "$lib/steamapps/shadercache/$appid" \
    "$lib/steamapps/workshop/content/$appid" \
    "$lib/steamapps/workshop/appworkshop_$appid.acf"
  rm -f -- "$manifest"

  if [ "${#restart_env[@]}" -gt 0 ]; then
    env "${restart_env[@]}" setsid -f "$steam_cmd" -silent >/dev/null 2>&1 </dev/null
  fi
}

# GOG y Zoom: Heroic solo apunta el juego en su installed.json
heroic_store_uninstall() {
  local source="$1" id="$2" installed path tmp
  case "$source" in
    gog) installed="$heroic_dir/gog_store/installed.json" ;;
    zoom) installed="$heroic_dir/zoom_store/installed.json" ;;
  esac
  path="$(jq -r --arg id "$id" '.installed[]? | select(.appName == $id) | .install_path' \
    "$installed" 2>/dev/null | head -n1)"
  if [ -z "$path" ] || [ "$path" = null ]; then
    echo "$source: $id ya no está instalado" >&2
    return 0
  fi
  case "$path" in
    /*/*) ;;
    *)
      echo "$source: ruta de instalación inválida: '$path'" >&2
      return 1
      ;;
  esac
  rm -rf -- "$path"
  tmp="$(mktemp)"
  jq --arg id "$id" '.installed |= map(select(.appName != $id))' "$installed" >"$tmp" &&
    mv "$tmp" "$installed"
}

uninstall() {
  local source="$1" id="$2"
  case "$source" in
    steam)
      [[ "$id" =~ ^[0-9]+$ ]] || return 2
      steam_uninstall "$id"
      ;;
    legendary) legendary -y uninstall --skip-uninstaller "$id" ;;
    nile) nile uninstall "$id" ;;
    gog | zoom) heroic_store_uninstall "$source" "$id" ;;
    *) return 2 ;;
  esac
}

# Desinstala, avisa y deja el estado para el tema
run_one() {
  local source="$1" id="$2" key="$3" title
  title="$(title_of "$source" "$id")"
  title="${title:-$id}"
  mkdir -p "$status_dir"
  echo running >"$status_dir/$key"
  if uninstall "$source" "$id"; then
    echo ok >"$status_dir/$key"
    if [ "$source" != steam ] && pgrep -f -- '-heroic-unwrapped-' >/dev/null; then
      notify "$title desinstalado" "Heroic está abierto: ciérralo para que lo vea."
    else
      notify "$title desinstalado"
    fi
    # Steam no toca libraryfolders.vdf al quitar un manifiesto a mano
    systemctl --user start --no-block pegasus-library.service || true
  else
    echo error >"$status_dir/$key"
    notify --urgency=critical "No se pudo desinstalar $title" \
      "Detalles: journalctl --user -u pegasus-uninstall"
    return 1
  fi
}

if [ "${1:-}" = --queue ]; then
  mkdir -p "$queue_dir" "$status_dir"
  failed=0
  for request in "$queue_dir"/*; do
    [ -f "$request" ] || continue
    key="$(basename "$request")"
    # El tema puede seguir escribiéndola cuando salta la unidad .path
    for _ in 1 2 3 4; do
      [ -s "$request" ] && break
      sleep 0.5
    done
    source="" id=""
    { read -r source; read -r id; } <"$request" || true
    rm -f -- "$request"
    if [ -z "$source" ] || [ -z "$id" ]; then
      echo "petición vacía: $key" >&2
      echo error >"$status_dir/$key"
      failed=1
      continue
    fi
    run_one "$source" "$id" "$key" || failed=1
  done
  exit "$failed"
fi

if [ $# -ne 2 ]; then
  echo "uso: pegasus-uninstall <steam|legendary|nile|gog|zoom> <id> | --queue" >&2
  exit 2
fi
run_one "$1" "$2" "$1-$(printf '%s' "$2" | tr -c 'A-Za-z0-9._-' _)"
