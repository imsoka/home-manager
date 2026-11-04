# Deshace lo que install.ps1 aplicó por error a la cuenta de administrador cuando
# "Ejecutar como administrador" usa una cuenta distinta de la de la sesión.
# Se ejecuta desde un PowerShell como administrador (es decir, como esa cuenta):
#   irm https://raw.githubusercontent.com/imsoka/home-manager/master/windows/revert-admin.ps1 -OutFile $env:TEMP\revert-admin.ps1
#   powershell -ExecutionPolicy Bypass -File $env:TEMP\revert-admin.ps1
# No toca lo que es de todo el equipo (WSL, winget, apps instaladas en Program Files).

$ErrorActionPreference = 'Continue'
$env:WSL_UTF8 = '1'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Note($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

# --- Seguridad: solo si esta cuenta NO es la de la sesión de escritorio ---
$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$owner = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" |
    Select-Object -First 1 | Invoke-CimMethod -MethodName GetOwner
$sessionUser = if ($owner) { "$($owner.Domain)\$($owner.User)" } else { $null }
Write-Host "Cuenta que ejecuta este script: $me"
Write-Host "Cuenta de la sesión de escritorio: $sessionUser"
if (-not $sessionUser) { throw 'No pude averiguar la cuenta de la sesión; no sigo.' }
if ($sessionUser -ieq $me) {
    Note 'Es la misma cuenta: aquí no hay nada que revertir (borraría tu propia config). No sigo.'
    return
}
$ok = Read-Host "Se borrará NixOS-WSL y la config de soka de la cuenta '$me'. Escribe SI para seguir"
if ($ok -cne 'SI') { Note 'Cancelado.'; return }

# --- 1. NixOS-WSL registrado en esta cuenta ---
Step 'NixOS-WSL'
$distros = (& wsl.exe --list --quiet 2>$null) -split "`r?`n" | ForEach-Object { $_.Trim() }
if ($distros -contains 'NixOS') {
    & wsl.exe --unregister NixOS
} else {
    Note 'No hay ninguna distro NixOS en esta cuenta.'
}
$nixDir = Join-Path $env:USERPROFILE 'NixOS'
if (Test-Path $nixDir) { Remove-Item $nixDir -Recurse -Force }

# --- 2. Apps instaladas solo para esta cuenta (las de Program Files se quedan) ---
Step 'Apps instaladas para esta cuenta'
$patterns = 'LearnHarness', 'Cursor', 'VSCodium', 'Grok', 'Anki', 'mpv', 'KeePassXC', 'Brave',
            'Nextcloud', 'DBeaver', 'Teams', 'Tailscale', 'WezTerm', 'GlazeWM', 'Zebar',
            'win32yank', 'Chatterino', 'calibre'
$entries = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $name = $_.DisplayName; $name -and ($patterns | Where-Object { $name -like "*$_*" }) }
if (-not $entries) { Note 'Ninguna.' }
foreach ($e in $entries) {
    $cmd = if ($e.QuietUninstallString) { $e.QuietUninstallString } else { $e.UninstallString }
    if (-not $cmd) { Note "$($e.DisplayName): sin desinstalador, la salto."; continue }
    if ((Read-Host "¿Desinstalar '$($e.DisplayName)' de esta cuenta? (s/n)") -eq 's') {
        Start-Process cmd.exe -ArgumentList '/c', $cmd -Wait
    }
}

# --- 3. Fuente SauceCodePro instalada para esta cuenta ---
Step 'SauceCodePro Nerd Font'
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
Get-ChildItem $fontDir -Filter 'SauceCodeProNerdFont-*.ttf' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-ItemProperty $fontReg -Name "$($_.BaseName) (TrueType)" -ErrorAction SilentlyContinue
    Remove-Item $_.FullName -Force
}

# --- 4. GlazeWM, Win+L, arranque automático ---
Step 'GlazeWM'
$glzr = Join-Path $env:USERPROFILE '.glzr\glazewm'
Remove-Item (Join-Path $glzr 'config.yaml'), (Join-Path $glzr 'lock.ps1') -Force -ErrorAction SilentlyContinue
if ((Test-Path $glzr) -and -not (Get-ChildItem $glzr)) {
    Remove-Item $glzr -Force
    $parent = Split-Path $glzr
    if (-not (Get-ChildItem $parent)) { Remove-Item $parent -Force }
}
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name DisableLockWorkstation -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'GlazeWM.lnk') -Force -ErrorAction SilentlyContinue

# --- 5. WezTerm y Windows Terminal ---
Step 'WezTerm / Windows Terminal'
$wez = Join-Path $env:USERPROFILE '.config\wezterm'
Remove-Item (Join-Path $wez 'wezterm.lua') -Force -ErrorAction SilentlyContinue
if ((Test-Path $wez) -and -not (Get-ChildItem $wez)) { Remove-Item $wez -Force }
Remove-Item (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\soka') -Recurse -Force -ErrorAction SilentlyContinue

# --- 6. PSGallery vuelve a "no confiable" (Set-PSRepository es por usuario) ---
Step 'PSGallery'
if (Get-Command Set-PSRepository -ErrorAction SilentlyContinue) {
    Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted -ErrorAction SilentlyContinue
}

# --- 7. Restos en TEMP ---
Step 'Temporales'
Remove-Item (Join-Path $env:TEMP 'soka-home-manager'), (Join-Path $env:TEMP 'SourceCodePro-nerd'),
            (Join-Path $env:TEMP 'winget-install'), (Join-Path $env:TEMP 'nixos.wsl'),
            (Join-Path $env:TEMP 'install.ps1') -Recurse -Force -ErrorAction SilentlyContinue

Step 'Hecho'
Note 'Lo que es de todo el equipo (WSL, winget, apps en Program Files) se queda: lo usará tu cuenta.'
