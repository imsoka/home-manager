# Las ventanas de Steam van a un workspace "steam" y los juegos (que además
# flotan, se centran y abren a 1920x1080) a uno "game". Cada uno solo existe
# mientras tiene ventanas: se crea nombrando el workspace vacío del final y se
# le quita el nombre al quedarse vacío, así niri lo borra y no desplaza
# Mod+1..9.
#
# Un juego es una ventana con app-id steam_app_<id> (Proton) o cuyo proceso
# tiene SteamAppId en el entorno (nativos; Steam se lo pone a todo lo que
# lanza). Las ventanas X11 llegan a niri con el PID de xwayland-satellite, así
# que para ellas el PID real se saca de _NET_WM_PID.
declare -A checked=()

workspace_id() {
  niri msg -j workspaces | jq -r --arg name "$1" '.[] | select(.name == $name) | .id'
}

# Mueve la ventana al workspace con ese nombre, creándolo al final si no existe,
# y la enfoca salvo que se esté jugando (los diálogos de Steam que salen al
# lanzar un juego no deben sacar del workspace "game")
move_to_workspace() {
  local id=$1 name=$2 last focused
  focused=$(niri msg -j workspaces | jq -r '.[] | select(.is_focused) | .name // ""')
  if [[ -z "$(workspace_id "$name")" ]]; then
    last=$(niri msg -j workspaces | jq -r \
      --arg out "$(niri msg -j workspaces | jq -r '.[] | select(.is_focused) | .output')" \
      '[.[] | select(.output == $out) | .idx] | max')
    niri msg action set-workspace-name --workspace "$last" "$name"
  fi
  niri msg action move-window-to-workspace --window-id "$id" --focus false "$name"
  if [[ "$name" == game || "$focused" != game ]]; then
    niri msg action focus-window --id "$id"
  fi
}

launched_by_steam() {
  local env
  env=$(tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null) || return 1
  grep -qE '^Steam(App|Game)Id=[1-9]' <<<"$env"
}

is_game() {
  local app_id=$1 pid=$2 xwin xpid
  [[ "$app_id" =~ ^steam_app_ ]] && return 0
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
    # Separador \x1f y no tabuladores: read junta los tabuladores seguidos y un
    # app-id vacío (gamescope) desplazaría los campos
    IFS=$'\x1f' read -r id app_id pid floating < <(jq -r \
      '[.id, .app_id, .pid, .is_floating] | map(. // "" | tostring) | join("\u001f")' <<<"$window")
    [[ -z "${checked[$id]:-}" ]] || continue
    checked[$id]=1
    if [[ "$app_id" =~ ^(steam|steamwebhelper)$ ]]; then
      move_to_workspace "$id" steam
    elif is_game "$app_id" "$pid"; then
      [[ "$floating" == true ]] || niri msg action move-window-to-floating --id "$id"
      move_to_workspace "$id" game
      niri msg action set-window-width --id "$id" 1920
      niri msg action set-window-height --id "$id" 1080
      niri msg action center-window --id "$id"
    fi
    continue
  fi

  closed=$(jq -r '.WindowClosed.id // empty' <<<"$event")
  [[ -n "$closed" ]] || continue
  unset "checked[$closed]"

  # Se comprueba con cualquier cierre: puede que lo último que quedaba en el
  # workspace no fuese de Steam
  for name in steam game; do
    ws=$(workspace_id "$name")
    [[ -n "$ws" ]] || continue
    remaining=$(niri msg -j windows | jq --argjson ws "$ws" '[.[] | select(.workspace_id == $ws)] | length')
    if (( remaining == 0 )); then
      niri msg action unset-workspace-name "$name"
    fi
  done
done
