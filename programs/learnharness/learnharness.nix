{ pkgs, learnharnessRelease, ... }:

# LearnHarness (https://github.com/amosblomqvist/learnharness): AppImage de la
# última release de GitHub. La versión, la URL y el sha256 vienen del input
# `learnharness-release` del flake (API de releases), así que
# `nix flake update` también actualiza la app.
let
  pname = "learnharness";
  release = builtins.fromJSON (builtins.readFile learnharnessRelease);
  version = pkgs.lib.removePrefix "v" release.tag_name;
  asset = builtins.head (
    builtins.filter (a: pkgs.lib.hasSuffix "-x86_64.AppImage" a.name) release.assets
  );
  src = pkgs.fetchurl {
    url = asset.browser_download_url;
    sha256 = pkgs.lib.removePrefix "sha256:" asset.digest;
  };
  contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
  # El idioma del dictado (Deepgram) se elige en la app: Ajustes → Providers →
  # Dictation → Language (desde 0.4.0; antes había que parchear el bundle).
in
{
  home.packages = [
    (pkgs.appimageTools.wrapAppImage {
      # wrapAppImage espera el AppImage ya extraído (appimage-exec.sh -w)
      inherit pname version;
      src = contents;
      # Lanzador e icono del propio AppImage, con Exec apuntando al binario envuelto
      extraInstallCommands = ''
        install -Dm444 ${contents}/learnharness.desktop -t $out/share/applications
        substituteInPlace $out/share/applications/learnharness.desktop \
          --replace-fail 'Exec=AppRun --no-sandbox' 'Exec=${pname}'
        cp -r ${contents}/usr/share/icons $out/share
      '';
    })
  ];
}
