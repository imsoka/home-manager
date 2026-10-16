{ pkgs, lib, ... }:

# Discord reescribe settings.json en tiempo de ejecución, así que no se puede
# enlazar desde el store: se fusiona la clave en cada activación.
# MINIMIZE_TO_TRAY: al cerrar la ventana (Mod+Shift+Q) se queda en la bandeja
# en vez de salir.
{
  home.activation.discordMinimizeToTray = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/discord/settings.json"
    run mkdir -p "$(dirname "$settings")"
    [ -s "$settings" ] || echo '{}' > "$settings"
    tmp="$(mktemp)"
    ${pkgs.jq}/bin/jq '.MINIMIZE_TO_TRAY = true' "$settings" > "$tmp" \
      && run mv "$tmp" "$settings"
  '';

  # Arranca con la sesión, directamente en la bandeja
  xdg.configFile."autostart/discord.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Discord
    Exec=discord --start-minimized
    Icon=discord
  '';
}
