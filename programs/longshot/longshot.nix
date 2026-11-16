{ ... }:

# Longshot: Ocarina of Time (Switch 2) recompilado de forma nativa. Se compila
# desde /games/Longshot-src con el devShell .#longshot de ~/.config/nixos, hacia
# /games/Longshot; el comando `longshot` (sistema) lo arranca con Vulkan en la ruta.
let
  launch = "/run/current-system/sw/bin/longshot";
in {
  xdg.desktopEntries.longshot = {
    name = "The Legend of Zelda: Ocarina of Time (Longshot)";
    exec = launch;
    icon = "/games/Longshot-src/assets/longshot.png";
    categories = [ "Game" ];
  };

  # Colección "Nativos" de Pegasus (pegasus-library)
  xdg.configFile."pegasus-library/native/longshot.json".text = builtins.toJSON {
    id = "longshot";
    title = "The Legend of Zelda: Ocarina of Time (Longshot)";
    # Por XWayland: ferriscope (Moonshine) deja delante la primera ventana
    # Wayland nativa, que es Pegasus, y el juego quedaría oculto detrás.
    # Audio por Pulse: SDL3 iría a PipeWire directo y se saltaría el
    # PULSE_SERVER de Moonshine, y el sonido saldría por el PC
    launch = "/run/current-system/sw/bin/env SDL_VIDEODRIVER=x11 SDL_AUDIO_DRIVER=pulseaudio ${launch}";
    developers = [ "Nintendo EPD" ];
    publishers = [ "Nintendo" ];
    release = "2026-11-05";
    summary = "Ocarina of Time de Switch 2 recompilado de forma nativa con Longshot, desde tu propia copia.";
    # IGDB: portada, key art sin logo y logo en color
    assets = {
      boxFront = "https://images.igdb.com/igdb/image/upload/t_original/cocv5r.jpg";
      background = "https://images.igdb.com/igdb/image/upload/t_original/ar6zbx.jpg";
      logo = "https://images.igdb.com/igdb/image/upload/t_original/ar627t.png";
    };
  };
}
