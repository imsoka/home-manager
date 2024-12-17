{ config, pkgs, ... }:

{
  xsession.windowManager.i3 = {
    config = {
      modifier = "Mod4";
      workspaceAutoBackAndForth = true;

      keybindings =
      let
        modifier = config.xsession.windowManager.i3.config.modifier;
        workspaces = [
            "1: term"
            "2: internet"
        ];
      in {
        # Program binds
        "${modifier}+Return" = "exec alacritty";
        "${modifier}+Shift+q" = "kill";
        "${modifier}+d" = "exec --no-startup-id dmenu_run";

        #Focus binds
        "${modifier}+h" = "focus left";
        "${modifier}+j" = "focus down";
        "${modifier}+k" = "focus up";
        "${modifier}+l" = "focus right";

        "${modifier}+Shift+h" = "move left";
        "${modifier}+Shift+j" = "move down";
        "${modifier}+Shift+k" = "move up";
        "${modifier}+Shift+l" = "move right";

        #Fullscreen
        "${modifier}+f" = "fullscreen toggle";

        #Workspaces
        "${modifier}+1" = "workspace 1: term";
        "${modifier}+2" = "workspace 2: internet";
        "${modifier}+3" = "workspace number 3";
        "${modifier}+4" = "workspace number 4";
        "${modifier}+5" = "workspace number 5";
        "${modifier}+6" = "workspace number 6";
        "${modifier}+7" = "workspace number 7";
        "${modifier}+8" = "workspace number 8";
        "${modifier}+9" = "workspace number 9";
        "${modifier}+0" = "workspace number 0";

        #Move window to workspace
        "${modifier}+Shift+1" = "move container to workspace 1: term";
        "${modifier}+Shift+2" = "move container to workspace 2: internet";
        "${modifier}+Shift+3" = "move container to workspace number 3";
        "${modifier}+Shift+4" = "move container to workspace number 4";
        "${modifier}+Shift+5" = "move container to workspace number 5";
        "${modifier}+Shift+6" = "move container to workspace number 6";
        "${modifier}+Shift+7" = "move container to workspace number 7";
        "${modifier}+Shift+8" = "move container to workspace number 8";
        "${modifier}+Shift+9" = "move container to workspace number 9";
        "${modifier}+Shift+0" = "move container to workspace number 0";

        "${modifier}+Space" = "floating toggle";
        "${modifier}+Shift+Space" = "focus mode_toggle";

        "${modifier}+Shift+c" = "reload";
        "${modifier}+Shift+r" = "restart";

        "${modifier}+Shift+s" = "move scratchpad";
        "${modifier}+Control+s" = "scratchpad show";
      };

      defaultWorkspace = "workspace 1: term";

      window = {
        border = 0;
        titlebar = false;
      };

      floating = {
        modifier = "Mod4";
        border = 0;
        titlebar = false;
      };

      gaps = {
        inner = 5;
      };

      startup = [
        { command = "nitrogen --set-zoom-fill --random"; always = true; notification = false; }
        { command = "nextcloud --background"; always = true; notification = false; }
      ];
    };
  };
}
