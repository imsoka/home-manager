{ pkgs, ... }:

# Eglantine (https://github.com/zortos293/Eglantine): emulador experimental de
# Nintendo Switch 2. AppImage de la release nx2-build31-20261101 (build CI),
# con el sha256 publicado en SHA256SUMS de esa release. Para actualizar:
# cambiar la URL y el hash por los de la release nueva.
let
  pname = "eglantine";
  version = "build31";
  src = pkgs.fetchurl {
    url = "https://github.com/zortos293/Eglantine/releases/download/nx2-build31-20261101/eglantine-build31-linux-x86_64-ci-d8a9528.AppImage";
    sha256 = "51ff04c75d09d3a7e0c07e3d7be00d2945d6f1bf71606e4bed418d568f494ecb";
  };
  contents = pkgs.appimageTools.extract { inherit pname version src; };
in
{
  home.packages = [
    (pkgs.appimageTools.wrapAppImage {
      # wrapAppImage espera el AppImage ya extraído (appimage-exec.sh -w)
      inherit pname version;
      src = contents;
      # libgcrypt va incluido en el AppImage pero necesita libgpg-error del sistema
      extraPkgs = p: [ p.libgpg-error ];
      # Lanzador e icono del propio AppImage (su Exec ya es `eglantine`)
      extraInstallCommands = ''
        install -Dm444 ${contents}/usr/share/applications/dev.eden_emu.eden.desktop \
          $out/share/applications/eglantine.desktop
        install -Dm444 ${contents}/dev.eglantine.eglantine.png \
          $out/share/pixmaps/dev.eglantine.eglantine.png
        # El AppImage solo trae el plugin Qt de X11 (sin wayland): va por XWayland
        sed -i '1a export QT_QPA_PLATFORM=xcb' $out/bin/${pname}
      '';
    })
  ];
}
