# Genera la biblioteca de Pegasus a partir de Steam, Heroic y los juegos
# nativos, como los plugins de biblioteca de Playnite: cada tienda junta lo
# instalado (archivos locales) con todo lo comprado (online o caché del
# launcher).
#
# - Steam: appmanifest_*.acf de cada biblioteca + IPlayerService/GetOwnedGames
#   (necesita API key en ~/.config/pegasus-library/steam-api-key; sin ella
#   solo salen los instalados). Datos e imágenes de IStoreBrowseService.
# - Heroic (Epic, GOG, Amazon, Zoom y juegos añadidos a mano): sus cachés en
#   ~/.config/heroic, que ya tienen la biblioteca completa con imágenes.
# - Nativos (ports de Linux sin tienda): un JSON por juego en
#   ~/.config/pegasus-library/native, que escribe home-manager.
#
# El tiempo jugado sale de las tiendas y sustituye al que cuenta Pegasus en
# stats.db: Pegasus lanza los juegos a través de Steam o Heroic, que son
# quienes saben cuánto se ha jugado.
# - Steam: playtime_forever de GetOwnedGames y Playtime de localconfig.vdf
# - Heroic: store/timestamp.json, que apunta lo jugado desde Heroic
#
# Cada colección va en su propio directorio porque Pegasus mete cada juego en
# todas las colecciones declaradas antes que él en el mismo archivo. Esos
# directorios se registran en game_dirs.txt de Pegasus.
import io
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import vdf
from PIL import Image

HOME = Path.home()
CONFIG = HOME / ".config/pegasus-library"
NATIVE = CONFIG / "native"
DATA = HOME / ".local/share/pegasus-library"
COLLECTIONS = DATA / "collections"
MEDIA = DATA / "media"
CACHE = HOME / ".cache/pegasus-library"
PEGASUS_GAME_DIRS = HOME / ".config/pegasus-frontend/game_dirs.txt"
PEGASUS_STATS = HOME / ".config/pegasus-frontend/stats.db"
STEAM = HOME / ".local/share/Steam"
HEROIC = HOME / ".config/heroic"

# Lanza un juego instalado y espera a que se cierre (vuelve a Pegasus)
PLAY_CMD = os.environ.get("PEGASUS_LIBRARY_PLAY", "pegasus-play")
HEROIC_CMD = os.environ.get("PEGASUS_LIBRARY_HEROIC", "heroic")
INSTALL_CMD = os.environ.get("PEGASUS_LIBRARY_INSTALL", "heroic-install")
STEAM_INSTALL_CMD = os.environ.get("PEGASUS_LIBRARY_STEAM_INSTALL",
                                   "steam-install")
# Tiendas que heroic-install sabe instalar sin la ventana de Heroic
UNATTENDED = {"legendary", "nile"}
# Tiendas que pegasus-uninstall sabe desinstalar (los juegos añadidos a mano
# en Heroic no: no se sabe qué borrar)
UNINSTALLABLE = {"steam", "legendary", "nile", "gog", "zoom"}

STEAM_CDN = "https://shared.akamai.steamstatic.com/store_item_assets/"
STEAM_STORE_TTL = 7 * 24 * 3600
MISSING_RETRY = 7 * 24 * 3600

# Las imágenes se guardan en WebP (Pegasus lo lee con qtimageformats) y como
# mucho al tamaño al que las enseña el tema en el stream a 1080p: las de las
# tiendas llegan a 4K y ocupaban diez veces más.
ASSET_SIZES = {
    "boxFront": (600, 900),
    "background": (1920, 1080),
    "logo": (800, 400),
}
WEBP_QUALITY = 80
# Formatos en los que se guardaban antes: se convierten sin volver a
# descargarlos
OLD_EXTS = (".jpg", ".jpeg", ".png", ".webp")

# Herramientas que Steam instala como apps y no tienen ficha en la tienda
STEAM_TOOLS = re.compile(
    r"^(Proton |Proton$|Steam Linux Runtime|Steamworks Common"
    r"|Steam Runtime|SteamVR)"
)

# Tienda de Heroic: (archivo de caché, clave, colección, orden)
HEROIC_STORES = {
    "legendary": ("store_cache/legendary_library.json", "library", "Epic"),
    "gog": ("store_cache/gog_library.json", "games", "GOG"),
    "nile": ("store_cache/nile_library.json", "library", "Amazon"),
    "zoom": ("store_cache/zoom_library.json", "games", "Zoom"),
    "sideload": ("sideload_apps/library.json", "games", "Otros"),
}
COLLECTION_ORDER = ["Steam", "Epic", "GOG", "Amazon", "Zoom", "Otros",
                    "Nativos"]
# shortname de la colección: el tema Reprise pone el icono
# assets/platforms/<shortname>.svg; sin icono muestra el nombre
SHORTNAMES = {
    "Steam": "steam", "Epic": "epic", "GOG": "gog", "Amazon": "amazon",
    "Nativos": "nixos",
}


@dataclass
class Game:
    source: str
    id: str
    title: str
    installed: bool
    launch: str
    collection: str
    developers: list = field(default_factory=list)
    publishers: list = field(default_factory=list)
    summary: str = ""
    release: str = ""
    # tipo de asset de Pegasus -> ruta local
    assets: dict = field(default_factory=dict)
    # Segundos jugados según la tienda; None si no se pudo saber (no se
    # toca lo que tenga Pegasus)
    playtime: int | None = None
    # Fin de la última partida (epoch), 0 si no se sabe
    last_played: int = 0


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def read_json(path, default=None):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def http_get(url, timeout=20):
    # Algunas imágenes de Epic llevan espacios en la ruta
    parts = urllib.parse.urlsplit(url)
    url = parts._replace(
        path=urllib.parse.quote(parts.path, safe="/%:@!$&'()*+,;=-._~")
    ).geturl()
    req = urllib.request.Request(
        url, headers={"User-Agent": "pegasus-library/1.0"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def http_json(url, params=None):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    return json.loads(http_get(url))


# --- Imágenes -------------------------------------------------------------

def fits(path, size):
    """Si ya es un WebP dentro del tamaño máximo."""
    try:
        with Image.open(path) as im:
            return (im.format == "WEBP"
                    and im.width <= size[0] and im.height <= size[1])
    except (OSError, ValueError, Image.DecompressionBombError):
        return False


def save_webp(src, dest, size):
    """Reduce la imagen src (ruta o bytes) a size y la guarda en WebP."""
    with Image.open(io.BytesIO(src) if isinstance(src, bytes) else src) as im:
        # Los JPEG se decodifican ya a escala reducida (mucho más rápido)
        im.draft("RGB", size)
        alpha = (im.mode in ("RGBA", "LA", "PA")
                 or (im.mode == "P" and "transparency" in im.info))
        im = im.convert("RGBA" if alpha else "RGB")
    im.thumbnail(size, Image.LANCZOS)
    im.save(dest, "WEBP", quality=WEBP_QUALITY)


def fetch_asset(dest, sources):
    """Guarda en dest (WebP) la primera fuente disponible.

    sources: rutas locales (Path) o URLs (str), por orden de preferencia.
    Si ninguna existe deja un marcador .missing para no reintentar en cada
    ejecución.
    """
    size = ASSET_SIZES[dest.stem]
    if dest.exists() and fits(dest, size):
        return dest
    old = [p for p in (dest.with_suffix(e) for e in OLD_EXTS) if p.is_file()]
    missing = dest.with_suffix(dest.suffix + ".missing")
    if not old and missing.exists():
        if time.time() - missing.stat().st_mtime < MISSING_RETRY:
            return None
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    for src in old + sources:
        if not src:
            continue
        try:
            if isinstance(src, Path):
                if not src.is_file():
                    continue
                save_webp(src, tmp, size)
            else:
                save_webp(http_get(src), tmp, size)
            tmp.replace(dest)
            missing.unlink(missing_ok=True)
            for p in old:
                if p != dest:
                    p.unlink(missing_ok=True)
            return dest
        except (OSError, ValueError, Image.DecompressionBombError):
            # URL, archivo o imagen inválidos: se prueba la siguiente fuente
            continue
    tmp.unlink(missing_ok=True)
    missing.touch()
    return None


def clean_media_dir(path):
    """Restos de versiones anteriores: el banner "steam" (el tema no lo usa)
    y los marcadores .missing de cuando se guardaban en JPEG o PNG."""
    if not path.is_dir():
        return
    for f in path.iterdir():
        if (f.name.startswith("steam.")
                or (f.name.endswith(".missing")
                    and not f.name.endswith(".webp.missing"))):
            f.unlink(missing_ok=True)


def resolve_assets(games, plans):
    """plans: {(índice, asset): (destino, [fuentes])}, en paralelo."""
    for path in {dest.parent for dest, _ in plans.values()}:
        clean_media_dir(path)
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {
            key: pool.submit(fetch_asset, dest, sources)
            for key, (dest, sources) in plans.items()
        }
    for (i, asset), fut in futures.items():
        path = fut.result()
        if path:
            games[i].assets[asset] = path


# --- Steam ----------------------------------------------------------------

def steam_library_dirs():
    data = read_vdf(STEAM / "steamapps/libraryfolders.vdf")
    folders = data.get("libraryfolders", {}) if data else {}
    dirs = [Path(v["path"]) for v in folders.values()
            if isinstance(v, dict) and "path" in v]
    return dirs or [STEAM]


def read_vdf(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return vdf.load(f)
    except (OSError, SyntaxError):
        return None


def steam_installed():
    games = {}
    for lib in steam_library_dirs():
        for acf in (lib / "steamapps").glob("appmanifest_*.acf"):
            state = (read_vdf(acf) or {}).get("AppState", {})
            appid, name = state.get("appid"), state.get("name", "")
            flags = int(state.get("StateFlags", "0") or 0)
            if appid and flags & 4 and not STEAM_TOOLS.match(name):
                games[appid] = name
    return games


def steam_user_id():
    if os.environ.get("STEAM_ID"):
        return os.environ["STEAM_ID"]
    users = (read_vdf(STEAM / "config/loginusers.vdf") or {}).get("users", {})
    for steamid, info in users.items():
        if str(info.get("MostRecent", "0")) == "1":
            return steamid
    return next(iter(users), None)


def steam_owned():
    key_file = CONFIG / "steam-api-key"
    if not key_file.exists():
        log("steam: sin API key en", key_file, "-> solo instalados")
        return None
    steamid = steam_user_id()
    if not steamid:
        log("steam: no se encuentra el usuario en loginusers.vdf")
        return None
    try:
        resp = http_json(
            "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/",
            {
                "key": key_file.read_text().strip(),
                "steamid": steamid,
                "include_appinfo": 1,
                "include_played_free_games": 1,
                "format": "json",
            },
        )
    except (OSError, ValueError) as e:
        log("steam: fallo al pedir la biblioteca:", e)
        return None
    return {str(g["appid"]): g
            for g in resp.get("response", {}).get("games", [])}


def steam_local_playtime():
    """appid -> (minutos, última partida) de localconfig.vdf, o None."""
    steamid = steam_user_id()
    if not steamid:
        return None
    # La carpeta de userdata es el id de cuenta (32 bits) del SteamID64
    account = int(steamid) - 76561197960265728 if len(steamid) == 17 \
        else int(steamid)
    data = read_vdf(STEAM / f"userdata/{account}/config/localconfig.vdf")
    if data is None:
        return None
    node = data
    # Las mayúsculas de cada clave cambian según la versión de Steam
    for key in ("UserLocalConfigStore", "Software", "Valve", "Steam", "apps"):
        node = next((v for k, v in node.items()
                     if k.lower() == key.lower() and isinstance(v, dict)), {})
    out = {}
    for appid, info in node.items():
        if isinstance(info, dict) and "Playtime" in info:
            out[appid] = (int(info.get("Playtime") or 0),
                          int(info.get("LastPlayed") or 0))
    return out


def steam_store_items(appids):
    """Ficha de la tienda (datos e imágenes) con caché en disco."""
    cache_dir = CACHE / "steam-store"
    cache_dir.mkdir(parents=True, exist_ok=True)
    items, pending = {}, []
    for appid in appids:
        path = cache_dir / f"{appid}.json"
        fresh = (path.exists()
                 and time.time() - path.stat().st_mtime < STEAM_STORE_TTL)
        if fresh:
            items[appid] = read_json(path, {})
        else:
            pending.append(appid)
    for i in range(0, len(pending), 100):
        batch = pending[i:i + 100]
        request = {
            "ids": [{"appid": int(a)} for a in batch],
            "context": {"language": "spanish", "country_code": "ES"},
            "data_request": {
                "include_assets": True,
                "include_basic_info": True,
                "include_release": True,
            },
        }
        try:
            resp = http_json(
                "https://api.steampowered.com/IStoreBrowseService/"
                "GetItems/v1/",
                {"input_json": json.dumps(request)},
            )
        except (OSError, ValueError) as e:
            log("steam: fallo al pedir fichas de la tienda:", e)
            continue
        found = {str(it.get("appid")): it
                 for it in resp.get("response", {}).get("store_items", [])}
        for appid in batch:
            # Sin ficha (retirado de la tienda): se guarda vacío igualmente
            item = found.get(appid, {})
            (cache_dir / f"{appid}.json").write_text(json.dumps(item))
            items[appid] = item
    return items


def steam_local_image(appid, name):
    base = STEAM / "appcache/librarycache" / appid
    direct = base / name
    if direct.is_file():
        return direct
    return next(base.glob(f"*/{name}"), None) if base.is_dir() else None


def steam_games():
    installed = steam_installed()
    owned_raw = steam_owned()
    owned = {appid: g.get("name", appid)
             for appid, g in (owned_raw or {}).items()}
    titles = {**owned, **installed}
    local_playtime = steam_local_playtime()
    # Sin ninguna de las dos fuentes no se sabe nada: no se toca Pegasus
    know_playtime = owned_raw is not None or local_playtime is not None
    store = steam_store_items(sorted(titles))

    games, plans = [], {}
    for appid, title in titles.items():
        item = store.get(appid, {})
        info = item.get("basic_info", {})
        is_installed = appid in installed
        # Sin instalar: steam-install, que lo instala en /games sin preguntar
        launch = (f"{PLAY_CMD} steam {appid}" if is_installed
                  else f"{STEAM_INSTALL_CMD} {appid}")
        release = item.get("release", {}).get("steam_release_date")
        game = Game(
            source="steam",
            id=appid,
            title=title,
            installed=is_installed,
            launch=launch,
            collection="Steam",
            developers=[d["name"] for d in info.get("developers", [])],
            publishers=[p["name"] for p in info.get("publishers", [])],
            summary=info.get("short_description", ""),
            release=(time.strftime("%Y-%m-%d", time.gmtime(release))
                     if release else ""),
        )
        if know_playtime:
            # Las dos van en minutos; vale la más reciente (la API va al día
            # con otros PCs y localconfig.vdf sin red)
            api = (owned_raw or {}).get(appid, {})
            local = (local_playtime or {}).get(appid, (0, 0))
            game.playtime = 60 * max(int(api.get("playtime_forever") or 0),
                                     local[0])
            game.last_played = max(int(api.get("rtime_last_played") or 0),
                                   local[1])
        idx = len(games)
        games.append(game)

        assets = item.get("assets", {})
        fmt = assets.get("asset_url_format",
                         f"steam/apps/{appid}/${{FILENAME}}")

        def cdn(key, fallback, fmt=fmt, assets=assets):
            return STEAM_CDN + fmt.replace(
                "${FILENAME}", assets.get(key, fallback))

        media = MEDIA / "steam" / appid
        for asset, local, key, fallback in (
            ("boxFront", "library_600x900.jpg", "library_capsule_2x",
             "library_600x900_2x.jpg"),
            ("background", "library_hero.jpg", "library_hero",
             "library_hero.jpg"),
            ("logo", "logo.png", None, "logo.png"),
        ):
            sources = [steam_local_image(appid, local)]
            if key:
                sources.append(cdn(key, fallback))
            sources.append(STEAM_CDN + f"steam/apps/{appid}/{fallback}")
            dest = media / (asset + ".webp")
            plans[(idx, asset)] = (dest, sources)
    resolve_assets(games, plans)
    return games


# --- Heroic ---------------------------------------------------------------

def heroic_installed(runner):
    """Ids instalados según cada gestor (la caché puede ir atrasada)."""
    if runner == "legendary":
        data = read_json(HEROIC / "legendaryConfig/legendary/installed.json")
        return set(data or {})
    if runner == "gog":
        data = read_json(HEROIC / "gog_store/installed.json", {})
        return {g.get("appName") for g in data.get("installed", [])}
    if runner == "nile":
        data = read_json(HEROIC / "nile_config/nile/installed.json", [])
        return {g.get("id") for g in data}
    if runner == "zoom":
        data = read_json(HEROIC / "zoom_store/installed.json", {})
        return {g.get("appName") for g in data.get("installed", [])}
    return None


def heroic_playtime():
    """appName -> (minutos, última partida) de lo jugado desde Heroic."""
    if not HEROIC.is_dir():
        return None
    # No existe hasta que se juega algo desde Heroic
    data = read_json(HEROIC / "store/timestamp.json", {}) or {}
    out = {}
    for app_name, info in data.items():
        if not isinstance(info, dict):
            continue
        try:
            last = int(datetime.fromisoformat(info["lastPlayed"]).timestamp())
        except (KeyError, TypeError, ValueError):
            last = 0
        out[app_name] = (int(info.get("totalPlayed") or 0), last)
    return out


def heroic_games():
    games, plans = [], {}
    playtime = heroic_playtime()
    for runner, (cache, key, collection) in HEROIC_STORES.items():
        library = (read_json(HEROIC / cache, {}) or {}).get(key) or []
        installed = heroic_installed(runner)
        for info in library:
            app_name = info.get("app_name")
            if not app_name or info.get("install", {}).get("is_dlc"):
                continue
            is_installed = (app_name in installed if installed is not None
                            else bool(info.get("is_installed")))
            extra = info.get("extra") or {}
            about = extra.get("about") or {}
            # Epic y Amazon se instalan en segundo plano; el resto (GOG, o
            # juegos de Epic que gestiona EA o Ubisoft) pasa por Heroic, que
            # pregunta si instalarlo
            unattended = (runner in UNATTENDED
                          and not info.get("thirdPartyManagedApp"))
            if is_installed:
                launch = f"{PLAY_CMD} {runner} {app_name}"
            elif not unattended:
                launch = (f"{HEROIC_CMD} --no-gui "
                          f"heroic://launch/{runner}/{app_name}")
            else:
                launch = f"{INSTALL_CMD} {runner} {app_name}"
            game = Game(
                source=runner,
                id=app_name,
                title=info.get("title") or app_name,
                installed=is_installed,
                launch=launch,
                collection=collection,
                developers=[d for d in [info.get("developer")] if d],
                summary=(about.get("shortDescription")
                         or about.get("description")
                         or info.get("description") or ""),
            )
            if playtime is not None:
                minutes, game.last_played = playtime.get(app_name, (0, 0))
                game.playtime = 60 * minutes
            idx = len(games)
            games.append(game)

            safe_id = re.sub(r"[^A-Za-z0-9._-]", "_", app_name)
            media = MEDIA / runner / safe_id
            for asset, srcs in (
                ("boxFront", [info.get("art_square")]),
                ("background", [info.get("art_background"),
                                info.get("art_cover")]),
                ("logo", [info.get("art_logo")]),
            ):
                sources = [s if s.startswith("http") else Path(s)
                           for s in srcs if s]
                if sources:
                    dest = media / (asset + ".webp")
                    plans[(idx, asset)] = (dest, sources)
    resolve_assets(games, plans)
    return games


# --- Nativos --------------------------------------------------------------

def native_games():
    """Juegos de Linux sin tienda: un JSON por juego en NATIVE, que escribe
    home-manager (id, title, launch y opcionalmente developers, publishers,
    release, summary y assets: {tipo: ruta o URL})."""
    games, plans = [], {}
    for path in sorted(NATIVE.glob("*.json")):
        info = read_json(path)
        if not info or not info.get("launch"):
            log(f"nativos: {path.name} sin launch, se ignora")
            continue
        game_id = info.get("id") or path.stem
        idx = len(games)
        # Pegasus lo lanza directamente y espera a que se cierre; el tiempo
        # jugado lo cuenta él (playtime None: no se toca)
        games.append(Game(
            source="native",
            id=game_id,
            title=info.get("title") or game_id,
            installed=True,
            launch=info["launch"],
            collection="Nativos",
            developers=info.get("developers") or [],
            publishers=info.get("publishers") or [],
            release=info.get("release") or "",
            summary=info.get("summary") or "",
        ))
        safe_id = re.sub(r"[^A-Za-z0-9._-]", "_", game_id)
        for asset, src in (info.get("assets") or {}).items():
            if asset in ASSET_SIZES and src:
                source = src if src.startswith("http") else Path(src)
                dest = MEDIA / "native" / safe_id / (asset + ".webp")
                plans[(idx, asset)] = (dest, [source])
    resolve_assets(games, plans)
    return games


# --- Salida para Pegasus --------------------------------------------------

def clean(text):
    return " ".join(str(text).split())


def write_collection(name, shortname, sort_key, games, path):
    lines = [f"collection: {name}", f"sort-by: {sort_key}"]
    if shortname:
        lines.append(f"shortname: {shortname}")
    lines.append("")
    for g in sorted(games, key=lambda g: g.title.lower()):
        lines.append(f"game: {clean(g.title)}")
        # Pegasus descarta los juegos sin ningún file:. Vale una URI, y es
        # también la clave de sus estadísticas: no cambia al instalar el
        # juego (steam:<appid> es la misma que usa el lector de Steam)
        lines.append(f"file: {g.source}:{g.id}")
        lines.append(f"launch: {g.launch}")
        if g.developers:
            lines.append("developers: " + ", ".join(map(clean, g.developers)))
        if g.publishers:
            lines.append("publishers: " + ", ".join(map(clean, g.publishers)))
        if g.release:
            lines.append(f"release: {g.release}")
        if g.summary:
            lines.append(f"summary: {clean(g.summary)}")
        for asset, file in sorted(g.assets.items()):
            lines.append(f"assets.{asset}: {file}")
        lines.append(f"x-source: {g.source}")
        lines.append(f"x-id: {g.id}")
        # El tema enseña "Install" en vez de "Play" (lanzarlo lo instala)
        if not g.installed:
            lines.append("x-installed: no")
        # El tema enseña "Desinstalar" (X) en los detalles
        if g.installed and g.source in UNINSTALLABLE:
            lines.append("x-uninstall: yes")
        lines.append("")
    path.mkdir(parents=True, exist_ok=True)
    tmp = path / "metadata.pegasus.txt.tmp"
    tmp.write_text("\n".join(lines), encoding="utf-8")
    tmp.replace(path / "metadata.pegasus.txt")


def update_game_dirs(dirs):
    """Deja en game_dirs.txt las colecciones actuales sin tocar el resto."""
    prefix = str(COLLECTIONS) + "/"
    existing = []
    if PEGASUS_GAME_DIRS.exists():
        existing = PEGASUS_GAME_DIRS.read_text().splitlines()
    kept = [line for line in existing
            if line.strip() and not line.startswith(prefix)]
    new = kept + [str(d) for d in dirs]
    if new != existing:
        PEGASUS_GAME_DIRS.parent.mkdir(parents=True, exist_ok=True)
        PEGASUS_GAME_DIRS.write_text("\n".join(new) + "\n")


def update_stats(games):
    """Deja en stats.db de Pegasus el tiempo de cada tienda.

    Pegasus suma las partidas (plays) de cada file: y toma como última
    partida inicio + duración, así que cada juego queda en una sola partida
    que acaba en la última vez que se jugó. Sin fecha conocida acaba en 1970
    y el tema pone "Never played".
    """
    known = [g for g in games if g.playtime is not None]
    if not known:
        return
    PEGASUS_STATS.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(PEGASUS_STATS, timeout=30)
    try:
        with db:
            # Mismo esquema que crea Pegasus
            db.execute("CREATE TABLE IF NOT EXISTS paths(id INTEGER PRIMARY "
                       "KEY,path TEXT UNIQUE NOT NULL)")
            db.execute("CREATE TABLE IF NOT EXISTS plays(id INTEGER PRIMARY "
                       "KEY,path_id INTEGER NOT NULL REFERENCES plays(id),"
                       "start_time INTEGER NOT NULL,"
                       "duration INTEGER NOT NULL)")
            for g in known:
                key = f"{g.source}:{g.id}"
                db.execute("DELETE FROM plays WHERE path_id IN "
                           "(SELECT id FROM paths WHERE path = ?)", (key,))
                if g.playtime <= 0:
                    continue
                db.execute("INSERT OR IGNORE INTO paths(path) VALUES(?)",
                           (key,))
                db.execute("INSERT INTO plays(path_id, start_time, duration) "
                           "SELECT id, ?, ? FROM paths WHERE path = ?",
                           (g.last_played - g.playtime, g.playtime, key))
    finally:
        db.close()
    log(f"tiempo jugado: {sum(g.playtime > 0 for g in known)} juegos "
        f"-> {PEGASUS_STATS}")


def main():
    games = []
    for name, plugin in (("steam", steam_games), ("heroic", heroic_games),
                         ("nativos", native_games)):
        try:
            found = plugin()
        except Exception as e:  # una tienda rota no tumba las demás
            log(f"{name}: error:", repr(e))
            continue
        log(f"{name}: {len(found)} juegos "
            f"({sum(g.installed for g in found)} instalados)")
        games += found

    groups = {}
    for g in games:
        label = (g.collection if g.installed
                 else f"{g.collection} · Sin instalar")
        groups.setdefault(label, []).append(g)

    dirs = []
    for label, group in groups.items():
        base = label.split(" · ")[0]
        order = (COLLECTION_ORDER.index(base)
                 if base in COLLECTION_ORDER else len(COLLECTION_ORDER))
        sort_key = f"{order:02d}{'b' if '·' in label else 'a'}"
        slug = re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")
        path = COLLECTIONS / slug
        write_collection(label, SHORTNAMES.get(base), sort_key, group, path)
        dirs.append(path)

    # Colecciones que ya no tienen juegos
    if COLLECTIONS.exists():
        for old in COLLECTIONS.iterdir():
            if old.is_dir() and old not in dirs:
                shutil.rmtree(old)

    update_game_dirs(sorted(dirs))
    try:
        update_stats(games)
    except sqlite3.Error as e:  # sin tiempos se abre Pegasus igual
        log("tiempo jugado: error:", repr(e))
    log(f"{len(games)} juegos en {len(dirs)} colecciones -> {COLLECTIONS}")


if __name__ == "__main__":
    main()
