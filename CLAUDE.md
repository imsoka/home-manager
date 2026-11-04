# Home Manager (flake)

Configuración según `hostname`: `sokix` → `.#soka`, `sokix-work` → `.#soka-work`, `sokix-wsl` → `.#soka-wsl`. `home-cli.nix` es la base de terminal (neovim, codex, usuario, stateVersion) y la única que usa `soka-wsl`; `home.nix` la importa y añade el escritorio (niri, Noctalia, GTK, kitty…) común a `soka` y `soka-work`. Lo exclusivo de cada máquina se añade en `flake.nix` (personal: steam, discord, pegasus, soh, noctalia/gaming; work: noctalia/noctalia.nix y el parche de huella vía `fingerprintPatch`). Algo nuevo de terminal va en `home-cli.nix`; algo gráfico, en `home.nix`.

## Dónde vive cada cosa
- niri: reglas de ventanas, workspaces, atajos → `window-managers/niri/config.kdl`; `niri.nix` solo lo enlaza.
- Steam (gamescope, workspaces "steam"/"game", opciones de lanzamiento, Proton-GE) → `programs/steam/` (scripts `.sh`/`.py` + `steam.nix`).
- Pegasus (biblioteca para mando/Moonlight, tema reprise y sus parches, instalar/desinstalar) → `programs/pegasus/`; la biblioteca se genera con `pegasus-library.py`.
- Noctalia (barra/shell): plugins en `programs/noctalia/` (`gaming.nix`, `claude-sessions.nix`, `wallpaper.nix`, `vpn-rema/`).
- GTK y tema → `programs/gtk/gtk.nix` (genera `gtk.css` con el import de Noctalia).
- Windows (portátil con sokix-wsl; no lo evalúa Nix) → `windows/`: `configuration.winget` (apps), `glazewm/` (config con Win como Mod calcando niri + `lock.ps1` para Win+Ctrl+L), `wezterm/wezterm.lua` (terminal: abre NixOS-WSL, con el protocolo gráfico de kitty para snacks.image) e `install.ps1`, que lo instala/copia todo y es relanzable. Tras editar algo de aquí, relanza `install.ps1` en Windows (o copia el fichero). Los `.ps1` llevan BOM UTF-8 para que PowerShell 5.1 lea bien los acentos.

## Aplicar
1. Ficheros nuevos: `git add` antes del switch, o el flake no los ve.
2. `home-manager switch --flake ~/.config/home-manager#<config>` (no requiere sudo; ejecútalo tú y comprueba el resultado).

## Hook de pre-commit
`.githooks/pre-commit` valida sintaxis y evaluación de todas las configs del flake; tras clonar actívalo con `git config core.hooksPath .githooks`.

## Commits (permiso permanente)
Commitea cada cambio ya aplicado y comprobado: un commit por tema, mensaje `tema: descripción` en español (temas habituales: `niri`, `steam`, `pegasus`, `gtk`, `noctalia`). Añade solo los ficheros que has tocado tú en esta sesión; lo que ya estaba modificado al empezar viene de otra sesión o del usuario y se queda fuera.

## Imágenes
Antes de leer capturas grandes con Read, redúcelas (p. ej. `ffmpeg -i in.png -vf scale=1280:-1 out.png`).
