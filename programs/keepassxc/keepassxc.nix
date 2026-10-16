{ pkgs, lib, ... }:

# KeePassXC reescribe keepassxc.ini en tiempo de ejecución, así que no se puede
# enlazar desde el store: se fijan las claves en cada activación.
# Icono en la bandeja + cerrar la ventana (Mod+Shift+Q) la minimiza a la
# bandeja en vez de salir.
{
  home.activation.keepassxcMinimizeToTray = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ini="$HOME/.config/keepassxc/keepassxc.ini"
    run mkdir -p "$(dirname "$ini")"
    for key in ShowTrayIcon MinimizeToTray MinimizeOnClose; do
      run ${pkgs.crudini}/bin/crudini --ini-options=nospace --set "$ini" GUI "$key" true
    done
  '';
}
