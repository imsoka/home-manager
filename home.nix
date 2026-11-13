# fingerprintPatch: solo el portátil (soka-work) lleva el icono de huella en Noctalia.
{ config, pkgs, fingerprintPatch ? false, ... }:

{
  # Escritorio encima de la base de terminal (home-cli.nix, que también usa soka-wsl).
  imports = [
    ./home-cli.nix
    ./programs/kitty/kitty.nix
    ./programs/noctalia/claude-sessions.nix
    ./programs/gtk/gtk.nix
    ./window-managers/i3/i3.nix
    ./programs/keepassxc/keepassxc.nix
    ./programs/goldendict/goldendict.nix
    ./programs/learnharness/learnharness.nix
    ./programs/eglantine/eglantine.nix
    ./programs/lichii/lichii.nix
    ./programs/lichii-shader-sync/lichii-shader-sync.nix
    ./window-managers/niri/niri.nix
  ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    grim
    slurp
    brightnessctl
    playerctl
    # Noctalia; con fingerprintPatch, el icono de huella rojo/verde en bloqueo y polkit
    (if fingerprintPatch then
      noctalia.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./programs/noctalia/fingerprint-lockscreen.patch ];
      })
    else
      noctalia)
    wtype
    wowup-cf
  ];

  home.file = {
  };

  home.pointerCursor = {
    enable = true;
    name = "everforest-cursors";
    package = pkgs.everforest-cursors;
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  xsession.windowManager.i3.enable = true;
}
