# Mebalife - basit yerel gelistirme sunucusu (Node/npm gerektirmez)
# Kullanim:  .\dev.ps1        veya    .\dev.ps1 -Port 3000
param(
  [int]$Port = 5173,
  [switch]$NoBrowser
)

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.htm'  = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif'  = 'image/gif'
  '.svg'  = 'image/svg+xml'
  '.webp' = 'image/webp'
  '.ico'  = 'image/x-icon'
  '.woff' = 'font/woff'
  '.woff2'= 'font/woff2'
  '.pdf'  = 'application/pdf'
  '.txt'  = 'text/plain; charset=utf-8'
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
  $listener.Start()
} catch {
  Write-Host "HATA: $Port portu acilamadi. Baska bir port deneyin:  .\dev.ps1 -Port 3000" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "  Mebalife dev sunucusu calisiyor" -ForegroundColor Green
Write-Host "  $prefix"
Write-Host "  Klasor: $root"
Write-Host "  Durdurmak icin: Ctrl+C"
Write-Host ""

if (-not $NoBrowser) { Start-Process $prefix }

try {
  while ($listener.IsListening) {
    $context  = $listener.GetContext()
    $request  = $context.Request
    $response = $context.Response

    $rel = [Uri]::UnescapeDataString($request.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'index.html' }
    $path = Join-Path $root $rel

    # klasor disina cikilmasini engelle
    $full = [IO.Path]::GetFullPath($path)
    if (-not $full.StartsWith([IO.Path]::GetFullPath($root), [StringComparison]::OrdinalIgnoreCase)) {
      $response.StatusCode = 403
      $response.Close()
      continue
    }

    if (Test-Path $full -PathType Container) { $full = Join-Path $full 'index.html' }

    if (Test-Path $full -PathType Leaf) {
      $ext = [IO.Path]::GetExtension($full).ToLower()
      $type = $mime[$ext]
      if (-not $type) { $type = 'application/octet-stream' }

      $bytes = [IO.File]::ReadAllBytes($full)
      $response.ContentType = $type
      $response.Headers.Add('Cache-Control', 'no-store')
      $response.ContentLength64 = $bytes.Length
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      Write-Host ("  200  /{0}" -f $rel) -ForegroundColor DarkGray
    } else {
      $msg = [Text.Encoding]::UTF8.GetBytes('404 - bulunamadi')
      $response.StatusCode = 404
      $response.ContentType = 'text/plain; charset=utf-8'
      $response.ContentLength64 = $msg.Length
      $response.OutputStream.Write($msg, 0, $msg.Length)
      Write-Host ("  404  /{0}" -f $rel) -ForegroundColor DarkYellow
    }
    $response.Close()
  }
} finally {
  $listener.Stop()
  $listener.Close()
  Write-Host "`n  Sunucu durduruldu." -ForegroundColor Yellow
}
