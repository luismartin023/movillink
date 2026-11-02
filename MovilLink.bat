@echo off
rem MovilLink - abre la app visual sin ventana de consola.
start "" powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0APP\Interfaz\MovilLink.UI.ps1"
