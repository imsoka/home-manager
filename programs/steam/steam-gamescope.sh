# Uso (en las opciones de lanzamiento de Steam):
#   steam-gamescope [opciones extra de gamescope] -- gamemoderun %command%
#
# Lanza el juego en gamescope a la resolución de la pantalla donde se juega:
# en un stream de Moonshine, la del cliente de Moonlight (Steam se abre
# dentro de la sesión del stream y los juegos heredan su entorno); en el
# escritorio, 1920x1080 a 60 Hz.

# Desde Moonshine el PATH puede venir recortado; gamescope es el del sistema
# (con el layout de teclado de programs.gamescope.env)
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

width="${MOONSHINE_CLIENT_WIDTH:-}"
height="${MOONSHINE_CLIENT_HEIGHT:-}"
fps="${MOONSHINE_CLIENT_FRAMERATE:-}"

if [[ ! "$width" =~ ^[0-9]+$ || ! "$height" =~ ^[0-9]+$ ]]; then
  width=1920
  height=1080
fi
[[ "$fps" =~ ^[0-9]+$ && "$fps" -gt 0 ]] || fps=60
# Por si llega en milihercios (59940)
((fps < 1000)) || fps=$(((fps + 500) / 1000))

exec gamescope -W "$width" -H "$height" -r "$fps" -F fsr -f "$@"
