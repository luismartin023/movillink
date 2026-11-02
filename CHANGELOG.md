# CHANGELOG — MovilLink

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
