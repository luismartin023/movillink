@echo off
title MovilLink - Instalar herramientas necesarias
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0APP\Instalar-Necesarios.ps1"
echo.
pause
