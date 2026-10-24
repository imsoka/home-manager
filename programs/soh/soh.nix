{ pkgs, config, ... }:

# Ship of Harkinian (port de Ocarina of Time). Las ROMs, los .o2r generados,
# las partidas (Save/) y la configuración viven en ~/.local/share/soh, fuera
# del repo a propósito: migrados desde la instalación de Windows (9.2.3).
let
  src = pkgs.shipwright.src;
in {
  home.packages = [ pkgs.shipwright ];

  # Colección "Nativos" de Pegasus (pegasus-library)
  xdg.configFile."pegasus-library/native/soh.json".text = builtins.toJSON {
    id = "soh";
    title = "The Legend of Zelda: Ocarina of Time";
    # Ruta estable del perfil, no del store
    launch = "${config.home.profileDirectory}/bin/soh";
    developers = [ "Harbour Masters" ];
    publishers = [ "Nintendo" ];
    release = "1998-11-21";
    summary = "Ship of Harkinian, el port de PC de Ocarina of Time.";
    assets = {
      boxFront = "${src}/soh/macosx/sohIcon.png";
      logo = "${src}/docs/shiptitle.darkmode.png";
    };
  };
}
