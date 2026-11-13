{ pkgs, ... }:

# Lichii (https://github.com/zortos293/Lichii), compilado desde fuente en
# package.nix. Convive con Eglantine (programs/eglantine/eglantine.nix).
{
  home.packages = [
    (pkgs.callPackage ./package.nix { })
  ];
}
