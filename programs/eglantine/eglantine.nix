{ pkgs, ... }:

# Eglantine: emulador experimental de Switch 2. Usa el fork Eglantine-MKW
# (Wael3rd, rama mkw-eglantine), que no publica build de Linux: se compila
# desde fuente en eglantine-mkw.nix. Para volver al AppImage oficial
# (nx2-build-34 PGO), restaurar este fichero desde el historial de git.
{
  home.packages = [
    (pkgs.callPackage ./eglantine-mkw.nix { })
  ];
}
