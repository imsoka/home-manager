{ pkgs, ... }:

# Lichii Shader Sync (https://github.com/oceanpacificpeace/lichii-shader-sync):
# binario estático de Go de la release v1.1.2, con el sha256 de su SHA256SUMS.txt.
# Para actualizar: cambiar `version` y `sha256` con los de la nueva release.
let
  version = "1.1.2";
in
{
  home.packages = [
    (pkgs.stdenvNoCC.mkDerivation {
      pname = "lichii-shader-sync";
      inherit version;
      src = pkgs.fetchurl {
        url = "https://github.com/oceanpacificpeace/lichii-shader-sync/releases/download/v${version}/lichii-sync-linux-amd64";
        sha256 = "fd37dc83a2d74fa02bb96afc5e8cc57f8e05157a3073a3f1f1e79fd3c2d1aeae";
      };
      dontUnpack = true;
      installPhase = ''
        install -Dm755 $src $out/bin/lichii-sync
      '';
      meta = {
        description = "Descarga cachés de shaders Vulkan compartidas para Lichii / Eden";
        homepage = "https://github.com/oceanpacificpeace/lichii-shader-sync";
        mainProgram = "lichii-sync";
        platforms = [ "x86_64-linux" ];
      };
    })
  ];
}
