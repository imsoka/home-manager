# Los juegos de Steam flotan, se centran y van a un workspace "game" que solo existe
# mientras hay alguno abierto: se crea nombrando el workspace vacío del final y
# se le quita el nombre al cerrar el último juego, así niri lo borra y no
# desplaza Mod+1..9.
#
# Un juego es una ventana con app-id steam_app_<id> (Proton) o cuyo proceso
# tiene SteamAppId en el entorno (nativos; Steam se lo pone a todo lo que
# lanza). Las ventanas X11 llegan a niri con el PID de xwayland-satellite, así
# que para ellas el PID real se saca de _NET_WM_PID.
declare -A checked=()

game_workspace_id() {
  niri msg -j workspaces | jq -r '.[] | select(.name == "game") | .id'
}

launched_by_steam() {
  local env
  env=$(tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null) || return 1
  grep -qE '^Steam(App|Game)Id=[1-9]' <<<"$env"
}

is_game() {
  local app_id=$1 pid=$2 xwin xpid
  [[ "$app_id" =~ ^steam_app_ ]] && return 0
  [[ "$app_id" =~ ^(steam|steamwebhelper)$ ]] && return 1
  [[ -n "$pid" && "$pid" != null ]] || return 1

  if [[ "$(cat "/proc/$pid/comm" 2>/dev/null)" == *xwayland-satel* ]]; then
    for xwin in $(xdotool search --class "^${app_id//[^[:alnum:]_-]/.}\$" 2>/dev/null); do
      xpid=$(xprop -id "$xwin" _NET_WM_PID 2>/dev/null | grep -oE '[0-9]+$') || continue
      launched_by_steam "$xpid" && return 0
    done
    return 1
  fi

  launched_by_steam "$pid"
}

niri msg -j event-stream | while read -r event; do
  window=$(jq -c '.WindowOpenedOrChanged.window // empty' <<<"$event")

  if [[ -n "$window" ]]; then
    read -r id app_id pid floating < <(jq -r '[.id, .app_id, .pid, .is_floating] | @tsv' <<<"$window")
    [[ -z "${checked[$id]:-}" ]] || continue
    checked[$id]=1
    is_game "$app_id" "$pid" || continue

    [[ "$floating" == true ]] || niri msg action move-window-to-floating --id "$id"
    if [[ -z "$(game_workspace_id)" ]]; then
      last=$(niri msg -j workspaces | jq -r \
        --arg out "$(niri msg -j workspaces | jq -r '.[] | select(.is_focused) | .output')" \
        '[.[] | select(.output == $out) | .idx] | max')
      niri msg action set-workspace-name --workspace "$last" game
    fi
    niri msg action move-window-to-workspace --window-id "$id" game
    niri msg action focus-window --id "$id"
    niri msg action center-window --id "$id"
    continue
  fi

  closed=$(jq -r '.WindowClosed.id // empty' <<<"$event")
  [[ -n "$closed" ]] || continue
  unset "checked[$closed]"

  # Se comprueba con cualquier cierre: puede que lo último en "game" no fuese
  # un juego
  ws=$(game_workspace_id)
  [[ -n "$ws" ]] || continue
  remaining=$(niri msg -j windows | jq --argjson ws "$ws" '[.[] | select(.workspace_id == $ws)] | length')
  if (( remaining == 0 )); then
    niri msg action unset-workspace-name game
  fi
done
