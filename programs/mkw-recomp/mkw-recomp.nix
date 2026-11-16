{ config, ... }:

# Mario Kart World recompilado (mkw-recomp, AppImage v0.1.7). El juego se
# prepara desde el dump propio en ~/.local/share/mkw-recomp (fuera del repo a
# propósito). El AppImage no corre en NixOS sin nix-ld, así que se lanza
# dentro de steam-run, desde la carpeta extraída (pkg/).
let
  game = "${config.home.homeDirectory}/.local/share/mkw-recomp";
  # Ruta del sistema, no del store: steam-run es el de NixOS
  launch = "/run/current-system/sw/bin/steam-run ${game}/pkg/AppRun --play";
in {
  xdg.desktopEntries.mkw-recomp = {
    name = "Mario Kart World (recomp)";
    exec = launch;
    icon = "${game}/pkg/mkw-recomp.png";
    categories = [ "Game" ];
  };

  # Colección "Nativos" de Pegasus (pegasus-library)
  xdg.configFile."pegasus-library/native/mkw-recomp.json".text = builtins.toJSON {
    id = "mkw-recomp";
    title = "Mario Kart World (recomp)";
    inherit launch;
    summary = "Port nativo de Mario Kart World (mkw-recomp v0.1.7). Necesita el juego preparado desde tu dump.";
  };
}
