{ config, pkgs, ... }:

{
  imports = [
    ./programs/neovim/neovim.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "soka";
  home.homeDirectory = "/home/soka";

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
  ];

  home.file = {
  };

  home.stateVersion = "24.05"; # Please read the comment before changing.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
