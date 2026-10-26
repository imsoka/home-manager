# fingerprintPatch: solo el portátil (soka-work) lleva el icono de huella en Noctalia.
{ config, pkgs, fingerprintPatch ? false, ... }:

{
  imports = [
    ./programs/neovim/neovim.nix
    ./programs/kitty/kitty.nix
    ./programs/noctalia/claude-sessions.nix
    ./programs/codex/codex.nix
    ./programs/gtk/gtk.nix
    ./window-managers/i3/i3.nix
    ./programs/keepassxc/keepassxc.nix
    ./programs/learnharness/learnharness.nix
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
    # Noctalia; con fingerprintPatch, el icono de huella rojo/verde en bloqueo y polkit
    (if fingerprintPatch then
      noctalia.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./programs/noctalia/fingerprint-lockscreen.patch ];
      })
    else
      noctalia)
    wtype
  ];

  home.file = {
  };

  home.stateVersion = "24.05"; # Please read the comment before changing.

  home.pointerCursor = {
    enable = true;
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
