' MovilLink - lanzador invisible (lo invoca el menu MovilLink.bat).
' wscript abre powershell SIN consola (0 = ventana oculta): ni cmd, ni
' icono de PowerShell en la barra - solo la app.
Set sh  = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ps = "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\Interfaz\MovilLink.UI.ps1"""
sh.Run ps, 0, False
