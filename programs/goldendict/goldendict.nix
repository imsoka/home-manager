{ pkgs, lib, ... }:

# GoldenDict-ng con un diccionario "Romaji" (kakasi) y JMdict en español e
# inglés para los significados. Mod+Y (config.kdl) abre su ventanita con el
# texto seleccionado.
let
  romaji = pkgs.writeShellApplication {
    name = "goldendict-romaji";
    runtimeInputs = [ pkgs.kakasi ];
    text = builtins.readFile ./romaji.sh;
  };

  # JMdict de jmdict-simplified (versiones fijas; upstream se regenera a
  # diario) convertido a DSL. La versión va en el nombre del fichero para que
  # GoldenDict lo reindexe al actualizar: en el store la fecha no cambia. Los
  # carga por orden alfabético: el prefijo pone el español primero
  jmdictVersion = "3.6.2+20261026175559";
  jmdictSrc = lang: hash: pkgs.fetchurl {
    url = "https://github.com/scriptin/jmdict-simplified/releases/download/${jmdictVersion}/jmdict-${lang}-${jmdictVersion}.json.tgz";
    inherit hash;
  };
  jmdict = pkgs.runCommand "goldendict-jmdict-${lib.replaceStrings [ "+" ] [ "-" ] jmdictVersion}" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    mkdir -p $out
    convert() {
      tar xzf "$1" -O > words.json
      python3 -I ${./jmdict2dsl.py} words.json "$2" "$3" \
        "$out/$4-${lib.replaceStrings [ "+" ] [ "-" ] jmdictVersion}.dsl"
    }
    convert ${jmdictSrc "spa" "sha256-Nj39QxZeYLrOWPYyN3Tlvq7+wasHFm2NnXHVpBeUnsg="} "JMdict (español)" Spanish 1-jmdict-spa
    convert ${jmdictSrc "eng" "sha256-gJ0QT+PB4Ksyj/JlvcUrXu0fm2aQiP0ZnvTnE4EpWKM="} "JMdict (inglés)" English 2-jmdict-eng
  '';
  jmdictDir = ".local/share/goldendict-jmdict";

  # GoldenDict reescribe su config al salir, así que no se puede enlazar desde
  # el store: solo se siembra si aún no existe. Lo que falta toma el valor por
  # defecto
  config = pkgs.writeText "goldendict-config" ''
    <config>
     <paths>
      <path recursive="1">@jmdictDir@</path>
     </paths>
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

  # Añade la carpeta de JMdict a una config ya existente
  addPath = pkgs.writers.writePython3 "goldendict-add-path" { } ''
    import sys
    import xml.etree.ElementTree as ET

    cfg, path = sys.argv[1:]
    tree = ET.parse(cfg)
    paths = tree.getroot().find("paths")
    if paths is None:
        paths = ET.SubElement(tree.getroot(), "paths")
    ET.SubElement(paths, "path", recursive="1").text = path
    tree.write(cfg, encoding="utf-8")
  '';
in {
  home.packages = [ pkgs.goldendict-ng ];

  home.file.${jmdictDir}.source = jmdict;

  home.activation.goldendictConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.config/goldendict/config"
    dir="$HOME/${jmdictDir}"
    if [ ! -e "$cfg" ]; then
      run mkdir -p "$(dirname "$cfg")"
      run sed "s|@jmdictDir@|$dir|" ${config} > "$cfg"
    elif ! grep -qF ">$dir<" "$cfg"; then
      # Al salir guarda su config y quitaría la carpeta: se cierra y se espera
      # a que acabe antes de editar; Mod+Y lo vuelve a abrir. El proceso se
      # llama ".goldendict-wrapped", que el kernel corta a 15 caracteres
      ${pkgs.procps}/bin/pkill -x .goldendict-wra || true
      while ${pkgs.procps}/bin/pgrep -x .goldendict-wra > /dev/null; do sleep 0.2; done
      run ${addPath} "$cfg" "$dir"
    fi
  '';
}
