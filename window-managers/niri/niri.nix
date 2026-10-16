{ pkgs, ... }:

{

  xdg.configFile."niri/config.kdl".source = ./config.kdl;

  # niri arranca xwayland-satellite solo si está en el PATH; sin él no hay
  # DISPLAY y las apps X11 (Steam) no abren
  home.packages = [ pkgs.xwayland-satellite ];

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
