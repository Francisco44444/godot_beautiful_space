$ErrorActionPreference = "Stop"

$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$installRoot = Join-Path $env:LOCALAPPDATA "SenderosDelHorizonte"
$desktop = [Environment]::GetFolderPath("Desktop")

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Copy-Item (Join-Path $source "ActualizarYJugar.ps1") $installRoot -Force
Copy-Item (Join-Path $source "Jugar.bat") $installRoot -Force
Copy-Item (Join-Path $source "channel.json") $installRoot -Force

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path $desktop "Senderos del Horizonte.lnk"))
$shortcut.TargetPath = Join-Path $installRoot "Jugar.bat"
$shortcut.WorkingDirectory = $installRoot
$shortcut.Description = "Actualizar y jugar a Senderos del Horizonte"
$shortcut.Save()

Write-Host "Instalado en $installRoot"
Write-Host "Se ha creado el acceso directo Senderos del Horizonte."
& (Join-Path $installRoot "Jugar.bat")

