# El diálogo de desbloqueo que pide KeePassXC-Browser es hijo de la ventana
# principal de KeePassXC, así que niri lo abre en el workspace de esta y sin
# foco. Lo traemos al workspace activo (el del navegador que lo pidió), lo
# centramos y le damos el foco.
declare -A handled=()

niri msg -j event-stream | while read -r event; do
  window=$(jq -c '.WindowOpenedOrChanged.window // empty' <<<"$event")
  [[ -n "$window" ]] || continue

  read -r id app_id title < <(jq -r '[.id, .app_id, .title] | @tsv' <<<"$window")
  [[ "${app_id,,}" == *keepassxc* ]] || continue
  [[ "$title" =~ ^(Desbloquear|Unlock) ]] || continue
  [[ -z "${handled[$id]:-}" ]] || continue
  handled[$id]=1

  workspace=$(niri msg -j workspaces | jq -r '.[] | select(.is_focused) | .idx')
  niri msg action move-window-to-workspace --window-id "$id" --focus false "$workspace"
  niri msg action focus-window --id "$id"
  niri msg action center-window --id "$id"
done
