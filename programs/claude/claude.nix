# Claude Code comparte inicio de sesión entre NixOS-WSL y Windows con un token de larga
# duración (`claude setup-token`, ~1 año). El token es secreto: vive solo en
# ~/.config/claude-code/oauth-token (chmod 600, fuera del repo y del store). Aquí se
# exporta en bash; en Windows, install.ps1 lo lee de \\wsl.localhost y lo pone como
# variable de usuario. Al renovarlo: sobrescribe el fichero y relanza install.ps1.
#
# Claude Code va por delante de nixpkgs: el paquete de nixpkgs con el manifiesto de
# la versión que fija manifest.zst.json (binario oficial de downloads.claude.ai).
# Para actualizar: ./update.sh y switch. Gana en el PATH al que instala el repo nixos.
{ pkgs, lib, ... }:

{
  home.packages = [
    (pkgs.claude-code.override { manifest = lib.importJSON ./manifest.zst.json; })
  ];

  programs.bash = {
    enable = true;
    bashrcExtra = ''
      if [ -r "$HOME/.config/claude-code/oauth-token" ]; then
        # setup-token parte el token en varias líneas al mostrarlo: se quitan los espacios
        _cct="$(< "$HOME/.config/claude-code/oauth-token")"
        export CLAUDE_CODE_OAUTH_TOKEN="''${_cct//[[:space:]]/}"
        unset _cct
      fi
    '';
  };
}
