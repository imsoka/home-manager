{ pkgs, ... }:

{
  # Tema GTK para Thunar y el resto de apps GTK.
  # adw-gtk3 respeta los colores con nombre (@define-color) que escribe la
  # plantilla GTK de Noctalia, así que la paleta sigue al escritorio.
  gtk = {
    enable = true;

    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "Noto Sans";
      size = 10;
    };
  };
}
