$ErrorActionPreference = "Stop"

$appDir = Join-Path $env:LOCALAPPDATA "Programs\Document Sidecar"
$exe = Join-Path $appDir "Document Sidecar.exe"
$resources = Join-Path $appDir "resources"
$server = Join-Path $resources "server\server.js"
$watcher = Join-Path $resources "sidecar-bridge.cjs"
$dataDir = Join-Path $env:APPDATA "document-cursor\data"
$node = "C:\Program Files\nodejs\node.exe"

if (-not (Test-Path -LiteralPath $exe)) { throw "Document Sidecar executable not found: $exe" }
if (-not (Test-Path -LiteralPath $server)) { throw "Sidecar server not found: $server" }
if (-not (Test-Path -LiteralPath $watcher)) { throw "Sidecar watcher not found: $watcher" }
if (-not (Test-Path -LiteralPath $node)) { throw "Node.js not found: $node" }

New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

function Test-SidecarServer {
  try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:4195" -UseBasicParsing -TimeoutSec 2
    return [int]$response.StatusCode -lt 500
  } catch {
    return $false
  }
}

function Start-HiddenProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [hashtable]$Environment = @{},
    [bool]$Hidden = $true
  )

  $info = New-Object System.Diagnostics.ProcessStartInfo
  $info.FileName = $FilePath
  $info.WorkingDirectory = $WorkingDirectory
  $info.UseShellExecute = $false
  if ($Hidden) {
    $info.CreateNoWindow = $true
    $info.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
  }
  $escapedArgs = foreach ($arg in $Arguments) {
    '"' + ($arg -replace '"', '\"') + '"'
  }
  $info.Arguments = ($escapedArgs -join " ")
  foreach ($key in $Environment.Keys) {
    $info.EnvironmentVariables[$key] = [string]$Environment[$key]
  }

  return [System.Diagnostics.Process]::Start($info)
}

$baseEnv = @{
  NODE_ENV = "production"
  PORT = "4195"
  HOSTNAME = "127.0.0.1"
  DOCUMENT_SIDECAR_APP_VERSION = "0.1.6"
  DOCUMENT_SIDECAR_DATA_DIR = $dataDir
}

if (-not (Test-SidecarServer)) {
  $serverEnv = @{}
  foreach ($key in $baseEnv.Keys) { $serverEnv[$key] = $baseEnv[$key] }

  Start-HiddenProcess `
    -FilePath $node `
    -Arguments @($server) `
    -WorkingDirectory (Split-Path -Parent $server) `
    -Environment $serverEnv | Out-Null

  for ($i = 0; $i -lt 30; $i++) {
    if (Test-SidecarServer) { break }
    Start-Sleep -Milliseconds 500
  }
}

$watcherRunning = Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like "*sidecar-bridge.cjs*watch*" }

if (-not $watcherRunning) {
  $watcherEnv = @{}
  $watcherEnv["DOCUMENT_SIDECAR_DATA_DIR"] = $dataDir

  Start-HiddenProcess `
    -FilePath $node `
    -Arguments @($watcher, "watch") `
    -WorkingDirectory $dataDir `
    -Environment $watcherEnv | Out-Null
}

$previousExternalServer = $env:DOCUMENT_SIDECAR_EXTERNAL_SERVER
$previousSkipWatcher = $env:DOCUMENT_SIDECAR_SKIP_WATCHER
$previousDataDir = $env:DOCUMENT_SIDECAR_DATA_DIR

try {
  $env:DOCUMENT_SIDECAR_EXTERNAL_SERVER = "1"
  $env:DOCUMENT_SIDECAR_SKIP_WATCHER = "1"
  $env:DOCUMENT_SIDECAR_DATA_DIR = $dataDir

  Start-Process -FilePath $exe `
    -WorkingDirectory $appDir `
    -WindowStyle Normal | Out-Null
} finally {
  $env:DOCUMENT_SIDECAR_EXTERNAL_SERVER = $previousExternalServer
  $env:DOCUMENT_SIDECAR_SKIP_WATCHER = $previousSkipWatcher
  $env:DOCUMENT_SIDECAR_DATA_DIR = $previousDataDir
}
