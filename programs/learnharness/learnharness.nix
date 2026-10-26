{ pkgs, ... }:

# LearnHarness (https://github.com/amosblomqvist/learnharness): AppImage de la
# release de GitHub. Para actualizar, cambia version y hash (sha256 del asset).
let
  pname = "learnharness";
  version = "0.3.8";
  src = pkgs.fetchurl {
    url = "https://github.com/amosblomqvist/learnharness/releases/download/v${version}/LearnHarness-${version}-x86_64.AppImage";
    hash = "sha256-g/mAHXJW/Uu2ZS+/AxpP/hunMlaljq+2tCLv7bQCCzA=";
  };
  contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
in
{
  home.packages = [
    (pkgs.appimageTools.wrapType2 {
      inherit pname version src;
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
