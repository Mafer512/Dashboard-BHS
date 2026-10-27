#Requires -Version 5.1
<#
.SYNOPSIS
Convierte un plano PDF de una pagina a PNG con el motor nativo de Windows.
.DESCRIPTION
Ejecutar con Windows PowerShell 5.1. No requiere instalar programas ni paquetes.
X, Y, AnchoRecorte y AltoRecorte son porcentajes de la pagina, desde arriba a la
izquierda. El ancho de salida se aplica al recorte y se conserva su proporcion.
Primero renderiza la pagina completa; el recorte util se decide viendo el plano.
.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/renderizar_layout.ps1 -Pdf "planos/nivel-10.50.pdf" -Salida "assets/layout/nivel-10-50.png"
.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/renderizar_layout.ps1 -Pdf "planos/nivel-5.25.pdf" -Salida "assets/layout/nivel-5-25.png" -X 5 -Y 10 -AnchoRecorte 90 -AltoRecorte 80 -Sobrescribir
Los porcentajes del segundo ejemplo son ilustrativos; no calibran ningun plano real.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Pdf,
    [Parameter(Mandatory = $true)][string]$Salida,
    [ValidateRange(100, 6000)][int]$Ancho = 3000,
    [ValidateRange(0, 100)][double]$X = 0,
    [ValidateRange(0, 100)][double]$Y = 0,
    [ValidateRange(0.01, 100)][double]$AnchoRecorte = 100,
    [ValidateRange(0.01, 100)][double]$AltoRecorte = 100,
    [switch]$Sobrescribir
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Usa Windows PowerShell 5.1 (powershell.exe), que incluye la proyeccion WinRT.'
}
if ($X + $AnchoRecorte -gt 100 -or $Y + $AltoRecorte -gt 100) {
    throw 'El recorte debe quedar dentro del 100 % de la pagina.'
}
$pdfPath = (Resolve-Path -LiteralPath $Pdf).Path
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Salida)
if ([IO.Path]::GetExtension($pdfPath) -ine '.pdf' -or [IO.Path]::GetExtension($outputPath) -ine '.png') {
    throw 'La entrada debe ser PDF y la salida PNG.'
}
if ((Test-Path -LiteralPath $outputPath) -and -not $Sobrescribir) {
    throw 'La salida ya existe. Usa -Sobrescribir para reemplazarla.'
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$storageType = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$pdfType = [Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
$optionsType = [Windows.Data.Pdf.PdfPageRenderOptions, Windows.Data.Pdf, ContentType = WindowsRuntime]
$streamType = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
$encoderType = [Windows.Graphics.Imaging.BitmapEncoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$asOperationTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
$asActionTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
} | Select-Object -First 1

function EsperarResultado($Operacion, [type]$Tipo) {
    $task = $asOperationTask.MakeGenericMethod($Tipo).Invoke($null, @($Operacion))
    return $task.GetAwaiter().GetResult()
}

$sourceFile = EsperarResultado ($storageType::GetFileFromPathAsync($pdfPath)) $storageType
$document = EsperarResultado ($pdfType::LoadFromFileAsync($sourceFile)) $pdfType
if ($document.PageCount -ne 1) {
    throw ('Se esperaba un plano de una pagina; el PDF contiene {0}.' -f $document.PageCount)
}
$page = $document.GetPage(0)
$memoryStream = $null
$reader = $null
$outputStream = $null
try {
    $options = [Activator]::CreateInstance($optionsType)
    $crop = $options.SourceRect
    $crop.X = $page.Size.Width * $X / 100
    $crop.Y = $page.Size.Height * $Y / 100
    $crop.Width = $page.Size.Width * $AnchoRecorte / 100
    $crop.Height = $page.Size.Height * $AltoRecorte / 100
    $height = [Math]::Max(1, [Math]::Round($Ancho * $crop.Height / $crop.Width))
    if ($height -gt 12000) { throw 'El recorte produciria una imagen demasiado alta. Reduce -Ancho o amplia el recorte horizontal.' }
    $options.SourceRect = $crop
    $options.DestinationWidth = $Ancho
    $options.DestinationHeight = $height
    $options.BitmapEncoderId = $encoderType::PngEncoderId
    $options.IsIgnoringHighContrast = $true
    $background = $options.BackgroundColor
    $background.A = $background.R = $background.G = $background.B = 255
    $options.BackgroundColor = $background
    $memoryStream = [Activator]::CreateInstance($streamType)
    $action = $page.RenderToStreamAsync($memoryStream, $options)
    $task = $asActionTask.Invoke($null, @($action))
    $null = $task.GetAwaiter().GetResult()
    $memoryStream.Seek(0)
    $reader = [IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($memoryStream)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputPath)) | Out-Null
    $mode = if ($Sobrescribir) { [IO.FileMode]::Create } else { [IO.FileMode]::CreateNew }
    $outputStream = [IO.File]::Open($outputPath, $mode, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $reader.CopyTo($outputStream)
} finally {
    if ($outputStream) { $outputStream.Dispose() }
    if ($reader) { $reader.Dispose() }
    if ($memoryStream) { $memoryStream.Dispose() }
    $page.Dispose()
}
Write-Output ('PNG: {0}' -f $outputPath)
Write-Output ('Dimensiones: {0} x {1} px; recorte (%): X={2}, Y={3}, ancho={4}, alto={5}' -f $Ancho, $height, $X, $Y, $AnchoRecorte, $AltoRecorte)
