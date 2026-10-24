# Home Manager (flake)

Configuración según `hostname`: `sokix` → `.#soka`, `sokix-work` → `.#soka-work`. `home.nix` es común; los módulos exclusivos de cada máquina se añaden en `flake.nix` (personal: steam, discord, pegasus, soh, noctalia/gaming; work: noctalia/noctalia.nix y el parche de huella vía `fingerprintPatch`).

## Dónde vive cada cosa
- niri: reglas de ventanas, workspaces, atajos → `window-managers/niri/config.kdl`; `niri.nix` solo lo enlaza.
- Steam (gamescope, workspaces "steam"/"game", opciones de lanzamiento, Proton-GE) → `programs/steam/` (scripts `.sh`/`.py` + `steam.nix`).
- Pegasus (biblioteca para mando/Moonlight, tema reprise y sus parches, instalar/desinstalar) → `programs/pegasus/`; la biblioteca se genera con `pegasus-library.py`.
- Noctalia (barra/shell): plugins en `programs/noctalia/` (`gaming.nix`, `claude-sessions.nix`, `wallpaper.nix`, `vpn-rema/`).
- GTK y tema → `programs/gtk/gtk.nix` (genera `gtk.css` con el import de Noctalia).

## Aplicar
1. Ficheros nuevos: `git add` antes del switch, o el flake no los ve.
2. `home-manager switch --flake ~/.config/home-manager#<config>` (no requiere sudo; ejecútalo tú y comprueba el resultado).

## Hook de pre-commit
`.githooks/pre-commit` valida sintaxis y evaluación de todas las configs del flake; tras clonar actívalo con `git config core.hooksPath .githooks`.

## Commits (permiso permanente)
Commitea cada cambio ya aplicado y comprobado: un commit por tema, mensaje `tema: descripción` en español (temas habituales: `niri`, `steam`, `pegasus`, `gtk`, `noctalia`). Añade solo los ficheros que has tocado tú en esta sesión; lo que ya estaba modificado al empezar viene de otra sesión o del usuario y se queda fuera.

## Imágenes
Antes de leer capturas grandes con Read, redúcelas (p. ej. `ffmpeg -i in.png -vf scale=1280:-1 out.png`).
