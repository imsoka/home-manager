{ pkgs, ... }:

# Selector de fondos (carrusel) para work y personal.
# Mismo rev que noctalia.nix y gaming.nix.
let
  communityPlugins = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "community-plugins";
    rev = "a8c5cd1c57ac3dc8a2048c86f5a6dcea71e0e3dd";
    hash = "sha256-6K8x2IB5ExjCleAbGRg4KTpAbPuSp4sko/qBl0rsy2c=";
  };
in {
  # Activar en runtime con:
  #   noctalia msg plugins enable ashur-d/wallpaper-widget
  xdg.configFile."noctalia/plugins/wallpaper-widget".source =
    "${communityPlugins}/wallpaper-widget";
}
