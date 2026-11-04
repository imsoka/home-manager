# Bloquea la sesión con Win+Ctrl+L (GlazeWM). install.ps1 desactiva el bloqueo de
# Windows (DisableLockWorkstation) para que Win+L llegue a GlazeWM, así que
# LockWorkStation no funciona: tsdiscon desconecta la sesión y deja la pantalla de
# inicio de sesión (pide contraseña, las apps siguen abiertas).
$tsdiscon = Join-Path $env:WINDIR 'System32\tsdiscon.exe'
if (Test-Path $tsdiscon) {
    & $tsdiscon
    return
}

# Sin tsdiscon (Windows Home): reactivar el bloqueo un momento. Solo funciona si el
# usuario puede escribir esta clave (normalmente hace falta ser administrador).
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
Set-ItemProperty -Path $key -Name DisableLockWorkstation -Value 0 -Type DWord
rundll32.exe user32.dll,LockWorkStation
Start-Sleep -Seconds 2
Set-ItemProperty -Path $key -Name DisableLockWorkstation -Value 1 -Type DWord
