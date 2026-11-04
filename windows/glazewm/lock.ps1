# Bloquea la sesión con Win+Ctrl+L (GlazeWM). install.ps1 desactiva el bloqueo
# de Windows para que Win+L llegue a GlazeWM; aquí se reactiva solo un momento.
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
Set-ItemProperty -Path $key -Name DisableLockWorkstation -Value 0 -Type DWord
rundll32.exe user32.dll,LockWorkStation
Start-Sleep -Seconds 2
Set-ItemProperty -Path $key -Name DisableLockWorkstation -Value 1 -Type DWord
