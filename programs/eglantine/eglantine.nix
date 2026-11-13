{ pkgs, ... }:

# Eglantine (https://github.com/zortos293/Eglantine): emulador experimental de
# Nintendo Switch 2. AppImage PGO de la build 135 del fork Djihads80/Eglantine
# (las builds -pgo son las recomendadas por el autor si la CPU lo soporta). Esa
# release no publica SHA256SUMS: el sha256 se ha calculado descargando el
# fichero. Para actualizar: cambiar la URL y el hash por los de la release nueva.
let
  pname = "eglantine";
  version = "build135-pgo";
  src = pkgs.fetchurl {
    url = "https://github.com/Djihads80/Eglantine/releases/download/build-135/eglantine-62214094d6c698b70f51016e5c12af415f025be7-linux-x86_64-pgo.AppImage";
    sha256 = "696ec244836631d472574eb6786aac40dcfac5a39947e1e94ec5891f7717e6d0";
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
