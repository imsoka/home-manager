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
    in {
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
          ./programs/noctalia/claude-sessions.nix
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
