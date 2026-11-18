{
  description = "Home Manager configuration of soka";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ratatidy = {
      url = "github:albert-araque/ratatidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Metadatos de la última release de LearnHarness (versión y AppImage con su
    # sha256). `nix flake update learnharness-release` la refresca.
    learnharness-release = {
      url = "file+https://api.github.com/repos/amosblomqvist/learnharness/releases/latest";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, ratatidy, learnharness-release, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      learnharnessRelease = learnharness-release;
      # Lanza un navegador con un perfil temporal que se borra al cerrarlo
      mkTestBrowser = name: profileArgs: pkgs.writeShellScriptBin "test-${name}" ''
        profile=$(mktemp -d -t "test-${name}.XXXXXX")
        trap 'rm -rf "$profile"' EXIT
        ${profileArgs} "$@"
      '';
    in {
      # Testeo manual de webs: nix develop ~/.config/home-manager#browsers
      devShells.${system}.browsers = pkgs.mkShell {
        packages = [
          (mkTestBrowser "firefox" ''${pkgs.firefox}/bin/firefox --no-remote --profile "$profile"'')
          (mkTestBrowser "chromium" ''${pkgs.chromium}/bin/chromium --user-data-dir="$profile" --no-first-run --no-default-browser-check'')
          (mkTestBrowser "epiphany" ''${pkgs.epiphany}/bin/epiphany --profile="$profile"'')
        ];
        shellHook = ''
          echo "Navegadores de testeo (perfil temporal): test-firefox, test-chromium, test-epiphany <url>"
        '';
      };

      # WSL en el portátil Windows (host NixOS sokix-wsl): solo la base de terminal,
      # sin escritorio. home-manager switch --flake .#soka-wsl
      homeConfigurations."soka-wsl" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home-cli.nix
          ./programs/claude/claude.nix
          ./programs/opencode/opencode.nix
          # NixOS no tiene caché de ldconfig: nvidia-smi (de Windows, en /usr/lib/wsl/lib)
          # no encuentra libnvidia-ml.so.1 si no se le indica dónde está. Va como wrapper
          # delante en el PATH (no alias) para que lo usen también otros programas (llmfit…)
          ({ pkgs, ... }: let
            nvidia-smi = pkgs.writeShellScriptBin "nvidia-smi" ''
              export LD_LIBRARY_PATH=/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
              exec /usr/lib/wsl/lib/nvidia-smi "$@"
            '';
          in { home.sessionVariablesExtra = ''export PATH="${nvidia-smi}/bin:$PATH"''; })
        ];
      };

      # Personal: home-manager switch --flake .#soka
      homeConfigurations."soka" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit ratatidy learnharnessRelease; };
        modules = [
          ./home.nix
          ./programs/ratatidy/ratatidy.nix
          ./programs/noctalia/gaming.nix
          ./programs/steam/steam.nix
          ./programs/discord/discord.nix
          ./programs/pegasus/pegasus.nix
          ./programs/soh/soh.nix
          ./programs/mkw-recomp/mkw-recomp.nix
          ./programs/longshot/longshot.nix
          ./programs/noctalia/wallpaper.nix
          # i3 ya no se usa aquí: se conserva su config (i3.nix) pero sin instalarlo
          { xsession.windowManager.i3.enable = nixpkgs.lib.mkForce false; }
          # node para el hook UserPromptSubmit del plugin ponytail (node -e ...)
          { home.packages = [ pkgs.nodejs ]; }
        ];
      };
    };
}
