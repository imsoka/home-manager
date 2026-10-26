{
  description = "Home Manager configuration of soka";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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

      # Trabajo: home-manager switch --flake .#soka-work
      homeConfigurations."soka-work" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        # noctalia.nix (plugin de batería) y parche de huella solo en el portátil
        extraSpecialArgs = { fingerprintPatch = true; };
        modules = [
          ./home.nix
          ./programs/noctalia/noctalia.nix
          ./programs/noctalia/wallpaper.nix
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };

      # Personal: home-manager switch --flake .#soka
      homeConfigurations."soka" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { fingerprintPatch = false; };
        modules = [
          ./home.nix
          ./programs/noctalia/gaming.nix
          ./programs/steam/steam.nix
          ./programs/discord/discord.nix
          ./programs/pegasus/pegasus.nix
          ./programs/soh/soh.nix
          ./programs/noctalia/wallpaper.nix
          # i3 ya no se usa aquí: se conserva su config (i3.nix) pero sin instalarlo
          { xsession.windowManager.i3.enable = nixpkgs.lib.mkForce false; }
        ];
      };
    };
}
