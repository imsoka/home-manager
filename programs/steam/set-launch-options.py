# Uso: set-launch-options <raíz de Steam> <ruta de steam-gamescope>
#                           [<appid>=<comando> ...]
# Envuelve las opciones de lanzamiento de todos los juegos instalados con
# steam-gamescope (gamescope a la resolución de la pantalla) y gamemoderun,
# así se aplican también al lanzarlos con steam://rungameid (Pegasus,
# Moonshine). Steam tiene que estar cerrado.
#
# Se respetan las opciones que ya llevan otro gamescope y las que tienen
# NO_GAMESCOPE=1 (para excluir un juego a mano), salvo el gamescope de
# resolución fija que se usaba antes, que pasa a ser steam-gamescope
# conservando sus opciones extra (--mangoapp...). Las variables de entorno se
# quedan delante, el resto de wrappers (mangohud...) detrás de gamemoderun y
# los argumentos del juego detrás de %command%.
#
# Cada <appid>=<comando> pone ese comando delante de todo (tras las variables
# de entorno) en ese juego, p. ej. para abrir un DPS meter con él.
#
# localconfig.vdf se edita como texto, igual que en set-default-compat-tool.
import glob
import os
import re
import shutil
import sys

import vdf

# Gamescope de resolución fija que se ponía antes a mano
OLD_GAMESCOPE = re.compile(
    r"(?<![\w/-])gamescope -W 1920 -H 1080 -F fsr -r 60 -f(?= )")
# Herramientas que también aparecen como apps instaladas
TOOLS = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common)", re.I)

root, gamescope = sys.argv[1], sys.argv[2]
prefixes = dict(arg.split("=", 1) for arg in sys.argv[3:])


def installed_games():
    with open(f"{root}/steamapps/libraryfolders.vdf", encoding="utf-8") as f:
        folders = vdf.load(f)["libraryfolders"]
    games = set()
    for folder in folders.values():
        for appid in folder.get("apps", {}):
            manifest = f"{folder['path']}/steamapps/appmanifest_{appid}.acf"
            try:
                with open(manifest, encoding="utf-8") as f:
                    name = vdf.load(f)["AppState"].get("name", "")
            except (OSError, KeyError, SyntaxError):
                continue
            if not TOOLS.match(name):
                games.add(appid)
    return games


def add_prefix(opts, prefix):
    if prefix in opts.split():
        return opts
    tokens = opts.split(" ")
    i = 0
    while i < len(tokens) and re.match(r"^[A-Za-z_]\w*=", tokens[i]):
        i += 1
    return " ".join(tokens[:i] + [prefix] + tokens[i:])


def wrap(opts, appid):
    opts = wrap_gamescope(opts)
    return add_prefix(opts, prefixes[appid]) if appid in prefixes else opts


def wrap_gamescope(opts):
    opts = OLD_GAMESCOPE.sub(gamescope, opts)
    if "gamescope" in opts or "NO_GAMESCOPE" in opts:
        return opts
    if "%command%" in opts:
        before, after = opts.split("%command%", 1)
    else:
        # Sin %command% todo son argumentos del juego
        before, after = "", f" {opts}" if opts.strip() else ""
    tokens = before.split()
    env = [t for t in tokens if re.match(r"^[A-Za-z_]\w*=", t)]
    wrappers = [t for t in tokens if t not in env and t != "gamemoderun"]
    return " ".join(env + [gamescope, "--", "gamemoderun", *wrappers,
                           "%command%"]) + after.rstrip()


def key_of(line):
    m = re.match(r'\s*"([^"]*)"\s*$', line)
    return m and m.group(1)


def block_end(lines, start):
    # start apunta a la línea "{"; devuelve el índice de su "}"
    depth = 0
    for i in range(start, len(lines)):
        s = lines[i].strip()
        depth += (s == "{") - (s == "}")
        if depth == 0:
            return i
    raise ValueError("llaves sin cerrar")


def children(lines, start, end):
    # Bloques hijos entre start y end: {clave: índice de su línea}
    i, found = start, {}
    while i < end:
        key = key_of(lines[i])
        if key is not None and lines[i + 1].strip() == "{":
            found[key.lower()] = i
            i = block_end(lines, i + 1) + 1
        else:
            i += 1
    return found


def unescape(s):
    return re.sub(r"\\(.)", r"\1", s)


def escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def update(path, games):
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()

    i, end = 0, len(lines)
    for key in ("userlocalconfigstore", "software", "valve", "steam", "apps"):
        i = children(lines, i, end).get(key)
        if i is None:
            return False
        end = block_end(lines, i + 1)
        i += 2

    apps = i - 2
    indent = re.match(r"\s*", lines[apps]).group(0) + "\t"
    changed = False
    for appid in sorted(games, key=int):
        blocks = children(lines, apps + 2, block_end(lines, apps + 1))
        if appid not in blocks:
            at = block_end(lines, apps + 1)
            lines[at:at] = [f'{indent}"{appid}"\n', f"{indent}{{\n",
                            f"{indent}}}\n"]
            blocks[appid] = at
        start = blocks[appid]
        stop = block_end(lines, start + 1)
        opts, at = "", None
        for j in range(start + 2, stop):
            m = re.match(r'\s*"LaunchOptions"\s+"((?:[^"\\]|\\.)*)"\s*$',
                         lines[j])
            if m:
                opts, at = unescape(m.group(1)), j
                break
        new = wrap(opts, appid)
        if new == opts and at is not None:
            continue
        line = f'{indent}\t"LaunchOptions"\t\t"{escape(new)}"\n'
        if at is None:
            lines.insert(start + 2, line)
        else:
            lines[at] = line
        changed = True

    if changed:
        shutil.copy2(path, path + ".bak")
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(lines)
    return changed


games = installed_games()
for path in glob.glob(f"{root}/userdata/*/config/localconfig.vdf"):
    if os.path.getsize(path):
        update(path, games)
