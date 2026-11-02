# CHANGELOG — MovilLink

## v1.0.1 — 2026-11-02

Pulido del lanzamiento (mismo día):

- `MovilLink.vbs` — lanzador invisible: ni cmd, ni consola de PowerShell,
  ni icono de PowerShell en la barra — solo la app con su icono propio.
- Autor en el pie de la app (Luis Martin Peña Mejia — MKZ COMPANY).
- Todos los `.ps1` en UTF-8 con BOM — caracteres con tilde/ñ correctos
  en Windows PowerShell 5.1.
- Colores explícitos en campos de texto e historial (eran negros/tenues).
- Fix de orden de paneles anclados y textos cortados (Vigilar, Reaplicar).

## v1.0.0 — 2026-11-02

Primera versión pública.

**Motor de conexión (plan A → plan B → barrido)**
- Autoconexión mDNS con recuperación de daemon zombie
  (`kill-server` + `start-server` cuando el descubrimiento sale mudo).
- Ficha `telefono-ultimo.json`: historial de endpoints (máx 8),
  misma red primero, editable a mano.
- Sondeo de vecinos ARP y barrido paralelo de la subred /24.
- Recuperación de "puerto rotado": barrido del rango efímero
  32768-60999 acotado a IPs vivas + validación con `adb connect`.
- `Sync-Ficha`: con transporte `_tcp` pide la IP al móvil por shell y
  redescubre el puerto cruzando su `netstat`.

**Monitor**
- Cada 3s: reconecta si se cayó y re-aplica `adb reverse` si falta —
  el reverse no sobrevive a una reconexión y dejaba Chrome del móvil
  en blanco.

**App**
- Ventana WinForms azul, DPI-aware (nitida en pantallas 125%/150%).
- Conexión directa `IP:PUERTO`, historial con Probar/Quitar/Recargar,
  registro con hora.
- Capturadora de errores a `logs/error-*.log`.
- Chequeo de dependencias al arrancar con botón INSTALAR AHORA.

**Paquete**
- `0-Preparar-Antivirus.bat` (exclusión de Defender) y
  `1-Instalar-Necesarios.bat` (adb por winget o portable oficial).
- `tools/Generar-Recursos.ps1` regenera logo/icono/banner; la captura
  del README la genera la propia app (`-Captura`).
