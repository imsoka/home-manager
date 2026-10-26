{ config, pkgs, ... }:

{
  # Nerd Font: los iconos de Neovim (mini.icons, diagnósticos, git) salen de aquí.
  # fontconfig hace que las fuentes de home-manager estén visibles para todas las apps.
  fonts.fontconfig.enable = true;
  home.packages = [ pkgs.nerd-fonts.sauce-code-pro ];

  programs.kitty = {
    enable = true;

    font = {
      name = "SauceCodePro Nerd Font";
      size = 11;
    };

    settings = {
      # Control remoto por socket: el plugin claude-sessions de Noctalia lo usa para
      # saltar a la pestaña exacta de cada sesión y abrir sesiones nuevas como pestañas.
      allow_remote_control = "socket-only";
      listen_on = "unix:@kitty-{kitty_pid}";

      enable_audio_bell = false;
      confirm_os_window_close = 0;
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      scrollback_lines = 10000;
    };

    # Tema generado por la plantilla de Noctalia. Va al final y tal cual: el hook de Noctalia
    # solo reescribe kitty.conf (que aquí es de solo lectura) si no encuentra esta línea.
    extraConfig = ''
      include themes/noctalia.conf
    '';
  };
}
