{ pkgs, lib, config, ... }:

# Biblioteca de Pegasus estilo Playnite: pegasus-library junta Steam y
# Heroic (instalados y sin instalar) en colecciones de Pegasus.
# Pegasus se instala desde NixOS (gaming-programs.nix). Heroic va aquí para
# que use los mismos legendary y nile que heroic-install.
#
# Para los juegos de Steam sin instalar hace falta una API key
# (https://steamcommunity.com/dev/apikey) en
# ~/.config/pegasus-library/steam-api-key. Fuera del repo a propósito.
let
  home = config.home.homeDirectory;

  heroicInstall = pkgs.writeShellApplication {
    name = "heroic-install";
    # legendary-gl y nile son los mismos que lleva dentro pkgs.heroic
    runtimeInputs = with pkgs; [
      legendary-gl nile jq libnotify procps systemd coreutils gnugrep zenity
    ];
    text = ''
      heroic_cmd=${config.home.profileDirectory}/bin/heroic
    '' + builtins.readFile ./heroic-install.sh;
  };

  # Va antes que el pegasus-fe del sistema en el PATH: sincroniza la
  # biblioteca antes de abrir Pegasus
  pegasusWrapper = pkgs.writeShellApplication {
    name = "pegasus-fe";
    runtimeInputs = with pkgs; [
      systemd zenity libnotify procps coreutils xdotool
    ];
    text = builtins.readFile ./pegasus-fe.sh;
  };

  # Juegos de Steam sin el diálogo de elegir biblioteca: todo a /games
  steamInstall = pkgs.writeShellApplication {
    name = "steam-install";
    runtimeInputs = with pkgs; [
      jq libnotify procps coreutils gnugrep gnused util-linux zenity
    ];
    # El wrapper de steam (GE-Proton) de home-manager
    text = ''
      steam_cmd=${config.home.profileDirectory}/bin/steam
    '' + builtins.readFile ./steam-install.sh;
  };

  pegasusLibrary = pkgs.writers.writePython3Bin "pegasus-library" {
    libraries = [ pkgs.python3Packages.vdf ];
  } (builtins.readFile ./pegasus-library.py);

  # Lo que cambia al instalar, desinstalar o actualizar la biblioteca
  watched = [
    # Steam reescribe libraryfolders.vdf al instalar o desinstalar
    "${home}/.local/share/Steam/steamapps/libraryfolders.vdf"
    "${home}/.config/heroic/store_cache/legendary_library.json"
    "${home}/.config/heroic/store_cache/gog_library.json"
    "${home}/.config/heroic/store_cache/nile_library.json"
    "${home}/.config/heroic/store_cache/zoom_library.json"
    "${home}/.config/heroic/legendaryConfig/legendary/installed.json"
    "${home}/.config/heroic/gog_store/installed.json"
    "${home}/.config/heroic/nile_config/nile/installed.json"
    "${home}/.config/heroic/zoom_store/installed.json"
    "${home}/.config/heroic/sideload_apps/library.json"
  ];

  # Tema: pensado para mando (https://github.com/ilyasturki/pegasus-theme-reprise)
  reprise = pkgs.fetchFromGitHub {
    owner = "ilyasturki";
    repo = "pegasus-theme-reprise";
    rev = "d9810b74b1c52a3d7614b46eb7f534f957a992c6";
    hash = "sha256-Xu0/lbP6T+TwljVQ6cysDBydeD4Fkl3KFj4ndfRt+MI=";
  };

  # Ajustes que se fuerzan en settings.txt de Pegasus. Los lectores nativos
  # de Steam y GOG se apagan: pegasus-library ya los cubre (también los no
  # instalados) y saldrían duplicados.
  pegasusSettings = {
    "general.theme" = "${home}/.config/pegasus-frontend/themes/reprise/";
    "providers.steam.enabled" = "false";
    "providers.gog.enabled" = "false";
  };
  heroicPaths = {
    defaultInstallPath = "/games/Heroic";
    defaultWinePrefixDir = "/games/Heroic/Prefixes";
    # Nombre antiguo de defaultWinePrefixDir, Heroic aún lo lee
    defaultWinePrefix = "/games/Heroic/Prefixes";
    winePrefix = "/games/Heroic/Prefixes/shared";
  };
in {
  home.packages = [
    pkgs.heroic heroicInstall steamInstall pegasusLibrary pegasusWrapper
  ];

  xdg.configFile."pegasus-frontend/themes/reprise".source = reprise;

  # Pegasus reescribe settings.txt desde su menú, así que no se enlaza desde
  # el store: se fusionan las claves en cada activación.
  home.activation.pegasusSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/pegasus-frontend/settings.txt"
    run mkdir -p "$(dirname "$settings")"
    run touch "$settings"
    ${lib.concatStrings (lib.mapAttrsToList (key: value: ''
      run ${pkgs.gnused}/bin/sed -i '/^${lib.escape [ "." ] key}:/d' "$settings"
      run sh -c 'echo "${key}: ${value}" >> "$1"' _ "$settings"
    '') pegasusSettings)}
  '';

  # Los juegos de Heroic (y sus prefijos de Wine) van a /games, como la
  # biblioteca de Steam. Heroic reescribe config.json desde sus ajustes, así
  # que se fusionan las claves; si aún no existe, Heroic completa el resto
  # con sus valores por defecto.
  home.activation.heroicPaths = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config="$HOME/.config/heroic/config.json"
    run mkdir -p "$(dirname "$config")"
    [ -s "$config" ] || echo '{"defaultSettings":{},"version":"v0"}' > "$config"
    tmp="$(mktemp)"
    ${pkgs.jq}/bin/jq '.defaultSettings += ${builtins.toJSON heroicPaths}' \
      "$config" > "$tmp" && run mv "$tmp" "$config"
  '';

  systemd.user.services.pegasus-library = {
    Unit.Description = "Genera la biblioteca de Pegasus desde Steam y Heroic";
    Service = {
      Type = "oneshot";
      ExecStart = "${pegasusLibrary}/bin/pegasus-library";
      Environment = [
        # Rutas estables para los comandos de lanzamiento (no del store)
        "PEGASUS_LIBRARY_STEAM=${config.home.profileDirectory}/bin/steam"
        "PEGASUS_LIBRARY_HEROIC=${config.home.profileDirectory}/bin/heroic"
        "PEGASUS_LIBRARY_INSTALL=${config.home.profileDirectory}/bin/heroic-install"
        "PEGASUS_LIBRARY_STEAM_INSTALL=${config.home.profileDirectory}/bin/steam-install"
      ];
    };
  };

  # Heroic y Steam escriben varios archivos seguidos: tras un cambio se
  # espera a que terminen antes de regenerar. El wrapper de pegasus-fe espera
  # a este servicio si está pendiente.
  systemd.user.services.pegasus-library-debounce = {
    Unit.Description = "Espera a que Steam o Heroic terminen de escribir y regenera la biblioteca de Pegasus";
    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user start pegasus-library.service";
    };
  };

  systemd.user.paths.pegasus-library = {
    Unit.Description = "Regenera la biblioteca de Pegasus al cambiar Steam o Heroic";
    Path = {
      PathChanged = watched;
      Unit = "pegasus-library-debounce.service";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Al iniciar sesión y una vez al día: compras nuevas de Steam, que no tocan
  # ningún archivo local (las de Epic o GOG llegan cuando Heroic refresca su
  # caché, y eso ya lo vigila el .path)
  systemd.user.timers.pegasus-library = {
    Unit.Description = "Regenera la biblioteca de Pegasus periódicamente";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "1d";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
