# Wrapper de pegasus-fe: antes de abrirlo, sincroniza la biblioteca con
# pegasus-library, porque Pegasus solo la lee al arrancar. Si Steam o Heroic
# acaban de cambiar algo, espera a que termine esa regeneración.
# Cualquier fallo (sin red, servicio roto...) no impide abrir Pegasus.
#
# Desde Moonshine (Moonlight) la sesión va en un compositor aparte: las
# notificaciones del escritorio no se ven en el stream, así que ahí el
# feedback son ventanas de zenity.

real_pegasus=/run/current-system/sw/bin/pegasus-fe

# Desde Moonshine puede no venir el entorno de la sesión
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

in_moonshine() { [[ -n "${MOONSHINE_CLIENT_WIDTH:-}" ]]; }

warn() {
  if in_moonshine; then
    zenity --warning --title=Pegasus --text="$1\n\n$2" --timeout=8 \
      --width=420 2>/dev/null || true
  else
    notify-send -a Pegasus -i pegasus-frontend "$1" "$2" || true
  fi
}

# Diálogo sin porcentaje: se cierra cuando acaba la sincronización
progress_dialog() {
  if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    zenity --progress --pulsate --no-cancel --auto-close \
      --title="Pegasus" --text="Sincronizando la biblioteca…" --width=420 \
      2>/dev/null
  else
    cat >/dev/null
  fi
}

# El wrapper se llama igual que Pegasus: se busca por el ejecutable real
pegasus_running() {
  local pid
  for pid in $(pgrep -u "$(id -u)" -f pegasus-fe); do
    [[ "$(readlink "/proc/$pid/exe" 2>/dev/null)" == *-pegasus-frontend-*/bin/* ]] && return 0
  done
  return 1
}

sync_library() {
  # Regeneración pendiente tras un cambio en Steam o Heroic: termina ella
  # misma lanzando pegasus-library, así que basta con esperarla
  # (is-active no sirve: un oneshot en marcha está "activating", no "active")
  local state
  while state="$(systemctl --user show -p ActiveState --value \
      pegasus-library-debounce.service)" &&
      [[ "$state" == activating || "$state" == active ]]; do
    sleep 0.5
  done
  # Oneshot: start espera a que acabe (o se une a una que ya esté en marcha)
  timeout 180 systemctl --user start pegasus-library.service
}

# Con Pegasus ya abierto en el escritorio no hace falta esperar. En Moonshine
# siempre: es otra pantalla y el usuario solo ve el stream
if in_moonshine || ! pegasus_running; then
  status_file="$(mktemp)"
  ( if sync_library; then echo 0; else echo 1; fi >"$status_file" ) &
  sync_pid=$!

  # En el escritorio con la caché caliente tarda un segundo: el diálogo solo
  # si va para largo. En el stream, desde el principio (si no, pantalla negra)
  in_moonshine || sleep 1
  if kill -0 "$sync_pid" 2>/dev/null; then
    { while kill -0 "$sync_pid" 2>/dev/null; do sleep 0.5; done; echo 100; } |
      progress_dialog
  fi
  wait "$sync_pid" || true

  if [[ "$(cat "$status_file")" != 0 ]]; then
    warn "No se pudo sincronizar la biblioteca" \
      "Pegasus se abre con la anterior. Detalles: journalctl --user -u pegasus-library"
  fi
  rm -f "$status_file"
fi

if ! in_moonshine; then
  exec "$real_pegasus" "$@"
fi

# Pegasus (Qt, sin soporte Wayland en nixpkgs) va por Xwayland y en el
# compositor de Moonshine se queda en 1280x720: marca la pantalla completa
# pero Moonshine no cambia el tamaño de la ventana. Sí acepta que se lo
# cambiemos, así que se ajusta a la pantalla en cuanto aparece y se vigila
# mientras siga abierto (por si vuelve a su tamaño al volver de un juego).
"$real_pegasus" "$@" &
pegasus_pid=$!

fill_screen() {
  local window size width height
  size="$(xdotool getdisplaygeometry 2>/dev/null)" || return 0
  width="${size% *}"
  height="${size#* }"
  for window in $(xdotool search --onlyvisible --pid "$pegasus_pid" 2>/dev/null || true); do
    if [[ "$(xdotool getwindowgeometry "$window" 2>/dev/null)" != *"Geometry: ${width}x${height}"* ]]; then
      xdotool windowstate --add FULLSCREEN "$window" 2>/dev/null || true
      xdotool windowmove "$window" 0 0 windowsize "$window" "$width" "$height" \
        2>/dev/null || true
    fi
  done
}

timeout 30 xdotool search --sync --onlyvisible --pid "$pegasus_pid" \
  >/dev/null 2>&1 || true
while kill -0 "$pegasus_pid" 2>/dev/null; do
  fill_screen
  sleep 2
done
wait "$pegasus_pid"
