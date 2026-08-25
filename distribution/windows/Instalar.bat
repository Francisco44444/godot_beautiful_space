@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar.ps1"
if errorlevel 1 (
  echo.
  echo La instalacion no pudo completarse.
  pause
)

