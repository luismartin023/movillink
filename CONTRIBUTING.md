# Contribuir a MovilLink

Gracias por querer aportar. Las reglas son pocas:

## Estructura sagrada

- La lógica vive solo en `APP/Core/` (orquestador) y `APP/Core/Dominio/`
  (adb, red, ficha — funciones puras, sin UI).
- `APP/Interfaz/` y `APP/Consola/` son adaptadores: consumen el Core,
  no duplican lógica. Si agregas una interfaz nueva, va ahí y llama al Core.
- Nada de adb.exe fuera de `Dominio/adb.ps1`.

## Estilo

- PowerShell 5.1 compatible (Windows PowerShell, no pwsh-only).
- Comentarios y mensajes en español, sin emojis en el código.
- La ficha `telefono-ultimo.json` es del usuario: leer/escribir solo con
  las funciones de `Dominio/ficha.ps1`.

## Verificación antes del PR

```powershell
# Sintaxis de todo el paquete
Get-ChildItem -Recurse -Filter *.ps1 | % {
  $t=$null;$e=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e)
  if($e){"$($_.Name): ERROR"}else{"$($_.Name): OK"}
}
# Motor real
.\APP\Consola\MovilLink.CLI.bat
# Ventana (genera captura y cierra sola)
powershell -STA -File APP\Interfaz\MovilLink.UI.ps1 -Captura
```

Abre un issue primero si el cambio es grande.
