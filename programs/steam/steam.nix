{ pkgs, ... }:

let
  setDefaultCompatTool = pkgs.writers.writePython3Bin "set-default-compat-tool" {
    libraries = [ pkgs.python3Packages.vdf ];
  } (builtins.readFile ./set-default-compat-tool.py);

  # Va antes que el steam del sistema en el PATH, así que lo usan el .desktop
  # y los lanzadores
  steamWrapper = pkgs.writeShellApplication {
    name = "steam";
    runtimeInputs = with pkgs; [
      curl jq coreutils gnutar gzip findutils procps libnotify util-linux zenity
      setDefaultCompatTool
    ];
    text = builtins.readFile ./steam-proton-ge.sh;
  };

  steamGameWorkspace = pkgs.writeShellApplication {
    name = "steam-game-workspace";
    runtimeInputs = with pkgs; [ niri jq xdotool xprop gnugrep coreutils ];
    text = builtins.readFile ./steam-game-workspace.sh;
  };
in {
  home.packages = [ steamWrapper ];

  systemd.user.services.steam-game-workspace = {
    Unit = {
      Description = "Mueve Steam y sus juegos a workspaces \"steam\" y \"game\" temporales";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${steamGameWorkspace}/bin/steam-game-workspace";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
