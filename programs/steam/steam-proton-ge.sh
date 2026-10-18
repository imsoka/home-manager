# Wrapper de steam: antes de abrirlo, instala el último GE-Proton si no lo
# tenemos y lo pone como herramienta de compatibilidad por defecto, y
# envuelve los juegos con gamescope y gamemoderun.
# Cualquier fallo (sin red, GitHub caído...) no impide abrir Steam.

steam_root="$HOME/.local/share/Steam"
compat_dir="$steam_root/compatibilitytools.d"
config_vdf="$steam_root/config/config.vdf"
real_steam=/run/current-system/sw/bin/steam

notify() { notify-send -a Steam -i steam GE-Proton "$1" || true; }

# Diálogo con barra de progreso; lee porcentajes y "# texto" por stdin
progress_dialog() {
  if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    zenity --progress --title="GE-Proton" --text="$1" --percentage=0 \
      --auto-close --width=420 2>/dev/null
  else
    cat >/dev/null
  fi
}

# Descarga, verifica y extrae en $tmp mientras escribe el progreso para
# zenity. Deja el resultado en $tmp/status ("ok" o el mensaje de error).
download_steps() {
  local tag=$1 tarball_url=$2 sum_url=$3 total=$4
  local tarball="$tmp/proton.tar.gz" pid size
  fail() { echo "$1" >"$tmp/status"; echo 100; exit 0; }

  curl -fsSL --connect-timeout 10 -o "$tarball" "$tarball_url" &
  pid=$!
  echo "$pid" >>"$tmp/pids"
  while kill -0 "$pid" 2>/dev/null; do
    size=$(stat -c %s "$tarball" 2>/dev/null || echo 0)
    echo $((size * 95 / total))
    echo "# Descargando $tag… $((size / 1048576)) de $((total / 1048576)) MB"
    sleep 0.5
  done
  wait "$pid" || fail "No se pudo descargar $tag"

  echo "# Verificando $tag…"
  echo 96
  if ! curl -fsSL --connect-timeout 10 "$sum_url" | awk '{print $1 "  proton.tar.gz"}' >"$tmp/checksum" ||
     ! (cd "$tmp" && sha512sum -c checksum >/dev/null); then
    fail "La descarga de $tag está corrupta"
  fi

  echo "# Extrayendo $tag…"
  echo 97
  mkdir -p "$tmp/extract"
  tar -xzf "$tarball" -C "$tmp/extract" &
  pid=$!
  echo "$pid" >>"$tmp/pids"
  wait "$pid" || fail "No se pudo extraer $tag"

  echo ok >"$tmp/status"
  echo 100
}

update_proton_ge() {
  # Si se abre Steam dos veces seguidas, el segundo espera a que acabe la
  # descarga del primero en vez de descargar lo mismo en paralelo
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/steam-proton-ge.lock"
  flock 9

  # Con Steam abierto no se toca nada: reescribe config.vdf al salir
  if pgrep -f 'ubuntu12_32/steam' >/dev/null; then
    return 0
  fi

  local release tag
  release=$(curl -fsSL --connect-timeout 5 --max-time 15 \
    https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest) || return 0
  tag=$(jq -r '.tag_name' <<<"$release")
  [[ "$tag" == GE-Proton* ]] || return 0
  [[ -d "$compat_dir/$tag" ]] && return 0

  local tarball_url sum_url total
  tarball_url=$(jq -r '.assets[] | select(.name | endswith("x86_64.tar.gz")) | .browser_download_url' <<<"$release")
  total=$(jq -r '.assets[] | select(.name | endswith("x86_64.tar.gz")) | .size' <<<"$release")
  sum_url=$(jq -r '.assets[] | select(.name | endswith("x86_64.sha512sum")) | .browser_download_url' <<<"$release")
  [[ -n "$tarball_url" && -n "$sum_url" && "$total" -gt 0 ]] || return 0

  # Directorio fijo y vaciado al empezar: si una ejecución anterior murió a
  # medias (señal sin trap), sus restos se borran aquí
  tmp="${XDG_CACHE_HOME:-$HOME/.cache}/steam-proton-ge"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  trap 'rm -rf "$tmp"' EXIT
  trap 'exit 1' TERM INT HUP

  download_steps "$tag" "$tarball_url" "$sum_url" "$total" |
    progress_dialog "Descargando $tag… Steam se abrirá al terminar"

  if [[ ! -f "$tmp/status" ]]; then
    # Diálogo cancelado: para la descarga o extracción en curso
    xargs -r kill 2>/dev/null <"$tmp/pids" || true
    notify "Descarga de $tag cancelada"
    return 0
  fi
  if [[ "$(cat "$tmp/status")" != ok ]]; then
    notify "$(cat "$tmp/status")"
    return 0
  fi

  local extracted
  extracted=$(find "$tmp/extract" -mindepth 1 -maxdepth 1 -type d | head -1)
  [[ -f "$extracted/compatibilitytool.vdf" ]] || { notify "$tag no tiene compatibilitytool.vdf"; return 0; }
  mkdir -p "$compat_dir"
  mv "$extracted" "$compat_dir/$tag"

  if [[ -f "$config_vdf" ]] && set-default-compat-tool "$config_vdf" "$compat_dir/$tag"; then
    notify "$tag instalado y activado por defecto"
  else
    notify "$tag instalado (actívalo en Ajustes → Compatibilidad)"
  fi
}

# En subshell: el trap limpia el temporal y un fallo no impide abrir Steam
(update_proton_ge) || true

# Todos los juegos con gamescope y gamemoderun (ver set-launch-options.py).
# Con Steam abierto no: reescribe localconfig.vdf al salir
if ! pgrep -f 'ubuntu12_32/steam' >/dev/null; then
  set-launch-options "$steam_root" "$steam_gamescope" "${game_prefixes[@]}" || notify-send -a Steam -i steam Steam \
    "No se pudieron poner gamescope y gamemode en las opciones de lanzamiento" || true
fi
exec "$real_steam" "$@"
