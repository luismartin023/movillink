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

function Ui-Log([string]$m) {
  $tb = $script:ui.txtLog
  if (-not $tb -or $tb.IsDisposed) { return }
  $linea = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  if ($tb.InvokeRequired) { $tb.Invoke([Action]{ $tb.AppendText($linea + [Environment]::NewLine) }) }
  else { $tb.AppendText($linea + [Environment]::NewLine) }
}
$script:OnLog = { param($m) Ui-Log $m }

function Ui-Error($Err) {
  $f = Write-ErrorLog $Err
  Ui-Log "ERROR: $($Err.Exception.Message)"
  if ($f) { Ui-Log "  detalle -> $f" }
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
    catch { $f = Write-ErrorLog $_ }
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
$form.ClientSize = New-Object System.Drawing.Size(500, 786)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.BackColor = $C.fondo
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$icoPath = Join-Path $raiz 'APP\Recursos\app.ico'
if (Test-Path $icoPath) { $form.Icon = New-Object System.Drawing.Icon($icoPath) }

# ---- cabecera azul ----
$head = New-Object System.Windows.Forms.Panel
$head.Dock = 'Top'; $head.Height = 108
$head.Add_Paint({
  param($s, $e)
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($s.ClientRectangle, $C.navyTop, $C.navyBot, 0.0)
  $e.Graphics.FillRectangle($br, $s.ClientRectangle); $br.Dispose()
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

$lblVer = New-Object System.Windows.Forms.Label
$lblVer.Text = 'v1.1.0'
$lblVer.ForeColor = [System.Drawing.Color]::FromArgb(120, 160, 215)
$lblVer.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblVer.AutoSize = $true; $lblVer.Location = '452,16'; $lblVer.BackColor = [System.Drawing.Color]::Transparent
$head.Controls.Add($lblVer)

# ---- banda de estado ----
$est = New-Object System.Windows.Forms.Panel
$est.Dock = 'Top'; $est.Height = 56; $est.BackColor = $C.banda
$form.Controls.Add($est)

$dot = New-Object System.Windows.Forms.Label
$dot.Text = [string][char]0x25CF
$dot.Font = New-Object System.Drawing.Font('Segoe UI', 20)
$dot.AutoSize = $true; $dot.Location = '16,6'
$dot.ForeColor = $C.rojo
$est.Controls.Add($dot)

$lblEstado = New-Object System.Windows.Forms.Label
$lblEstado.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$lblEstado.ForeColor = $C.texto
$lblEstado.AutoSize = $true; $lblEstado.Location = '52,7'
$lblEstado.Text = 'Comprobando...'
$est.Controls.Add($lblEstado)

$lblDetalle = New-Object System.Windows.Forms.Label
$lblDetalle.Font = New-Object System.Drawing.Font('Segoe UI', 8)
$lblDetalle.ForeColor = $C.subtexto
$lblDetalle.AutoEllipsis = $true
$lblDetalle.SetBounds(52, 30, 432, 20)
$est.Controls.Add($lblDetalle)

# ---- boton principal ----
$btnConectar = New-Btn 'CONECTAR' $C.verde $C.verdeOver @(16, 168, 468, 46)
$btnConectar.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnConectar)

# ---- reverse ----
$grpDev = New-Object System.Windows.Forms.GroupBox
$grpDev.Text = 'Reverse (dev server)'; $grpDev.ForeColor = $C.texto
$grpDev.SetBounds(16, 224, 468, 58)
$form.Controls.Add($grpDev)

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
$chkVigilar.AutoSize = $true; $chkVigilar.Location = '316,25'
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($chkVigilar, 'Cada 3s: reconecta si se cayo y re-aplica el reverse si falta')
$grpDev.Controls.Add($chkVigilar)

# ---- conexion directa ----
$grpManual = New-Object System.Windows.Forms.GroupBox
$grpManual.Text = 'Conexion directa (IP:PUERTO del movil)'; $grpManual.ForeColor = $C.texto
$grpManual.SetBounds(16, 290, 468, 58)
$form.Controls.Add($grpManual)

$txtManual = New-Object System.Windows.Forms.TextBox
$txtManual.SetBounds(12, 22, 296, 23)
$txtManual.BackColor = [System.Drawing.Color]::White; $txtManual.ForeColor = $C.texto
$txtManual.BorderStyle = 'FixedSingle'
$grpManual.Controls.Add($txtManual)

$btnManual = New-Btn 'Conectar directo' $C.azul $C.azulOver @(318, 20, 138, 27)
$grpManual.Controls.Add($btnManual)

# ---- historial ----
$grpHist = New-Object System.Windows.Forms.GroupBox
$grpHist.Text = 'Historial (telefono-ultimo.json - editable a mano)'; $grpHist.ForeColor = $C.texto
$grpHist.SetBounds(16, 356, 468, 178)
$form.Controls.Add($grpHist)

$lst = New-Object System.Windows.Forms.ListBox
$lst.SetBounds(12, 20, 444, 110)
$lst.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$lst.BackColor = [System.Drawing.Color]::White; $lst.ForeColor = $C.texto
$lst.BorderStyle = 'FixedSingle'
$grpHist.Controls.Add($lst)

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
$lblLog.AutoSize = $true; $lblLog.Location = '16,542'
$form.Controls.Add($lblLog)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.BackColor = $C.logFondo; $txtLog.ForeColor = $C.logTexto
$txtLog.BorderStyle = 'FixedSingle'
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$txtLog.SetBounds(16, 562, 468, 196)
$form.Controls.Add($txtLog)

$lblPie = New-Object System.Windows.Forms.Label
$lblPie.Text = 'Luis Martin Peña Mejia - MKZ COMPANY'
$lblPie.ForeColor = $C.subtexto; $lblPie.Font = New-Object System.Drawing.Font('Segoe UI', 7.5)
$lblPie.AutoSize = $false; $lblPie.TextAlign = 'MiddleCenter'
$lblPie.SetBounds(16, 762, 468, 18)
$form.Controls.Add($lblPie)

$script:ui = @{
  txtLog = $txtLog; dot = $dot; lblEstado = $lblEstado; lblDetalle = $lblDetalle
  btnConectar = $btnConectar; btnManual = $btnManual; btnProbar = $btnProbar
  txtDev = $txtDev; txtManual = $txtManual; lst = $lst; chkVigilar = $chkVigilar
}
$script:nextRetry = Get-Date

# Puerto dev validado: solo 1-65535; cualquier otra cosa vuelve a 3000.
function Get-DevPort {
  $dp = 0
  if ([int]::TryParse($txtDev.Text.Trim(), [ref]$dp) -and $dp -ge 1 -and $dp -le 65535) { return $dp }
  if ($txtDev.Text.Trim() -ne '3000') { $txtDev.Text = '3000'; Ui-Log 'Puerto invalido -> vuelve a 3000 (rango 1-65535).' }
  return 3000
}

function Update-Status {
  try {
    # Sin adb no hay nada que consultar — reintenta resolver por si ya se instalo.
    if (-not $script:adb) {
      $script:adb = Resolve-Adb $raiz
      if (-not $script:adb) {
        $dot.ForeColor = $C.rojo
        $lblEstado.Text = 'Falta adb'
        $lblDetalle.Text = 'Instala las herramientas (opcion 2 del menu MovilLink.bat)'
        return
      }
      Ui-Log 'adb detectado.'
    }
    $lista = @(Get-Moviles)
    $dp = Get-DevPort
    if ($lista.Count -eq 0) {
      $dot.ForeColor = $C.rojo
      $lblEstado.Text = 'Sin conexion'
      $lblDetalle.Text = 'Pulsa CONECTAR o deja que el monitor lo haga'
      return
    }
    $serial = Select-Serial $lista
    $rev = Test-Reverse $serial $dp
    $dot.ForeColor = if ($rev) { $C.verde } else { $C.ambar }
    $lblEstado.Text = if ($rev) { 'Listo' } else { 'Conectado (sin reverse)' }
    $lblDetalle.Text = "$serial  ->  localhost:$dp/acceso"
  } catch { Ui-Error $_ }
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
  if ($worker.IsBusy) { return }
  if (-not $script:adb) { Ui-Log 'adb no encontrado — instala primero (opcion 2 del menu).'; return }
  $dp = Get-DevPort
  $btnConectar.Enabled = $false; $btnManual.Enabled = $false; $btnProbar.Enabled = $false
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

$worker.add_ProgressChanged({ param($s, $e) if ($e.UserState) { Ui-Log ([string]$e.UserState) } })

$worker.add_RunWorkerCompleted({
  param($s, $e)
  $btnConectar.Enabled = $true; $btnManual.Enabled = $true; $btnProbar.Enabled = $true
  $r = [string]$e.Result
  if ($r -like 'FAIL:*') { Ui-Log $r; $script:nextRetry = (Get-Date).AddSeconds(20) }
  elseif ($r -like 'OK:*') { Ui-Log "Conectado: $($r.Substring(3))" }
  Update-Ficha
  Update-Status
})

# ------------------------------ eventos ---------------------------------
$btnConectar.Add_Click({
  try { $script:nextRetry = Get-Date; Start-Worker 'auto' } catch { Ui-Error $_ }
})

$btnManual.Add_Click({
  try {
    $ep = $txtManual.Text.Trim()
    if ($ep -notmatch '^\d{1,3}(\.\d{1,3}){3}:\d+$') { Ui-Log 'Formato: IP:PUERTO (ej. 192.168.100.189:36653)'; return }
    Start-Worker 'directo' $ep
  } catch { Ui-Error $_ }
})

$btnProbar.Add_Click({
  try {
    if ($lst.SelectedIndex -lt 0 -or "$($lst.SelectedItem)".StartsWith('(')) { Ui-Log 'Selecciona un endpoint valido del historial.'; return }
    $ep = ($lst.SelectedItem -split '\s')[0]
    Start-Worker 'directo' $ep
  } catch { Ui-Error $_ }
})

$btnQuitar.Add_Click({
  try {
    if ($lst.SelectedIndex -lt 0 -or "$($lst.SelectedItem)".StartsWith('(')) { return }
    $ep = ($lst.SelectedItem -split '\s')[0]
    if ($ep -match '^(\d{1,3}(?:\.\d{1,3}){3}):(\d+)$') { Remove-Endpoint $Matches[1] ([int]$Matches[2]) }
    Update-Ficha
  } catch { Ui-Error $_ }
})

$btnRecargar.Add_Click({ try { Update-Ficha } catch { Ui-Error $_ } })

$btnReverse.Add_Click({
  try {
    if (-not $script:adb) { Ui-Log 'adb no encontrado.'; return }
    $lista = @(Get-Moviles)
    if (-not $lista) { Ui-Log 'Sin movil conectado.'; return }
    $serial = Select-Serial $lista
    $dp = Get-DevPort
    Set-Reverse $serial $dp
    Ui-Log "reverse re-aplicado: tcp:$dp"
    Update-Status
  } catch { Ui-Error $_ }
})

# ------------------------------ monitor ---------------------------------
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
  try {
    if ($worker.IsBusy -or -not $script:adb) { Update-Status; return }
    $lista = @(Get-Moviles)
    $dp = Get-DevPort
    if ($lista.Count -eq 0) {
      if ($chkVigilar.Checked -and (Get-Date) -gt $script:nextRetry) {
        Ui-Log 'Sin conexion -> autoconectando...'
        $script:nextRetry = (Get-Date).AddSeconds(25)
        Start-Worker 'auto'
      }
    }
    else {
      $serial = Select-Serial $lista
      if (-not (Test-Reverse $serial $dp)) {
        Set-Reverse $serial $dp
        Ui-Log "reverse re-aplicado (tcp:$dp)"
      }
    }
    Update-Status
  } catch { Ui-Error $_ }
})
$timer.Start()

# ------------------------------- arranque -------------------------------
$form.Add_Shown({
  Ui-Log 'MovilLink listo. El monitor vigila conexion y reverse.'
  if (-not $cfg.adbOk) { Ui-Log 'AVISO: adb no encontrado — opcion 2 del menu MovilLink.bat' }
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
}
