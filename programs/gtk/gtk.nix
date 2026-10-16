{ config, pkgs, ... }:

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

    # Mantiene el comportamiento anterior (GTK4 usa el mismo tema que GTK3).
    gtk4.theme = config.gtk.theme;

    # La plantilla GTK de Noctalia reescribe gtk.css para añadir este import;
    # se genera ya incluido para que el resultado sea el mismo
    gtk4.extraCss = ''
      @import url("noctalia.css");
    '';

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "Noto Sans";
      size = 10;
    };
  };

  # Noctalia cambia el enlace por un archivo normal al regenerar el tema;
  # sin force el siguiente switch se negaría a sobrescribirlo
  xdg.configFile."gtk-4.0/gtk.css".force = true;
}
