' MovilLink - lanzador invisible.
' wscript abre powershell SIN consola (0 = ventana oculta): ni cmd, ni
' icono de PowerShell en la barra, ni fantasma en Alt+Tab - solo la app.
Set sh  = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ps = "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\APP\Interfaz\MovilLink.UI.ps1"""
sh.Run ps, 0, False
