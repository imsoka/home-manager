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
      # Trabajo: home-manager switch --flake .#soka
      homeConfigurations."soka" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        # noctalia.nix (plugin de batería) solo en el portátil
        modules = [
          ./home.nix
          ./programs/noctalia/noctalia.nix
          ./programs/noctalia/wallpaper.nix
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };

      # Personal: home-manager switch --flake .#soka-personal
      homeConfigurations."soka-personal" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          ./programs/noctalia/gaming.nix
          ./programs/noctalia/wallpaper.nix
        ];
      };
    };
}
