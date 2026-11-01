{ pkgs, ... }:

# Eglantine (https://github.com/zortos293/Eglantine): emulador experimental de
# Nintendo Switch 2. AppImage PGO de la release nx2-build-34 (las builds -pgo
# son las recomendadas por el autor si la CPU lo soporta). Esa release no
# publica SHA256SUMS: el sha256 se ha calculado descargando el fichero. Para
# actualizar: cambiar la URL y el hash por los de la release nueva.
let
  pname = "eglantine";
  version = "build34-pgo";
  src = pkgs.fetchurl {
    url = "https://github.com/zortos293/Eglantine/releases/download/nx2-build-34/eglantine-nx2-build-34-linux-x86_64-pgo.AppImage";
    sha256 = "630346127765bb35838061bd9baada43161480ff29d60e392f91ce6a5f951f31";
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
