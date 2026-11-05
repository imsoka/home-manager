# Prepara el portátil Windows: WSL2 + NixOS-WSL, winget y apps, fuente, ssh-agent y
# WezTerm. Se puede relanzar las veces que haga falta: salta lo ya hecho.
#
# Se ejecuta en un PowerShell NORMAL, con tu usuario (no "como administrador"): las
# distros de WSL, la fuente, las configs y muchas apps son por usuario, y si la
# elevación usa otra cuenta acabarían en esa cuenta. Los pasos que necesitan
# administrador (activar WSL, instalar winget, ssh-agent, reactivar Win+L) piden permiso aparte.
# Descargar y ejecutar con -File (irm | iex en PowerShell 5.1 puede romper el BOM y
# los acentos):
#   irm https://raw.githubusercontent.com/imsoka/home-manager/master/windows/install.ps1 -OutFile $env:TEMP\install.ps1
#   powershell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest va mucho más rápido sin barra
$env:WSL_UTF8 = '1'                        # salida de wsl.exe en UTF-8 y no UTF-16

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Note($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

# --- Tiene que correr con la cuenta de la sesión de escritorio ---
$me = [Security.Principal.WindowsIdentity]::GetCurrent()
$owner = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" |
    Select-Object -First 1 | Invoke-CimMethod -MethodName GetOwner
$sessionUser = if ($owner) { "$($owner.Domain)\$($owner.User)" } else { $null }
if ($sessionUser -and $sessionUser -ine $me.Name) {
    throw "Este PowerShell es de '$($me.Name)', pero la sesión es de '$sessionUser'. Ábrelo normal, sin 'como administrador'."
}
$mySid = $me.User.Value

# Ejecuta un bloque como administrador en otra ventana (UAC) y espera. Lo que toque
# HKCU o el perfil ahí sería de la cuenta de administrador: solo cosas de equipo.
function Invoke-Elevated([string]$Title, [string]$Script) {
    $wrapped = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
Write-Host '$Title (como administrador)' -ForegroundColor Cyan
try {
$Script
} catch {
    Write-Host "Error: `$_" -ForegroundColor Red
    Read-Host 'Pulsa Enter para cerrar'
    exit 1
}
"@
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrapped))
    try {
        $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru `
            -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc
        return $p.ExitCode
    } catch {
        Note "No se concedió el permiso de administrador ($_)."
        return 1
    }
}

# --- Ficheros del repo: junto al script o, si se lanzó con irm | iex, descargados ---
$here = if ($PSScriptRoot) { $PSScriptRoot } else { '' }
if (-not $here -or -not (Test-Path (Join-Path $here 'configuration.winget'))) {
    Step 'Descargando el repo home-manager'
    $tmp = Join-Path $env:TEMP 'soka-home-manager'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'repo.zip'
    Invoke-WebRequest 'https://github.com/imsoka/home-manager/archive/refs/heads/master.zip' -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    $here = Join-Path $tmp 'home-manager-master\windows'
}

# --- 1. WSL2 ---
Step 'WSL2'
# PS 5.1 con 'Stop' convierte la salida de error de un .exe en excepción
try { & wsl.exe --version *> $null } catch { }
if ($LASTEXITCODE -ne 0) {
    $rc = Invoke-Elevated 'Activar WSL' @'
& wsl.exe --install --no-distribution
if ($LASTEXITCODE -ne 0) { throw "wsl --install devolvió $LASTEXITCODE" }
'@
    if ($rc -ne 0) { throw 'No se pudo activar WSL.' }
    Note 'WSL instalado. REINICIA Windows y vuelve a lanzar este script.'
    return   # no exit: con irm | iex cerraría la ventana
}
& wsl.exe --update

# --- 2. NixOS-WSL ---
Step 'NixOS-WSL'
$distros = (& wsl.exe --list --quiet) -split "`r?`n" | ForEach-Object { $_.Trim() }
if ($distros -contains 'NixOS') {
    Note 'NixOS ya está instalado.'
} else {
    $image = Join-Path $env:TEMP 'nixos.wsl'
    Invoke-WebRequest 'https://github.com/nix-community/NixOS-WSL/releases/latest/download/nixos.wsl' -OutFile $image
    & wsl.exe --install --from-file $image --no-launch
    if ($LASTEXITCODE -ne 0) {
        # WSL antiguo sin --from-file
        $dir = Join-Path $env:USERPROFILE 'NixOS'
        & wsl.exe --import NixOS $dir $image
    }
    Remove-Item $image
    $distros = (& wsl.exe --list --quiet) -split "`r?`n" | ForEach-Object { $_.Trim() }
    if ($distros -notcontains 'NixOS') {
        throw "NixOS no aparece en 'wsl --list' tras instalarlo. Distros actuales: $($distros -join ', ')"
    }
    & wsl.exe --set-default NixOS
    Note 'NixOS instalado para este usuario.'
}

# --- 3. winget (>= 1.6, necesario para winget configure) ---
function Get-WingetVersion {
    # El alias de winget vive aquí; en una sesión recién instalada puede faltar en el PATH
    $apps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (($env:Path -split ';') -notcontains $apps) { $env:Path += ";$apps" }
    try { $v = (& winget.exe --version 2>$null) } catch { return $null }
    if ($LASTEXITCODE -ne 0 -or -not $v) { return $null }
    return [version](($v | Select-Object -First 1).Trim().TrimStart('v') -replace '-.*$', '')
}

Step 'winget'
$wingetMin = [version]'1.6.0'
$wingetVer = Get-WingetVersion
if ($wingetVer -and $wingetVer -ge $wingetMin) {
    Note "winget $wingetVer ya está disponible."
} else {
    if ($wingetVer) { Note "winget $wingetVer es demasiado antiguo: actualizando." } else { Note 'winget no está: instalando.' }

    # Vía oficial, como administrador: módulo Microsoft.WinGet.Client, que instala o
    # repara winget para todos los usuarios (-AllUsers), también para este
    $rc = Invoke-Elevated 'Instalar winget' @'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
Install-Module Microsoft.WinGet.Client -Repository PSGallery -Scope AllUsers -Force
Import-Module Microsoft.WinGet.Client -Force
Repair-WinGetPackageManager -AllUsers -Latest -Force
'@
    if ($rc -ne 0) { Note 'El módulo Microsoft.WinGet.Client falló; instalo el paquete de GitHub.' }

    # Respaldo, con este usuario (Add-AppxPackage registra para quien lo ejecuta):
    # msixbundle de la última release de winget-cli con sus dependencias
    $wingetVer = Get-WingetVersion
    if (-not $wingetVer -or $wingetVer -lt $wingetMin) {
        $tmp = Join-Path $env:TEMP 'winget-install'
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory $tmp | Out-Null
        $base = 'https://github.com/microsoft/winget-cli/releases/latest/download'
        $deps = Join-Path $tmp 'deps.zip'
        $bundle = Join-Path $tmp 'winget.msixbundle'
        Invoke-WebRequest "$base/DesktopAppInstaller_Dependencies.zip" -OutFile $deps
        Invoke-WebRequest "$base/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $bundle
        Expand-Archive $deps -DestinationPath (Join-Path $tmp 'deps')
        Get-ChildItem (Join-Path $tmp 'deps') -Recurse -Filter *.appx |
            Where-Object { $_.FullName -match '\\x64\\' } |
            ForEach-Object { Add-AppxPackage -Path $_.FullName -ErrorAction SilentlyContinue }
        Add-AppxPackage -Path $bundle
        Remove-Item $tmp -Recurse -Force
        Start-Sleep -Seconds 5   # el alias tarda un momento en registrarse
        $wingetVer = Get-WingetVersion
    }

    if (-not $wingetVer -or $wingetVer -lt $wingetMin) {
        throw 'No he podido instalar winget. Instala o actualiza "Instalador de aplicación" desde la Microsoft Store y relanza el script.'
    }
    Note "winget $wingetVer instalado."
}

# --- 4. Apps ---
Step 'Apps (winget configure)'
# winget configure viene desactivado ("extended features are not enabled"): se activa
# una vez. Primero con este usuario y, si pide administrador, elevado.
try { & winget.exe configure --enable *> $null } catch { }
if ($LASTEXITCODE -ne 0) {
    $rc = Invoke-Elevated 'Activar winget configure' @'
& winget.exe configure --enable
if ($LASTEXITCODE -ne 0) { throw "winget configure --enable devolvió $LASTEXITCODE" }
'@
    if ($rc -ne 0) { Note 'No se pudo activar winget configure; el paso de apps fallará.' }
}
& winget configure -f (Join-Path $here 'configuration.winget') --accept-configuration-agreements
if ($LASTEXITCODE -ne 0) { Note 'winget configure terminó con errores: revisa la salida y relanza.' }

Step 'LearnHarness (no está en winget: instalador de la última release)'
$lhKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$lhInstalled = Get-ItemProperty $lhKey -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'LearnHarness*' }
if ($lhInstalled) {
    Note 'LearnHarness ya está instalado (se actualiza sola).'
} else {
    # Sin la API de GitHub (límite de peticiones por IP, que en la red de la empresa se
    # agota): el latest.yml de electron-builder da el nombre del instalador y su sha512
    $base = 'https://github.com/amosblomqvist/learnharness/releases/latest/download'
    $yml = (Invoke-WebRequest "$base/latest.yml" -UseBasicParsing).Content
    if ($yml -is [byte[]]) { $yml = [Text.Encoding]::UTF8.GetString($yml) }
    $name = ([regex]::Match($yml, '(?m)^path:\s*(\S+)')).Groups[1].Value
    $sha = ([regex]::Match($yml, '(?m)^sha512:\s*(\S+)')).Groups[1].Value
    if (-not $name) { throw 'No encuentro el instalador de LearnHarness en latest.yml.' }
    $exe = Join-Path $env:TEMP $name
    Invoke-WebRequest "$base/$name" -OutFile $exe
    $hash = [Convert]::ToBase64String((New-Object Security.Cryptography.SHA512Managed).ComputeHash([IO.File]::ReadAllBytes($exe)))
    if ($sha -and $hash -ne $sha) { Remove-Item $exe; throw 'El sha512 del instalador de LearnHarness no coincide.' }
    Start-Process $exe -Wait
    Remove-Item $exe
}

# --- 5. Fuente: SauceCodePro Nerd Font (no está en winget), instalada para el usuario ---
Step 'SauceCodePro Nerd Font'
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
if (Test-Path (Join-Path $fontDir 'SauceCodeProNerdFont-Regular.ttf')) {
    Note 'Ya instalada.'
} else {
    $tmp = Join-Path $env:TEMP 'SourceCodePro-nerd'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'SourceCodePro.zip'
    Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SourceCodePro.zip' -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    New-Item -ItemType Directory $fontDir -Force | Out-Null
    if (-not (Test-Path $fontReg)) { New-Item $fontReg -Force | Out-Null }
    # Solo la variante normal (sin Mono ni Propo), como la de kitty
    Get-ChildItem $tmp -Filter 'SauceCodeProNerdFont-*.ttf' | ForEach-Object {
        $dest = Join-Path $fontDir $_.Name
        Copy-Item $_.FullName $dest -Force
        Set-ItemProperty $fontReg -Name "$($_.BaseName) (TrueType)" -Value $dest
    }
    Remove-Item $tmp -Recurse -Force
}

# --- 6. Limpieza de GlazeWM (ya no se usa; winget lo desinstala con Ensure: Absent) ---
Step 'Limpieza de GlazeWM'
Remove-Item (Join-Path $env:USERPROFILE '.glzr') -Recurse -Force -ErrorAction SilentlyContinue
$startup = [Environment]::GetFolderPath('Startup')
if ($startup) { Remove-Item (Join-Path $startup 'GlazeWM.lnk') -Force -ErrorAction SilentlyContinue }

# Versiones anteriores desactivaron Win+L para dárselo a GlazeWM: se vuelve a activar.
# La clave Policies solo la toca un administrador, sobre el registro de ESTE usuario.
$pol = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
if ($null -eq (Get-ItemProperty $pol -ErrorAction SilentlyContinue).DisableLockWorkstation) {
    Note 'Win+L ya bloquea la sesión.'
} else {
    $rc = Invoke-Elevated 'Reactivar Win+L' @"
Remove-ItemProperty 'Registry::HKEY_USERS\$mySid\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name DisableLockWorkstation
"@
    if ($null -ne (Get-ItemProperty $pol -ErrorAction SilentlyContinue).DisableLockWorkstation) {
        Note 'No se pudo reactivar Win+L: borra DisableLockWorkstation de esa clave a mano.'
    }
}

# --- 7. WezTerm ---
Step 'WezTerm'
$wezDir = Join-Path $env:USERPROFILE '.config\wezterm'
New-Item -ItemType Directory $wezDir -Force | Out-Null
Copy-Item (Join-Path $here 'wezterm\wezterm.lua') (Join-Path $wezDir 'wezterm.lua') -Force

# --- 8. ssh-agent de Windows: KeePassXC le carga las claves y NixOS-WSL lo usa vía
# wsl2-ssh-agent (wsl.ssh-agent en sokix-wsl). Viene deshabilitado; activarlo es de equipo.
Step 'ssh-agent de Windows'
$agent = Get-Service ssh-agent -ErrorAction SilentlyContinue
if ($agent -and $agent.StartType -eq 'Automatic' -and $agent.Status -eq 'Running') {
    Note 'Ya está activo.'
} else {
    $rc = Invoke-Elevated 'Activar ssh-agent' @'
if (-not (Get-Service ssh-agent -ErrorAction SilentlyContinue)) {
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
}
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
'@
    if ($rc -ne 0) { Note 'No se pudo activar ssh-agent (¿lo bloquea la política de la empresa?).' }
}

# --- 9. Claude Code: mismo inicio de sesión que en NixOS-WSL (programs/claude/claude.nix).
# El token (claude setup-token) vive solo en el fichero de WSL; aquí se copia a una
# variable de usuario. Relanzar tras renovarlo.
Step 'Token de Claude Code'
$tokenFile = '\\wsl.localhost\NixOS\home\soka\.config\claude-code\oauth-token'
if (Test-Path $tokenFile) {
    $token = (Get-Content $tokenFile -Raw) -replace '\s', ''   # setup-token lo parte en líneas
    if ([Environment]::GetEnvironmentVariable('CLAUDE_CODE_OAUTH_TOKEN', 'User') -ne $token) {
        [Environment]::SetEnvironmentVariable('CLAUDE_CODE_OAUTH_TOKEN', $token, 'User')
        Note 'Actualizado (abre una terminal nueva para usarlo).'
    } else { Note 'Ya está al día.' }
} else {
    Note "No existe $tokenFile : genera uno en WSL con 'claude setup-token' (ver programs/claude/claude.nix)."
}

# --- 10. Lo que queda a mano ---
Step 'Pendiente a mano'
Note 'FortiClient VPN (VPN rema): https://www.fortinet.com/support/product-downloads'
Note 'LibreSprite: https://libresprite.github.io'
Note 'KeePassXC: Ajustes > Agente SSH > activar (OpenSSH); en cada entrada con clave, "Añadir clave al agente al abrir la base de datos".'
Note 'Primer arranque de NixOS-WSL (usuario soka, repos, home-manager): ver CLAUDE.md del repo nixos.'
Note 'Cierra sesión y vuelve a entrar para que se aplique la fuente.'
