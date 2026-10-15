{ pkgs, ... }:

{

  xdg.configFile."niri/config.kdl".source = ./config.kdl;

  # Screencasting (gnome portal) and file pickers (gtk portal) for niri
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.niri = {
      default = [ "gnome" "gtk" ];
    };
    config.common = {
      default = [ "gtk" ];
    };
  };
}
