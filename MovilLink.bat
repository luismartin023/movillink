@echo off
rem ============================================================
rem  MovilLink - asistente paso a paso (unico lanzador del paquete)
rem  Primera vez: 1 (antivirus) -> 2 (instalar adb) -> 3 (abrir app)
rem ============================================================
title MovilLink - Asistente
chcp 65001 >nul
cd /d "%~dp0"

:menu
cls
echo.
echo   ============================================
echo     MOVILLINK - Puente ADB WiFi  v1.1.0
echo   ============================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "APP\Estado.ps1"
echo.
echo   PRIMERA VEZ: haz los pasos 1, 2 y 3 en orden.
echo.
echo    [1] Paso 0 - Excluir carpeta del antivirus (1 vez)
echo    [2] Paso 1 - Instalar herramientas necesarias (adb)
echo    [3] Paso 2 - Abrir MovilLink (ventana)
echo   --------------------------------------------
echo    [4] Conectar por consola (sin ventana)
echo    [5] Diagnostico (adb / mDNS / reverse / ficha)
echo    [6] Ver registros de error (logs)
echo    [0] Salir
echo.
set /p "op=   Elige una opcion y pulsa Enter: "

if "%op%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "APP\Preparar-Antivirus.ps1"
  echo.
  pause
  goto menu
)
if "%op%"=="2" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "APP\Instalar-Necesarios.ps1"
  echo.
  pause
  goto menu
)
if "%op%"=="3" (
  wscript "APP\Lanzador.vbs"
  goto menu
)
if "%op%"=="4" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "APP\Consola\MovilLink.CLI.ps1"
  echo.
  pause
  goto menu
)
if "%op%"=="5" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "APP\Diagnostico.ps1"
  echo.
  pause
  goto menu
)
if "%op%"=="6" (
  if not exist logs mkdir logs
  explorer logs
  goto menu
)
if "%op%"=="0" exit /b
goto menu
