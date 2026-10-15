{ config, pkgs, ... }:

{
  imports = [
    ./programs/neovim/neovim.nix
    ./programs/codex/codex.nix
    ./programs/gtk/gtk.nix
    ./window-managers/i3/i3.nix
    ./window-managers/niri/niri.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "soka";
  home.homeDirectory = "/home/soka";

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    grim
    slurp
    brightnessctl
    playerctl
    jq
    # Noctalia con el icono de huella rojo/verde en la pantalla de bloqueo
    (noctalia.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./programs/noctalia/fingerprint-lockscreen.patch ];
    }))
    wtype
  ];

  home.file = {
  };

  home.stateVersion = "24.05"; # Please read the comment before changing.

  home.pointerCursor = {
    name = "everforest-cursors";
    package = pkgs.everforest-cursors;
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  xsession.windowManager.i3.enable = true;
}
