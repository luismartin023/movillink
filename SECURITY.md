# Security Policy — MovilLink

## Alcance

MovilLink es una herramienta **local**: ejecuta `adb` en tu PC, habla con
tu teléfono por tu WiFi y no envía datos a ningún servidor. No maneja
credenciales ni secrets — la ficha `telefono-ultimo.json` solo guarda IPs
y puertos de tu red local.

## Qué hace cada componente sensible

- `0-Preparar-Antivirus.bat` — agrega SOLO la carpeta del paquete a las
  exclusiones de Windows Defender (`Add-MpPreference -ExclusionPath`).
  Pide administrador y no toca nada más.
- `1-Instalar-Necesarios.bat` — instala Android Platform-Tools por winget
  (`Google.PlatformTools`) o descarga el ZIP oficial de
  `dl.google.com`. No instala nada más.
- La app abre un forward `adb reverse tcp:PUERTO tcp:PUERTO` hacia tu
  dev server local — solo dentro del par PC↔móvil ya vinculados por TLS.

## Reportar una vulnerabilidad

Abre un issue en el repositorio o escribe al autor por GitHub:
[@luismartin023](https://github.com/luismartin023).

## Descarga segura

Descarga siempre desde el repositorio oficial o sus Releases. Si Windows
muestra una alerta SmartScreen, verifica la fuente antes de ejecutar.
