# MovilLink.UI — adaptador WinForms. Solo presenta: toda la logica vive en
# APP\Core\MovilLink.Core.ps1 (dominio puro). Doble clic: MovilLink.bat.
param(
  [int]$Puerto = 3000,
  [switch]$Captura,
  [string]$CapturaRuta = ''
)

# --- nitidez: la app era borrosa porque powershell.exe no es DPI-aware y
# Windows reescala la ventana como bitmap (pantallas 125%/150%). Declarar
# PER_MONITOR_AWARE_V2 ANTES de crear cualquier ventana -> render real.
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DpiInit {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  [DllImport("shcore.dll")]  public static extern int  SetProcessDpiAwareness(int value);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
try { [void][DpiInit]::SetProcessDpiAwarenessContext((New-Object IntPtr(-4))) }
catch { try { [void][DpiInit]::SetProcessDpiAwareness(2) } catch { [void][DpiInit]::SetProcessDPIAware() } }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Instancia unica: dos ventanas se pisarian el reverse y el monitor.
$creada = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\MovilLink.UI', [ref]$creada)
if (-not $creada) {
  [void][System.Windows.Forms.MessageBox]::Show('MovilLink ya esta abierto.`nRevisa la barra de tareas.', 'MovilLink', 'OK', 'Information')
  exit 0
}

# --- cargar el Core (dominio) ---
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot '..\Core\MovilLink.Core.ps1')
$cfg = Initialize-MovilLink $raiz

# Capturadora global: cualquier error fuera de un handler tambien queda
# registrado en logs\ y no tumba la app en silencio.
trap {
  $f = Write-ErrorLog $_
  try { [void][System.Windows.Forms.MessageBox]::Show("MovilLink encontro un error.`n$($_.Exception.Message)`n`nDetalle: $f", 'MovilLink', 'OK', 'Error') } catch {}
  continue
}

function Write-UiLog([string]$m) {
  $tb = $script:ui.txtLog
  if (-not $tb -or $tb.IsDisposed) { return }
  $linea = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  if ($tb.InvokeRequired) { $tb.Invoke([Action]{ $tb.AppendText($linea + [Environment]::NewLine) }) }
  else { $tb.AppendText($linea + [Environment]::NewLine) }
}
$script:OnLog = { param($m) Write-UiLog $m }

function Write-UiError($Err) {
  $f = Write-ErrorLog $Err
  Write-UiLog "ERROR: $($Err.Exception.Message)"
  if ($f) { Write-UiLog "  detalle -> $f" }
}

# --------------------------- paleta azul --------------------------------
$C = @{
  navyTop   = [System.Drawing.Color]::FromArgb(14, 38, 78)
  navyBot   = [System.Drawing.Color]::FromArgb(30, 80, 160)
  banda     = [System.Drawing.Color]::FromArgb(226, 235, 249)
  fondo     = [System.Drawing.Color]::FromArgb(237, 242, 250)
  texto     = [System.Drawing.Color]::FromArgb(23, 42, 74)
  subtexto  = [System.Drawing.Color]::FromArgb(96, 116, 148)
  verde     = [System.Drawing.Color]::FromArgb(22, 163, 74)
  verdeOver = [System.Drawing.Color]::FromArgb(19, 140, 63)
  azul      = [System.Drawing.Color]::FromArgb(37, 99, 235)
  azulOver  = [System.Drawing.Color]::FromArgb(29, 78, 216)
  rojo      = [System.Drawing.Color]::FromArgb(220, 60, 60)
  ambar     = [System.Drawing.Color]::FromArgb(230, 160, 20)
  logFondo  = [System.Drawing.Color]::FromArgb(11, 27, 52)
  logTexto  = [System.Drawing.Color]::FromArgb(190, 212, 240)
}

function New-Btn([string]$txt, $bg, $over, $rect) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $txt
  $b.BackColor = $bg
  $b.ForeColor = [System.Drawing.Color]::White
  $b.FlatStyle = 'Flat'
  $b.FlatAppearance.BorderSize = 0
  $b.FlatAppearance.MouseOverBackColor = $over
  $b.SetBounds($rect[0], $rect[1], $rect[2], $rect[3])
  return $b
}

# ==================== VISTA: faltan dependencias =========================
function Show-Dependencias {
  $f = New-Object System.Windows.Forms.Form
  $f.Text = 'MovilLink - Herramientas necesarias'
  $f.ClientSize = New-Object System.Drawing.Size(470, 330)
  $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false
  $f.StartPosition = 'CenterScreen'; $f.BackColor = $C.fondo
  $f.Font = New-Object System.Drawing.Font('Segoe UI', 9)

  $head = New-Object System.Windows.Forms.Panel
  $head.Dock = 'Top'; $head.Height = 96
  $head.Add_Paint({
    param($s, $e)
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($s.ClientRectangle, $C.navyTop, $C.navyBot, 0.0)
    $e.Graphics.FillRectangle($br, $s.ClientRectangle); $br.Dispose()
  })
  $f.Controls.Add($head)

  $logoPath = Join-Path $raiz 'APP\Recursos\logo.png'
  if (Test-Path $logoPath) {
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Image = [System.Drawing.Image]::FromFile($logoPath)
    $pb.SizeMode = 'Zoom'; $pb.SetBounds(18, 16, 64, 64); $pb.BackColor = [System.Drawing.Color]::Transparent
    $head.Controls.Add($pb)
  }
  $t = New-Object System.Windows.Forms.Label
  $t.Text = 'MovilLink'; $t.ForeColor = [System.Drawing.Color]::White
  $t.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
  $t.AutoSize = $true; $t.Location = '96,20'; $t.BackColor = [System.Drawing.Color]::Transparent
  $head.Controls.Add($t)
  $s = New-Object System.Windows.Forms.Label
  $s.Text = 'Faltan herramientas para funcionar'; $s.ForeColor = [System.Drawing.Color]::FromArgb(170, 200, 240)
  $s.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $s.AutoSize = $true; $s.Location = '98,54'; $s.BackColor = [System.Drawing.Color]::Transparent
  $head.Controls.Add($s)

  $msg = New-Object System.Windows.Forms.Label
  $msg.Text = "No se encontro 'adb' (Android Platform-Tools).`n`nPara que MovilLink funcione debes instalar las herramientas.`nPulsa INSTALAR AHORA y el instalador las descarga y configura por ti."
  $msg.ForeColor = $C.texto; $msg.AutoSize = $false
  $msg.SetBounds(24, 112, 420, 110)
  $f.Controls.Add($msg)

  $btnInst = New-Btn 'INSTALAR AHORA' $C.azul $C.azulOver @(24, 226, 200, 40)
  $f.Controls.Add($btnInst)
  $btnRe = New-Btn 'REINTENTAR' $C.navyBot $C.navyTop @(236, 226, 110, 40)
  $f.Controls.Add($btnRe)
  $btnOut = New-Btn 'SALIR' $C.subtexto $C.texto @(358, 226, 88, 40)
  $f.Controls.Add($btnOut)

  $btnInst.Add_Click({
    try { Start-Process powershell.exe '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$raiz\APP\Instalar-Necesarios.ps1`"" }
    catch { Write-UiError $_ }
  })
  $btnRe.Add_Click({ $script:reintentar = $true; $f.Close() })
  $btnOut.Add_Click({ $f.Close() })
  [void]$f.ShowDialog()
}

# Bucle de dependencias: reintentar hasta que adb aparezca o el usuario salga.
while (-not $cfg.adbOk) {
  $script:reintentar = $false
  Show-Dependencias
  if (-not $script:reintentar) { exit 1 }
  $cfg = Initialize-MovilLink $raiz
  if ($cfg.adbOk) { break }
}

# ============================ VISTA PRINCIPAL ============================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'MovilLink - Puente ADB WiFi'
$form.ClientSize = New-Object System.Drawing.Size(500, 860)
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.BackColor = $C.fondo
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$icoPath = Join-Path $raiz 'APP\Recursos\app.ico'
if (Test-Path $icoPath) { $form.Icon = New-Object System.Drawing.Icon($icoPath) }

# ---- cabecera azul ----
$head = New-Object System.Windows.Forms.Panel
$head.Dock = 'Top'; $head.Height = 108
$script:verTxt = 'v1.2.4'
$head.Add_Paint({
  param($s, $e)
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($s.ClientRectangle, $C.navyTop, $C.navyBot, 90.0)
  $e.Graphics.FillRectangle($br, $s.ClientRectangle); $br.Dispose()
  $fv = New-Object System.Drawing.Font('Segoe UI', 8)
  $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 160, 215))
  $sz = $e.Graphics.MeasureString($script:verTxt, $fv)
  $e.Graphics.DrawString($script:verTxt, $fv, $tb, ($s.ClientSize.Width - $sz.Width - 14), 10)
  $tb.Dispose(); $fv.Dispose()
})
$form.Controls.Add($head)

$logoPath = Join-Path $raiz 'APP\Recursos\logo.png'
if (Test-Path $logoPath) {
  $pb = New-Object System.Windows.Forms.PictureBox
  $pb.Image = [System.Drawing.Image]::FromFile($logoPath)
  $pb.SizeMode = 'Zoom'; $pb.SetBounds(20, 20, 68, 68); $pb.BackColor = [System.Drawing.Color]::Transparent
  $head.Controls.Add($pb)
}
$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Text = 'MovilLink'
$lblTitulo.ForeColor = [System.Drawing.Color]::White
$lblTitulo.Font = New-Object System.Drawing.Font('Segoe UI', 19, [System.Drawing.FontStyle]::Bold)
$lblTitulo.AutoSize = $true; $lblTitulo.Location = '102,14'; $lblTitulo.BackColor = [System.Drawing.Color]::Transparent
$head.Controls.Add($lblTitulo)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = 'Puente ADB WiFi - tu dev server en el movil'
$lblSub.ForeColor = [System.Drawing.Color]::FromArgb(170, 200, 240)
$lblSub.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$lblSub.SetBounds(104, 64, 388, 20); $lblSub.BackColor = [System.Drawing.Color]::Transparent
$head.Controls.Add($lblSub)

# ---- banda de estado ----
$est = New-Object System.Windows.Forms.Panel
$est.Dock = 'Top'; $est.Height = 56; $est.BackColor = $C.banda
$form.Controls.Add($est)

# Punto de estado pintado: alineacion perfecta con el texto (un caracter
# de fuente nunca queda centrado — lleva padding interno).
$script:estadoColor = $C.rojo
$script:estadoDotY = 14
$script:estadoDotX = 18
$est.Add_Paint({
  param($s, $e)
  $e.Graphics.SmoothingMode = 'AntiAlias'
  $b = New-Object System.Drawing.SolidBrush($script:estadoColor)
  $e.Graphics.FillEllipse($b, $script:estadoDotX, $script:estadoDotY, 12, 12)
  $b.Dispose()
})

$lblEstado = New-Object System.Windows.Forms.Label
$lblEstado.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$lblEstado.ForeColor = $C.texto
$lblEstado.AutoSize = $true; $lblEstado.Location = '50,4'
$lblEstado.Text = 'Comprobando...'
$est.Controls.Add($lblEstado)

$lblDetalle = New-Object System.Windows.Forms.Label
$lblDetalle.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$lblDetalle.ForeColor = $C.subtexto
$lblDetalle.AutoEllipsis = $true
$lblDetalle.TextAlign = 'MiddleCenter'

# El alto real del label de estado crece con el DPI y su padding interno —
# detalle y punto se posicionan midiendo en runtime, nunca hardcodeados.
$hDet = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $lblDetalle.Font).Height
$estadoBottom = [Math]::Max($lblEstado.Bottom, $lblEstado.Top + 20)
$script:estadoDotY = [int](($lblEstado.Top + $estadoBottom - 12) / 2)
$lblDetalle.SetBounds(12, ($estadoBottom + 3), [Math]::Max(120, ($est.ClientSize.Width - 24)), ($hDet + 1))
$est.Controls.Add($lblDetalle)

# Bloque punto + estado + detalle centrado en la banda: se recalcula al
# redimensionar y al cambiar el texto (su ancho varia entre estados).
function Update-EstadoCentro {
  $gw = 18 + $lblEstado.Width
  $dx = [Math]::Max(8, [int](($est.ClientSize.Width - $gw) / 2))
  $script:estadoDotX = $dx
  $lblEstado.Left = $dx + 18
  $lblDetalle.SetBounds(12, $lblDetalle.Top, [Math]::Max(120, ($est.ClientSize.Width - 24)), $lblDetalle.Height)
  $est.Invalidate()
}

# ---- cuerpo: columna centrada con ancho maximo ----
# En pantalla grande el contenido crece hasta 860px y queda centrado;
# los controles se estiran por anchors y el log absorbe el alto extra.
$content = New-Object System.Windows.Forms.Panel
$content.Dock = 'Fill'; $content.BackColor = $C.fondo
$form.Controls.Add($content)
$form.Controls.SetChildIndex($content, 0)

$col = New-Object System.Windows.Forms.Panel
$col.BackColor = $C.fondo
$col.SetBounds(0, 0, 500, 696)
$content.Controls.Add($col)

$content.Add_Resize({ Update-Layout })
$form.Add_Resize({ Update-Layout })
$form.Add_ResizeEnd({ Update-Layout })

# ---- boton principal + detener ----
$btnConectar = New-Btn 'CONECTAR' $C.verde $C.verdeOver @(16, 4, 336, 46)
$btnConectar.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$col.Controls.Add($btnConectar)

$btnDetener = New-Btn 'Detener' $C.rojo ([System.Drawing.Color]::FromArgb(185, 40, 40)) @(360, 4, 124, 46)
$btnDetener.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$col.Controls.Add($btnDetener)

# ---- reverse ----
$grpDev = New-Object System.Windows.Forms.GroupBox
$grpDev.Text = 'Reverse (dev server)'; $grpDev.ForeColor = $C.texto
$grpDev.SetBounds(16, 60, 468, 58)
$col.Controls.Add($grpDev)

$lblDev = New-Object System.Windows.Forms.Label
$lblDev.Text = 'Puerto dev:'; $lblDev.ForeColor = $C.texto
$lblDev.AutoSize = $true; $lblDev.Location = '12,25'
$grpDev.Controls.Add($lblDev)

$txtDev = New-Object System.Windows.Forms.TextBox
$txtDev.Text = "$Puerto"; $txtDev.SetBounds(112, 22, 56, 23)
$txtDev.BackColor = [System.Drawing.Color]::White; $txtDev.ForeColor = $C.texto
$txtDev.BorderStyle = 'FixedSingle'
$grpDev.Controls.Add($txtDev)

$btnReverse = New-Btn 'Reaplicar reverse' $C.azul $C.azulOver @(176, 20, 132, 27)
$grpDev.Controls.Add($btnReverse)

$chkVigilar = New-Object System.Windows.Forms.CheckBox
$chkVigilar.Text = 'Vigilar (auto, 3s)'
$chkVigilar.ForeColor = $C.texto; $chkVigilar.Checked = $true
$chkVigilar.AutoSize = $false; $chkVigilar.SetBounds(316, 24, 140, 20)
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($chkVigilar, 'Cada 3s: reconecta si se cayo y re-aplica el reverse si falta')
$grpDev.Controls.Add($chkVigilar)

# ---- conexion directa ----
$grpManual = New-Object System.Windows.Forms.GroupBox
$grpManual.Text = 'Conexion directa (IP:PUERTO del movil)'; $grpManual.ForeColor = $C.texto
$grpManual.SetBounds(16, 126, 468, 58)
$col.Controls.Add($grpManual)

$txtManual = New-Object System.Windows.Forms.TextBox
$txtManual.SetBounds(12, 22, 296, 23)
$txtManual.BackColor = [System.Drawing.Color]::White; $txtManual.ForeColor = $C.texto
$txtManual.BorderStyle = 'FixedSingle'
$grpManual.Controls.Add($txtManual)

$btnManual = New-Btn 'Conectar directo' $C.azul $C.azulOver @(318, 20, 138, 27)
$grpManual.Controls.Add($btnManual)

# ---- dispositivo conectado ----
$grpDisp = New-Object System.Windows.Forms.GroupBox
$grpDisp.Text = 'Dispositivo'; $grpDisp.ForeColor = $C.texto
$grpDisp.SetBounds(16, 192, 468, 66)
$col.Controls.Add($grpDisp)

$lblDispNombre = New-Object System.Windows.Forms.Label
$lblDispNombre.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$lblDispNombre.ForeColor = $C.texto
$lblDispNombre.SetBounds(12, 18, 444, 18)
$lblDispNombre.Text = 'Ninguno conectado'
$grpDisp.Controls.Add($lblDispNombre)

$lblDispInfo = New-Object System.Windows.Forms.Label
$lblDispInfo.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblDispInfo.ForeColor = $C.subtexto
$lblDispInfo.AutoEllipsis = $true
$lblDispInfo.SetBounds(12, 40, 444, 16)
$grpDisp.Controls.Add($lblDispInfo)

# ---- historial ----
$grpHist = New-Object System.Windows.Forms.GroupBox
$grpHist.Text = 'Historial (telefono-ultimo.json - editable a mano)'; $grpHist.ForeColor = $C.texto
$grpHist.SetBounds(16, 266, 468, 178)
$col.Controls.Add($grpHist)

$lst = New-Object System.Windows.Forms.ListBox
$lst.SetBounds(12, 20, 444, 110)
$lst.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$lst.BackColor = [System.Drawing.Color]::White; $lst.ForeColor = $C.texto
$lst.BorderStyle = 'FixedSingle'
$grpHist.Controls.Add($lst)

# Tooltip del item bajo el cursor (por si un endpoint largo queda cortado).
$script:lstTipIdx = -2
$lst.Add_MouseMove({
  $i = $lst.IndexFromPoint($_.Location)
  if ($i -lt 0 -or $i -ge $lst.Items.Count) { $i = -1 }
  if ($i -ne $script:lstTipIdx) {
    $script:lstTipIdx = $i
    $tip.SetToolTip($lst, $(if ($i -ge 0) { "$($lst.Items[$i])" } else { '' }))
  }
})

$btnProbar = New-Btn 'Probar' $C.azul $C.azulOver @(12, 138, 110, 27)
$grpHist.Controls.Add($btnProbar)
$btnQuitar = New-Btn 'Quitar' ([System.Drawing.Color]::White) ([System.Drawing.Color]::FromArgb(230, 238, 250)) @(130, 138, 110, 27)
$btnQuitar.ForeColor = $C.azul; $btnQuitar.FlatAppearance.BorderColor = $C.azul
$grpHist.Controls.Add($btnQuitar)
$btnRecargar = New-Btn 'Recargar' ([System.Drawing.Color]::White) ([System.Drawing.Color]::FromArgb(230, 238, 250)) @(248, 138, 110, 27)
$btnRecargar.ForeColor = $C.azul; $btnRecargar.FlatAppearance.BorderColor = $C.azul
$grpHist.Controls.Add($btnRecargar)

# ---- log ----
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = 'Registro'; $lblLog.ForeColor = $C.subtexto
$lblLog.AutoSize = $true; $lblLog.Location = '16,448'
$col.Controls.Add($lblLog)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'; $txtLog.WordWrap = $true
$txtLog.BackColor = $C.logFondo; $txtLog.ForeColor = $C.logTexto
$txtLog.BorderStyle = 'FixedSingle'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$txtLog.SetBounds(16, 478, 468, 190)
$col.Controls.Add($txtLog)

$lblPie = New-Object System.Windows.Forms.Label
$lblPie.Text = 'Luis Martin Peña Mejia - MKZ COMPANY'
$lblPie.ForeColor = $C.subtexto; $lblPie.Font = New-Object System.Drawing.Font('Segoe UI', 7.5)
$lblPie.AutoSize = $false; $lblPie.TextAlign = 'MiddleCenter'
$lblPie.SetBounds(16, 672, 468, 18)
$col.Controls.Add($lblPie)

# ---- layout responsivo manual ----
# Ventana estrecha: una columna centrada (max 860px) como el diseno original.
# Ventana ancha (>=1150px): dos columnas — acciones + registro a la
# izquierda, historial a altura completa a la derecha. Sin anchors:
# todas las posiciones se recalculan aqui al redimensionar.
function Update-Layout {
  if (-not $col -or -not $content) { return }
  # El tamano se lee del form (fuente de verdad) — el panel puede ir un
  # frame por detras durante transiciones de maximizar/restaurar.
  $W = $form.ClientSize.Width
  $H = $form.ClientSize.Height - 164
  if ($W -lt 100 -or $H -lt 300) { return }

  # banda a ancho completo: bloque de estado centrado y detalle estirado
  Update-EstadoCentro
  # Repintado total de la cabecera: sin esto, al redimensionar Windows solo
  # pinta la franja nueva y el "v1.2.1" viejo queda como fantasma duplicado.
  $head.Invalidate()

  if ($W -lt 1150) {
    $cw = [Math]::Min($W, 860)
    $col.SetBounds([int](($W - $cw) / 2), 0, $cw, $H)
    $gw = $cw - 32
    $btnConectar.SetBounds(16, 4, ($cw - 164), 46)
    $btnDetener.SetBounds(($cw - 140), 4, 124, 46)
    $grpDev.SetBounds(16, 60, $gw, 58)
    $chkVigilar.SetBounds(($gw - 152), 24, 140, 20)
    $grpManual.SetBounds(16, 126, $gw, 58)
    $txtManual.SetBounds(12, 22, ($gw - 172), 23)
    $btnManual.SetBounds(($gw - 150), 20, 138, 27)
    $grpDisp.SetBounds(16, 192, $gw, 66)
    $lblDispNombre.SetBounds(12, 18, ($gw - 24), 18)
    $lblDispInfo.SetBounds(12, 40, ($gw - 24), 16)
    $grpHist.SetBounds(16, 266, $gw, 178)
    $lst.SetBounds(12, 20, ($gw - 24), 110)
    $btnProbar.Location = '12,138'
    $btnQuitar.Location = '130,138'
    $btnRecargar.Location = '248,138'
    $lblLog.Location = '16,448'
    $txtLog.SetBounds(16, 478, $gw, ([Math]::Max(60, $H - 506)))
    $lblPie.SetBounds(16, ($H - 24), $gw, 18)
  } else {
    $cw = [Math]::Min(($W - 40), 1500)
    $col.SetBounds([int](($W - $cw) / 2), 0, $cw, $H)
    $lw = 560; $rx = 16 + $lw + 16; $rw = $cw - $rx - 16
    $btnConectar.SetBounds(16, 4, ($lw - 132), 46)
    $btnDetener.SetBounds(($lw - 108), 4, 124, 46)
    $grpDev.SetBounds(16, 60, $lw, 58)
    $chkVigilar.SetBounds(($lw - 152), 24, 140, 20)
    $grpManual.SetBounds(16, 126, $lw, 58)
    $txtManual.SetBounds(12, 22, ($lw - 172), 23)
    $btnManual.SetBounds(($lw - 150), 20, 138, 27)
    $grpDisp.SetBounds(16, 192, $lw, 66)
    $lblDispNombre.SetBounds(12, 18, ($lw - 24), 18)
    $lblDispInfo.SetBounds(12, 40, ($lw - 24), 16)
    $lblLog.Location = '16,270'
    $txtLog.SetBounds(16, 294, $lw, ([Math]::Max(60, $H - 322)))
    $gh = [Math]::Max(120, ($H - 32))
    $grpHist.SetBounds($rx, 4, $rw, $gh)
    $lst.SetBounds(12, 20, ([Math]::Max(60, $rw - 24)), ([Math]::Max(40, $gh - 72)))
    $by = $gh - 40
    $btnProbar.SetBounds(12, $by, 110, 27)
    $btnQuitar.SetBounds(130, $by, 110, 27)
    $btnRecargar.SetBounds(248, $by, 110, 27)
    $lblPie.SetBounds(16, ($H - 24), ($cw - 32), 18)
  }
}
Update-Layout

$script:ui = @{
  txtLog = $txtLog; lblEstado = $lblEstado; lblDetalle = $lblDetalle
  btnConectar = $btnConectar; btnManual = $btnManual; btnProbar = $btnProbar
  txtDev = $txtDev; txtManual = $txtManual; lst = $lst; chkVigilar = $chkVigilar
}
$script:nextRetry = Get-Date
$script:caidos = 0                 # ticks consecutivos sin movil (histeresis anti-flap)
$script:backoff = 25               # reintento auto exponencial (25 -> 300s max)
$script:cancelar = $false          # bandera de cancelacion leida por el Core
$script:detenido = $false          # Detener: monitor parado hasta accion manual
$script:pendienteManual = $null    # endpoint manual encolado tras cancelar

# Puerto dev validado: solo 1-65535; cualquier otra cosa vuelve a 3000.
function Get-DevPort {
  $dp = 0
  if ([int]::TryParse($txtDev.Text.Trim(), [ref]$dp) -and $dp -ge 1 -and $dp -le 65535) { return $dp }
  if ($txtDev.Text.Trim() -ne '3000') { $txtDev.Text = '3000'; Write-UiLog 'Puerto invalido -> vuelve a 3000 (rango 1-65535).' }
  return 3000
}

# Detalle con tooltip: el texto truncado (ellipsis) se ve completo al pasar el mouse.
function Set-Detalle([string]$t) {
  $lblDetalle.Text = $t
  $tip.SetToolTip($lblDetalle, $t)
  Update-EstadoCentro
}

# Ficha del dispositivo: modelo/marca/Android/IP via getprop — cacheada por
# serial para no lanzar shells adb en cada tick del monitor.
$script:dispCache = $null
function Get-InfoDisp([string]$serial) {
  if ($script:dispCache -and $script:dispCache.s -eq $serial) { return $script:dispCache }
  $info = @{ s = $serial; nombre = ''; so = ''; ip = '' }
  try {
    $model = ([string](& $script:adb -s $serial shell getprop ro.product.model 2>$null)).Trim()
    $brand = ([string](& $script:adb -s $serial shell getprop ro.product.brand 2>$null)).Trim()
    $ver   = ([string](& $script:adb -s $serial shell getprop ro.build.version.release 2>$null)).Trim()
    if ($model) {
      $marca = if ($brand) { (Get-Culture).TextInfo.ToTitleCase($brand.ToLower()) } else { '' }
      $info.nombre = "$marca $model".Trim()
    }
    if ($ver) { $info.so = "Android $ver" }
    if ($serial -match '^(\d{1,3}(?:\.\d{1,3}){3}):') { $info.ip = $Matches[1] }
    else {
      $route = [string](& $script:adb -s $serial shell ip route get 1.1.1.1 2>$null)
      if ($route -match 'src\s+(\d{1,3}(?:\.\d{1,3}){3})') { $info.ip = $Matches[1] }
    }
  } catch {}
  $script:dispCache = $info
  return $info
}

function Update-Status {
  try {
    # Sin adb no hay nada que consultar — reintenta resolver por si ya se instalo.
    if (-not $script:adb) {
      $script:adb = Resolve-Adb $raiz
      if (-not $script:adb) {
        $script:estadoColor = $C.rojo; $est.Invalidate()
        $lblEstado.Text = 'Falta adb'
        Set-Detalle 'Instala las herramientas (opcion 2 del menu MovilLink.bat)'
        $lblDispNombre.Text = 'Ninguno conectado'; $lblDispInfo.Text = ''
        return
      }
      Write-UiLog 'adb detectado.'
    }
    $lista = @(Get-Moviles)
    $dp = Get-DevPort
    if ($lista.Count -eq 0) {
      $script:estadoColor = $C.rojo; $est.Invalidate()
      $lblEstado.Text = 'Sin conexion'
      Set-Detalle 'Pulsa CONECTAR o deja que el monitor lo haga'
      $lblDispNombre.Text = 'Ninguno conectado'; $lblDispInfo.Text = ''; $script:dispCache = $null
      return
    }
    $serial = Select-Serial $lista
    $rev = Test-Reverse $serial $dp
    $script:estadoColor = if ($rev) { $C.verde } else { $C.ambar }; $est.Invalidate()
    $lblEstado.Text = if ($rev) { 'Listo' } else { 'Conectado (sin reverse)' }
    Set-Detalle "$serial   $([char]0x2192)   localhost:$dp/acceso"
    $d = Get-InfoDisp $serial
    $lblDispNombre.Text = "$(if ($d.nombre) { $d.nombre } else { 'Dispositivo Android' })$(if ($d.so) { "   ·   $($d.so)" } else { '' })"
    $lblDispInfo.Text = "IP: $(if ($d.ip) { $d.ip } else { '?' })   ·   $serial"
    $tip.SetToolTip($lblDispInfo, $lblDispInfo.Text)
  } catch { Write-UiError $_ }
}

function Update-Ficha {
  $lst.Items.Clear()
  $items = @(Get-Candidatos)
  if ($items.Count -eq 0) {
    [void]$lst.Items.Add('(vacio - conecta para guardar o edita APP\Datos\telefono-ultimo.json)')
    return
  }
  foreach ($e in $items) { [void]$lst.Items.Add(('{0}:{1}   ({2})' -f $e.ip, $e.adbPort, $e.actualizado)) }
}

function Start-Worker([string]$Accion, [string]$Arg = '') {
  $worker = $script:ui.worker
  if ($worker.IsBusy) {
    if ($Accion -eq 'directo' -and $Arg) {
      # El usuario manda: cancela el intento actual y encola el endpoint manual.
      $script:pendienteManual = $Arg
      $script:cancelar = $true
      Write-UiLog "Ocupado — cancelando el intento actual y probando $Arg..."
    } else {
      Write-UiLog 'Ya hay una conexion en curso — espera a que termine o pulsa Detener.'
    }
    return
  }
  if (-not $script:adb) { Write-UiLog 'adb no encontrado — instala primero (opcion 2 del menu).'; return }
  $dp = Get-DevPort
  $script:cancelar = $false         # un intento nuevo limpia la cancelacion
  $script:detenido = $false         # accion del usuario reanuda el monitor
  $script:backoff = 25              # y resetea el backoff de reintentos
  # Los botones quedan ACTIVOS durante el intento: el guardia real es
  # worker.IsBusy (encola el endpoint manual y cancela). Deshabilitarlos
  # dejaba clicks muertos durante barridos largos.
  $worker.RunWorkerAsync(@{ accion = $Accion; arg = $Arg; devPort = $dp })
}

# ------------------------------- worker --------------------------------
$worker = New-Object System.ComponentModel.BackgroundWorker
$worker.WorkerReportsProgress = $true
$script:ui.worker = $worker

$worker.add_DoWork({
  param($s, $e)
  $a = $e.Argument.accion; $arg = $e.Argument.arg
  $report = { param($m) $s.ReportProgress(0, $m) }
  try {
    switch ($a) {
      'auto' {
        $script:daemonReiniciado = $false
        & $report 'Conectando (mDNS -> ficha -> vecinos -> subred -> barrido)...'
        $serial = Connect-Auto
        if ($script:cancelar) { $e.Result = 'FAIL: detenido por el usuario'; return }
        if (-not $serial) { $e.Result = 'FAIL: sin respuesta del movil'; return }
        $dp = [int]$e.Argument.devPort
        & $report "Movil: $serial"
        Confirm-Conexion $serial $dp | Out-Null
        $e.Result = "OK:$serial"
      }
      'directo' {
        $serial = Invoke-ConexionDirecta $arg
        if (-not $serial) { $e.Result = "FAIL: $arg no respondio"; return }
        $dp = [int]$e.Argument.devPort
        Confirm-Conexion $serial $dp | Out-Null
        $e.Result = "OK:$serial"
      }
    }
  } catch { $e.Result = "FAIL: $($_.Exception.Message)" }
})

$worker.add_ProgressChanged({ param($s, $e) if ($e.UserState) { Write-UiLog ([string]$e.UserState) } })

$worker.add_RunWorkerCompleted({
  param($s, $e)
  $r = [string]$e.Result
  if ($r -like 'FAIL:*') {
    Write-UiLog $r
    # Backoff exponencial: 25 -> 50 -> 100 -> 200 -> 300s max. Menos spam
    # en el registro y menos desgaste con el movil apagado un rato.
    $script:nextRetry = (Get-Date).AddSeconds($script:backoff)
    if ($chkVigilar.Checked -and -not $script:detenido) { Write-UiLog "  (proximo reintento auto en $($script:backoff)s)" }
    $script:backoff = [Math]::Min($script:backoff * 2, 300)
  }
  elseif ($r -like 'OK:*') { $script:backoff = 25; Write-UiLog "Conectado: $($r.Substring(3))" }
  $script:cancelar = $false
  if ($script:pendienteManual) {
    # El usuario pidio un endpoint manual durante la cancelacion: probarlo ya.
    $ep = $script:pendienteManual; $script:pendienteManual = $null
    Write-UiLog "Probando tu endpoint: $ep"
    Update-Ficha; Update-Status
    Start-Worker 'directo' $ep
    return
  }
  Update-Ficha
  Update-Status
})

# ------------------------------ eventos ---------------------------------
$btnConectar.Add_Click({
  try { $script:nextRetry = Get-Date; Start-Worker 'auto' } catch { Write-UiError $_ }
})

$btnManual.Add_Click({
  try {
    $ep = $txtManual.Text.Trim()
    if ($ep -notmatch '^\d{1,3}(\.\d{1,3}){3}:\d+$') { Write-UiLog 'Formato: IP:PUERTO (ej. 192.168.100.189:36653)'; return }
    Start-Worker 'directo' $ep
  } catch { Write-UiError $_ }
})

$btnProbar.Add_Click({
  try {
    if ($lst.SelectedIndex -lt 0 -or "$($lst.SelectedItem)".StartsWith('(')) { Write-UiLog 'Selecciona un endpoint valido del historial.'; return }
    $ep = ($lst.SelectedItem -split '\s')[0]
    Start-Worker 'directo' $ep
  } catch { Write-UiError $_ }
})

$btnQuitar.Add_Click({
  try {
    if ($lst.SelectedIndex -lt 0 -or "$($lst.SelectedItem)".StartsWith('(')) { return }
    $ep = ($lst.SelectedItem -split '\s')[0]
    if ($ep -match '^(\d{1,3}(?:\.\d{1,3}){3}):(\d+)$') { Remove-Endpoint $Matches[1] ([int]$Matches[2]) }
    Update-Ficha
  } catch { Write-UiError $_ }
})

$btnRecargar.Add_Click({ try { Update-Ficha } catch { Write-UiError $_ } })

$btnDetener.Add_Click({
  try {
    $script:cancelar = $true
    $script:detenido = $true
    Write-UiLog 'Detenido — el monitor no reintentara hasta CONECTAR, directo o Vigilar.'
  } catch { Write-UiError $_ }
})

# Re-marcar Vigilar a mano tambien rearma el monitor.
$chkVigilar.Add_CheckedChanged({ if ($chkVigilar.Checked) { $script:detenido = $false } })

$btnReverse.Add_Click({
  try {
    if (-not $script:adb) { Write-UiLog 'adb no encontrado.'; return }
    $lista = @(Get-Moviles)
    if (-not $lista) { Write-UiLog 'Sin movil conectado.'; return }
    $serial = Select-Serial $lista
    $dp = Get-DevPort
    Set-Reverse $serial $dp
    Write-UiLog "reverse re-aplicado: tcp:$dp"
    Update-Status
  } catch { Write-UiError $_ }
})

# ------------------------------ monitor ---------------------------------
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
  try {
    if ($worker.IsBusy -or -not $script:adb) { Update-Status; return }
    if ($script:detenido) { Update-Status; return }
    $lista = @(Get-Moviles)
    $dp = Get-DevPort
    if ($lista.Count -eq 0) {
      $script:caidos++
      # Transporte 'offline' = el movil sigue ahi (TLS renegociando, WiFi
      # dormido): `adb reconnect` lo revive en ~1s sin barrer nada. La
      # busqueda completa solo arranca tras 3 ticks vacios (~9s de verdad
      # sin movil) — un parpadeo ya no dispara el escaner.
      if (@(Get-Transportes | Where-Object { $_.estado -eq 'offline' })) { Invoke-Reconnect }
      if ($chkVigilar.Checked -and $script:caidos -ge 3 -and (Get-Date) -gt $script:nextRetry) {
        Write-UiLog 'Sin conexion -> autoconectando...'
        $script:caidos = 0
        $script:nextRetry = (Get-Date).AddSeconds($script:backoff)
        Start-Worker 'auto'
      }
    }
    else {
      $script:caidos = 0
      $serial = Select-Serial $lista
      if (-not (Test-Reverse $serial $dp)) {
        Set-Reverse $serial $dp
        Write-UiLog "reverse re-aplicado (tcp:$dp)"
      }
    }
    Update-Status
  } catch { Write-UiError $_ }
})
$timer.Start()

# ------------------------------- arranque -------------------------------
$form.Add_Shown({
  Write-UiLog 'MovilLink listo. El monitor vigila conexion y reverse.'
  if (-not $cfg.adbOk) { Write-UiLog 'AVISO: adb no encontrado — opcion 2 del menu MovilLink.bat' }
  Update-Ficha
  Update-Status
})

if ($Captura) {
  # Genera APP\Recursos\captura.png con la app real en marcha (docs).
  $capTimer = New-Object System.Windows.Forms.Timer
  $capTimer.Interval = 1500
  $capTimer.Add_Tick({
    $capTimer.Stop()
    try {
      $bmp = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
      $form.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
      $destino = if ($CapturaRuta) { $CapturaRuta } else { Join-Path $raiz 'APP\Recursos\captura.png' }
      $bmp.Save($destino, [System.Drawing.Imaging.ImageFormat]::Png)
      $bmp.Dispose()
    } catch {}
    $form.Close()
  })
  $capTimer.Start()
}

# Dock=Top se procesa en orden inverso: el ultimo indice queda mas arriba.
$form.Controls.SetChildIndex($head, $form.Controls.Count - 1)

try {
  [void]$form.ShowDialog()
} catch {
  $f = Write-ErrorLog $_
  [void][System.Windows.Forms.MessageBox]::Show("MovilLink encontro un error.`n$($_.Exception.Message)`n`nDetalle: $f", 'MovilLink', 'OK', 'Error')
} finally {
  $timer.Stop()
  # Libera el mutex de instancia unica al salir limpio.
  try { $mutex.ReleaseMutex(); $mutex.Dispose() } catch {}
}
