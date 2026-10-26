{ pkgs, ratatidy, ... }:

# Ratatidy en modo remoto: la TUI corre aquí y el Agent en el servidor de
# medios (Debian) hace el escaneo, el borrado y qBittorrent por SSH.
{
  home.packages = [ ratatidy.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  xdg.configFile."ratatidy/config.toml".text = ''
    remote = "administrador@100.124.230.63"
  '';
}
