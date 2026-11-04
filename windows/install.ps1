# Prepara el portátil Windows: WSL2 + NixOS-WSL, winget y apps, fuente, GlazeWM y
# WezTerm. Se puede relanzar las veces que haga falta: salta lo ya hecho.
#
# PowerShell como administrador (descargar y ejecutar con -File; irm | iex en
# PowerShell 5.1 puede romper el BOM y los acentos):
#   irm https://raw.githubusercontent.com/imsoka/home-manager/master/windows/install.ps1 -OutFile $env:TEMP\install.ps1
#   powershell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest va mucho más rápido sin barra
$env:WSL_UTF8 = '1'                        # salida de wsl.exe en UTF-8 y no UTF-16

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Note($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Ejecuta este script en un PowerShell como administrador.' }

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
    & wsl.exe --install --no-distribution
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
    & wsl.exe --set-default NixOS
    Remove-Item $image
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

    # Vía oficial: módulo Microsoft.WinGet.Client (instala o repara winget)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module Microsoft.WinGet.Client -Repository PSGallery -Scope AllUsers -Force
        Import-Module Microsoft.WinGet.Client -Force
        Repair-WinGetPackageManager -AllUsers -Latest -Force
    } catch {
        Note "El módulo Microsoft.WinGet.Client falló ($_); instalo el paquete de GitHub."
    }

    # Respaldo: msixbundle de la última release de winget-cli con sus dependencias
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
& winget configure -f (Join-Path $here 'configuration.winget') --accept-configuration-agreements
if ($LASTEXITCODE -ne 0) { Note 'winget configure terminó con errores: revisa la salida y relanza.' }

Step 'LearnHarness (no está en winget: instalador de la última release)'
$lhKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$lhInstalled = Get-ItemProperty $lhKey -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'LearnHarness*' }
if ($lhInstalled) {
    Note 'LearnHarness ya está instalado (se actualiza sola).'
} else {
    $rel = Invoke-RestMethod 'https://api.github.com/repos/amosblomqvist/learnharness/releases/latest'
    $asset = $rel.assets | Where-Object { $_.name -like '*-x64-setup.exe' } | Select-Object -First 1
    $exe = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $exe
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

# --- 6. GlazeWM ---
Step 'GlazeWM'
$glzr = Join-Path $env:USERPROFILE '.glzr\glazewm'
New-Item -ItemType Directory $glzr -Force | Out-Null
Copy-Item (Join-Path $here 'glazewm\config.yaml') (Join-Path $glzr 'config.yaml') -Force
Copy-Item (Join-Path $here 'glazewm\lock.ps1') (Join-Path $glzr 'lock.ps1') -Force

# Win+L pasa a GlazeWM: se desactiva el bloqueo de Windows (Win+Ctrl+L bloquea con lock.ps1)
$pol = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
if (-not (Test-Path $pol)) { New-Item $pol -Force | Out-Null }
Set-ItemProperty $pol -Name DisableLockWorkstation -Value 1 -Type DWord
if ((Get-ItemProperty $pol).DisableLockWorkstation -ne 1) {
    Note 'No se pudo desactivar Win+L (¿política de empresa?): seguirá bloqueando la sesión.'
}

# Arranque con la sesión
$glazeExe = (Get-Command glazewm.exe -ErrorAction SilentlyContinue).Source
if (-not $glazeExe) {
    $glazeExe = Get-ChildItem "$env:ProgramFiles\glzr.io", "$env:LOCALAPPDATA\Programs" -Filter glazewm.exe -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if ($glazeExe) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'GlazeWM.lnk'
    $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $sc.TargetPath = $glazeExe
    $sc.Save()
} else {
    Note 'No encuentro glazewm.exe: añádelo a mano al arranque (shell:startup).'
}

# --- 7. WezTerm ---
Step 'WezTerm'
$wezDir = Join-Path $env:USERPROFILE '.config\wezterm'
New-Item -ItemType Directory $wezDir -Force | Out-Null
Copy-Item (Join-Path $here 'wezterm\wezterm.lua') (Join-Path $wezDir 'wezterm.lua') -Force

# --- 8. Lo que queda a mano ---
Step 'Pendiente a mano'
Note 'FortiClient VPN (VPN rema): https://www.fortinet.com/support/product-downloads'
Note 'LibreSprite: https://libresprite.github.io'
Note 'Primer arranque de NixOS-WSL (usuario soka, repos, home-manager): ver CLAUDE.md del repo nixos.'
Note 'Cierra sesión y vuelve a entrar para que arranque GlazeWM y se aplique la fuente.'
