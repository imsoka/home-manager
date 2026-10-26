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

  # Alerta a pantalla completa (parpadeo rojo + alarma) con la batería baja, para
  # que el portátil no se apague sin avisar. Activar en runtime con:
  #   noctalia msg plugins enable soka/low-battery-alarm
  # Probar sin descargar la batería (y quitar la prueba):
  #   noctalia msg plugin soka/low-battery-alarm:watcher all test 9
  #   noctalia msg plugin soka/low-battery-alarm:watcher all test-off
  xdg.dataFile."noctalia/plugins/low-battery-alarm".source = ./low-battery-alarm;

  # Salud de discos internos (SMART, temperatura). Necesita smartctl; pkexec
  # para leer los discos con permisos. Activar en runtime con:
  #   noctalia msg plugins enable gustav0ar/drive-health
  xdg.configFile."noctalia/plugins/drive-health".source =
    "${communityPlugins}/drive-health";

  # Espacio usado/libre y puntos de montaje de todos los discos montados (y
  # velocidad de lectura/escritura). Necesita nvtop (ya está en gaming.nix en
  # el host personal). Activar en runtime con:
  #   noctalia msg plugins enable arrifat346afs/systempulse
  xdg.configFile."noctalia/plugins/systempulse".source =
    "${communityPlugins}/systempulse";

  # Battery plugin needs these at runtime; vpn-rema usa secret-tool (keyring)
  home.packages = with pkgs; [
    upower
    power-profiles-daemon
    libsecret
    smartmontools   # drive-health: smartctl
    gnome-disk-utility  # GUI "Discos" para particiones, formato y montajes internos
  ];
}
