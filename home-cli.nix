# Base de terminal, común a todas las configs (también soka-wsl, que no tiene escritorio).
# home.nix la importa y añade encima todo lo gráfico (niri, Noctalia, GTK, kitty…).
{ pkgs, ... }:

{
  imports = [
    ./programs/neovim/neovim.nix
    ./programs/codex/codex.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "soka";
  home.homeDirectory = "/home/soka";

  home.packages = with pkgs; [
    jq
  ];

  home.stateVersion = "24.05"; # Please read the comment before changing.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
