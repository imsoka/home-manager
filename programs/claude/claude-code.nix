# Claude Code (todas las configs; NixOS ya no lo instala). Va por delante de nixpkgs:
# el paquete de nixpkgs con el manifiesto de la versión que fija manifest.zst.json
# (binario oficial de downloads.claude.ai, sin pasar por GitHub).
# Para actualizar: ./update.sh y switch.
{ pkgs, lib, ... }:

{
  home.packages = [
    (pkgs.claude-code.override { manifest = lib.importJSON ./manifest.zst.json; })
  ];
}
