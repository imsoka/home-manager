{ pkgs, ... }:

let
  keepassxcUnlockFollow = pkgs.writeShellApplication {
    name = "keepassxc-unlock-follow";
    runtimeInputs = with pkgs; [ niri jq ];
    text = builtins.readFile ./keepassxc-unlock-follow.sh;
  };
in {

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

  systemd.user.services.keepassxc-unlock-follow = {
    Unit = {
      Description = "Lleva el diálogo de desbloqueo de KeePassXC al workspace activo";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${keepassxcUnlockFollow}/bin/keepassxc-unlock-follow";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
