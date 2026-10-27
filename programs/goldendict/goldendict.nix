{ pkgs, lib, ... }:

# GoldenDict-ng con un diccionario "Romaji" (kakasi). Mod+Y (config.kdl) abre
# su ventanita con el texto seleccionado.
let
  romaji = pkgs.writeShellApplication {
    name = "goldendict-romaji";
    runtimeInputs = [ pkgs.kakasi ];
    text = builtins.readFile ./romaji.sh;
  };

  # GoldenDict reescribe su config al salir, así que no se puede enlazar desde
  # el store: solo se siembra si aún no existe. Lo que falta toma el valor por
  # defecto
  config = pkgs.writeText "goldendict-config" ''
    <config>
     <programs>
      <program id="9e1c5a0d6b7f4e2a8c3d1f0b5a6e7c4d" name="Romaji" commandLine="${romaji}/bin/goldendict-romaji %GDWORD%" enabled="1" type="2" icon=""/>
     </programs>
     <preferences>
      <enableTrayIcon>1</enableTrayIcon>
      <startToTray>1</startToTray>
      <closeToTray>1</closeToTray>
     </preferences>
    </config>
  '';
in {
  home.packages = [ pkgs.goldendict-ng ];

  home.activation.goldendictConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.config/goldendict/config"
    if [ ! -e "$cfg" ]; then
      run mkdir -p "$(dirname "$cfg")"
      run install -m 644 ${config} "$cfg"
    fi
  '';
}
