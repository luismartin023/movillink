@echo off
title MovilLink - Consola
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MovilLink.CLI.ps1" %*
echo.
pause
