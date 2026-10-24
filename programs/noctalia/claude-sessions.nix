{ pkgs, ... }:

# Mismo rev que noctalia.nix y gaming.nix, para que los plugins sean compatibles entre sí.
let
  communityPlugins = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "community-plugins";
    rev = "a8c5cd1c57ac3dc8a2048c86f5a6dcea71e0e3dd";
    hash = "sha256-6K8x2IB5ExjCleAbGRg4KTpAbPuSp4sko/qBl0rsy2c=";
  };
in {
  # Sesiones de Claude Code en la barra. Activar en runtime con:
  #   noctalia msg plugins enable lfdominguez/claude-sessions
  xdg.configFile."noctalia/plugins/claude-sessions".source =
    "${communityPlugins}/claude-sessions";

  # Dependencias declaradas en plugin.toml (kitty es opcional; niri ya viene del sistema)
  home.packages = with pkgs; [
    jq
    curl
    xdg-utils
  ];
}
