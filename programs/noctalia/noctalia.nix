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

  # Plugin de la VPN rema (openfortivpn). Wrapper y polkit están en NixOS
  # (nixos/hosts/work/vpn-rema.nix). Activar en runtime con:
  #   noctalia msg plugins enable soka/vpn-rema
  # Noctalia solo escanea plugins locales en ~/.local/share/noctalia/plugins
  xdg.dataFile."noctalia/plugins/vpn-rema".source = ./vpn-rema;

  # Battery plugin needs these at runtime; vpn-rema usa secret-tool (keyring)
  home.packages = with pkgs; [
    upower
    power-profiles-daemon
    libsecret
  ];
}
