@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ActualizarYJugar.ps1"
if errorlevel 1 (
  echo.
  echo No se pudo iniciar Senderos del Horizonte.
  pause
)

