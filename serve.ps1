# Simple local preview server for the Nails by Mary website.
# Run:  powershell -ExecutionPolicy Bypass -File serve.ps1   then open http://localhost:5500
param([int]$Port = 5500)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.js' = 'application/javascript; charset=utf-8'; '.svg' = 'image/svg+xml'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'
  '.webp' = 'image/webp'; '.gif' = 'image/gif'; '.ico' = 'image/x-icon'; '.json' = 'application/json'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try {
  $listener.Start()
} catch {
  Write-Host "Port $Port is already in use. Stop the other preview server (or pass -Port 5501) and try again."
  exit 1
}
Write-Host "Serving $root at http://localhost:$Port/  (Ctrl+C to stop)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($rel -eq '') { $rel = 'index.html' }
    $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if ((Test-Path $path -PathType Container)) { $path = Join-Path $path 'index.html' }
    if ($path.StartsWith($root) -and (Test-Path $path -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($path)
      $ext = [IO.Path]::GetExtension($path).ToLower()
      $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
      $ctx.Response.StatusCode = 200
    } else {
      $bytes = [Text.Encoding]::UTF8.GetBytes('Not found')
      $ctx.Response.StatusCode = 404
    }
    try {
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {
      Write-Host "Request error: $_"
    } finally {
      $ctx.Response.Close()
    }
    Write-Host "$($ctx.Response.StatusCode) /$rel"
  }
} finally {
  if ($listener.IsListening) { $listener.Stop() }
  $listener.Close()
}
