# Uso: steam-install <appid>
#
# Instala un juego de Steam sin el diálogo de "¿en qué biblioteca?": escribe
# su appmanifest en la biblioteca de /games marcado como "hace falta
# actualizar" (StateFlags 1026) y arranca Steam, que lo descarga solo.
# Steam tiene que estar cerrado mientras se escribe: guarda los manifiestos en
# memoria y lo sobrescribiría.
#
# - En el escritorio sale enseguida (Steam ya enseña sus descargas).
# - Desde Moonshine (Moonlight) muestra el progreso en una ventana y al
#   terminar abre el juego. Con "Seguir en segundo plano" se vuelve a Pegasus
#   mientras sigue descargando, y entonces no se abre nada al acabar.
appid="${1:-}"

library="${STEAM_INSTALL_LIBRARY:-/games/SteamLibrary}"
steam_root="$HOME/.local/share/Steam"
real_steam=/run/current-system/sw/bin/steam
manifest="$library/steamapps/appmanifest_$appid.acf"

if ! [[ "$appid" =~ ^[0-9]+$ ]]; then
  echo "uso: steam-install <appid>" >&2
  exit 2
fi

in_moonshine() { [[ -n "${MOONSHINE_CLIENT_WIDTH:-}" ]]; }
steam_running() { pgrep -f 'ubuntu12_32/steam' >/dev/null; }

notify() { notify-send -a Steam -i steam "$@" || true; }

say() {
  if in_moonshine; then
    zenity "$1" --title=Steam --text="$2" --timeout=8 --width=420 \
      2>/dev/null || true
  else
    notify "$2"
  fi
}

# Nombre del juego: la ficha de la tienda que ya guarda pegasus-library
name="$(jq -r '.name // empty' "$HOME/.cache/pegasus-library/steam-store/$appid.json" 2>/dev/null || true)"
name="${name:-$appid}"

# Bibliotecas registradas en Steam: si el juego ya tiene manifiesto en alguna
# (instalado o a medias), no se toca y se abre con Steam como siempre
libraries() {
  grep -oE '"path"[[:space:]]+"[^"]+"' "$steam_root/steamapps/libraryfolders.vdf" \
    2>/dev/null | sed -E 's/.*"([^"]+)"$/\1/' || true
}
for lib in $(libraries); do
  if [ -f "$lib/steamapps/appmanifest_$appid.acf" ]; then
    exec "$steam_cmd" "steam://rungameid/$appid"
  fi
done

if ! libraries | grep -qxF "$library"; then
  say --error "La biblioteca $library no está registrada en Steam.\n\nAñádela en Steam → Ajustes → Almacenamiento."
  exit 1
fi

# Cierre ordenado de Steam (sincroniza la nube antes de salir)
if steam_running; then
  "$real_steam" -shutdown >/dev/null 2>&1 &
  for _ in $(seq 1 30); do
    steam_running || break
    sleep 1
  done
  if steam_running; then
    say --error "Steam no se ha cerrado y no se puede preparar la instalación de $name."
    exit 1
  fi
fi

# Carpeta de instalación: el nombre sin caracteres problemáticos (Steam usa
# la que diga el manifiesto)
installdir="$(printf '%s' "$name" | tr -d '<>:"/\\|?*' | sed -E 's/[[:space:]]+$//')"
installdir="${installdir:-$appid}"
cat >"$manifest" <<EOF
"AppState"
{
	"appid"		"$appid"
	"Universe"		"1"
	"name"		"$name"
	"StateFlags"		"1026"
	"installdir"		"$installdir"
	"AutoUpdateBehavior"		"0"
}
EOF

# Steam arranca en la bandeja y empieza a descargar. setsid: sigue vivo
# aunque este comando acabe (en Moonshine, dentro del compositor del stream)
setsid -f "$steam_cmd" -silent >/dev/null 2>&1 </dev/null

if ! in_moonshine; then
  notify "Instalando $name" "Steam lo descarga en $library"
  exit 0
fi

# Progreso en el stream, con los bytes que Steam va apuntando en el manifiesto
field() {
  grep -oE "\"$1\"[[:space:]]+\"[0-9]+\"" "$manifest" 2>/dev/null |
    grep -oE '[0-9]+"$' | tr -d '"' || true
}
progress_lines() {
  local flags got total
  while [ -f "$manifest" ]; do
    flags="$(field StateFlags)"
    [ "$flags" = 4 ] && break
    got="$(field BytesDownloaded)"
    total="$(field BytesToDownload)"
    if [ -n "$total" ] && [ "$total" -gt 0 ] 2>/dev/null; then
      echo $((${got:-0} * 99 / total))
      echo "# Descargando $name… $((${got:-0} / 1048576)) de $((total / 1048576)) MB"
    else
      echo "# Steam está preparando la descarga de $name…"
    fi
    sleep 2
  done
  echo 100
}

if ! progress_lines | zenity --progress --title="Instalando" \
    --text="Steam está preparando la descarga de $name…" --percentage=0 \
    --auto-close --cancel-label="Seguir en segundo plano" --width=480 \
    2>/dev/null; then
  exit 0
fi

if [ "$(field StateFlags)" != 4 ]; then
  say --error "La instalación de $name se ha cancelado en Steam."
  exit 1
fi

# Se ha esperado a que terminara: a jugar. En Pegasus seguirá en "Sin
# instalar" hasta que se vuelva a abrir (solo lee la biblioteca al arrancar)
exec "$steam_cmd" "steam://rungameid/$appid"
