{ config, ... }:

# Mario Kart World recompilado (mkw-recomp, AppImage v0.1.2). El juego se
# prepara desde el dump propio en ~/.local/share/mkw-recomp (fuera del repo a
# propósito). El AppImage no corre en NixOS sin nix-ld, así que se lanza
# dentro de steam-run, desde la carpeta extraída (pkg/).
let
  game = "${config.home.homeDirectory}/.local/share/mkw-recomp";
in {
  # Colección "Nativos" de Pegasus (pegasus-library)
  xdg.configFile."pegasus-library/native/mkw-recomp.json".text = builtins.toJSON {
    id = "mkw-recomp";
    title = "Mario Kart World (recomp)";
    # Ruta del sistema, no del store: steam-run es el de NixOS. Sin sparse
    # images el driver NVIDIA de la RTX 2070 no pierde el dispositivo al arrancar
    launch = "env MKW_SPARSE_IMAGES=0 /run/current-system/sw/bin/steam-run ${game}/pkg/AppRun --play";
    summary = "Port nativo de Mario Kart World (mkw-recomp v0.1.2). Necesita el juego preparado desde tu dump.";
  };
}
