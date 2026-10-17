# Uso: pegasus-play steam <appid>
#      pegasus-play <legendary|gog|nile|zoom|sideload> <app_name>
#
# Lanza un juego instalado de Steam o Heroic y no sale hasta que se cierra,
# para que Pegasus vuelva a mostrarse al terminar. Lanzados tal cual
# (steam://, heroic://), Pegasus se queda esperando al proceso de Steam o
# Heroic: vuelve al momento si ya estaba abierto o, si lo abre el propio
# lanzamiento (como en Moonshine, que cierra el Steam del escritorio), no
# vuelve nunca y se queda su ventana en el stream.
#
# Steam y Heroic se abren aparte (setsid) y se quedan en segundo plano. Un
# juego son los procesos que llevan en el entorno SteamAppId=<appid> (Steam
# se lo pone a todo lo que lanza) o HEROIC_APP_NAME=<app_name> (Heroic, con
# cualquier tienda). Si no llega a arrancar (falla, se cancela una
# actualización...), se vuelve a Pegasus al pasar el margen de espera.
store="${1:-}"
app="${2:-}"

case "$store" in
  steam)
    [[ "$app" =~ ^[0-9]+$ ]] || { echo "uso: pegasus-play steam <appid>" >&2; exit 2; }
    marker="SteamAppId=$app"
    # Arranque de Steam, inicio de sesión, sincronización con la nube
    start_timeout=180
    ;;
  legendary | gog | nile | zoom | sideload)
    [ -n "$app" ] || { echo "uso: pegasus-play $store <app_name>" >&2; exit 2; }
    marker="HEROIC_APP_NAME=$app"
    # En el primer arranque Heroic instala las dependencias de Wine
    start_timeout=300
    ;;
  *)
    echo "uso: pegasus-play <steam|legendary|gog|nile|zoom|sideload> <id>" >&2
    exit 2
    ;;
esac

steam_running() { pgrep -f 'ubuntu12_32/steam' >/dev/null; }

game_running() {
  local pid
  for pid in $(pgrep -u "$(id -u)"); do
    grep -qzxF -- "$marker" "/proc/$pid/environ" 2>/dev/null && return 0
  done
  return 1
}

# Steam deja el juego sin abrir mientras lo actualiza: el manifiesto no está
# en StateFlags 4 ("completamente instalado")
steam_root="$HOME/.local/share/Steam"
steam_updating() {
  local lib manifest
  while read -r lib; do
    manifest="$lib/steamapps/appmanifest_$app.acf"
    [ -f "$manifest" ] || continue
    grep -qE '"StateFlags"[[:space:]]+"4"' "$manifest" && return 1
    return 0
  done < <(grep -oE '"path"[[:space:]]+"[^"]+"' \
      "$steam_root/steamapps/libraryfolders.vdf" 2>/dev/null |
      sed -E 's/.*"([^"]+)"$/\1/' || true)
  return 1
}

if ! game_running; then
  if [ "$store" = steam ]; then
    if steam_running; then
      "$steam_cmd" "steam://rungameid/$app" >/dev/null 2>&1 </dev/null || true
    else
      setsid -f "$steam_cmd" -silent "steam://rungameid/$app" \
        >/dev/null 2>&1 </dev/null
    fi
  else
    # Con Heroic ya abierto, esta instancia le pasa el enlace y sale
    setsid -f "$heroic_cmd" --no-gui "heroic://launch/$store/$app" \
      >/dev/null 2>&1 </dev/null
  fi

  deadline=$((SECONDS + start_timeout))
  until game_running; do
    if [ "$store" = steam ] && steam_updating; then
      deadline=$((SECONDS + start_timeout))
    fi
    [ "$SECONDS" -lt "$deadline" ] || exit 1
    sleep 1
  done
fi

while game_running; do
  sleep 2
done
