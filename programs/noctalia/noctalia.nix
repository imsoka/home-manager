{ pkgs, ... }:

let
  communityPlugins = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "community-plugins";
    rev = "a8c5cd1c57ac3dc8a2048c86f5a6dcea71e0e3dd";
    hash = "sha256-6K8x2IB5ExjCleAbGRg4KTpAbPuSp4sko/qBl0rsy2c=";
  };
in {
  # Pinned plugin, enabled at runtime with:
  #   noctalia msg plugins enable piero-93/battery-power-management
  xdg.configFile."noctalia/plugins/battery-power-management".source =
    "${communityPlugins}/battery-power-management";

  # Battery plugin needs these at runtime
  home.packages = with pkgs; [
    upower
    power-profiles-daemon
  ];
}
