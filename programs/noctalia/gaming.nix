{ pkgs, ... }:

# Solo para el host personal (homeConfigurations."soka-personal").
# Mismo rev que noctalia.nix, para que los plugins sean compatibles entre sí.
let
  communityPlugins = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "community-plugins";
    rev = "a8c5cd1c57ac3dc8a2048c86f5a6dcea71e0e3dd";
    hash = "sha256-6K8x2IB5ExjCleAbGRg4KTpAbPuSp4sko/qBl0rsy2c=";
  };
in {
  # Activar en runtime con:
  #   noctalia msg plugins enable alexander/game-launcher
  #   noctalia msg plugins enable nomadcxx/gamer-mode
  xdg.configFile."noctalia/plugins/game-launcher".source =
    "${communityPlugins}/game-launcher";
  xdg.configFile."noctalia/plugins/gamer-mode".source =
    "${communityPlugins}/gamer-mode";
  xdg.configFile."noctalia/plugins/discord-voice".source =
    "${communityPlugins}/discord-voice";
  xdg.configFile."noctalia/plugins/nvtop".source =
    "${communityPlugins}/nvtop";

  # Dependencias declaradas en plugin.toml
  home.packages = with pkgs; [
    gcc          # game-launcher: "cc"
    xdg-utils    # game-launcher
    procps       # gamer-mode: pgrep, pkill; nvtop: pkill, kill
    # discord-voice: puente RPC; nvtop (sus gráficas usan Pillow)
    (python3.withPackages (ps: [ ps.pillow ]))
    nvtopPackages.nvidia  # nvtop: monitor de GPU (con soporte NVIDIA)
    mangohud     # overlay de rendimiento para los juegos
  ];
}
