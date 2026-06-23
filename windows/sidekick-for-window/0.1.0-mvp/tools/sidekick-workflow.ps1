param(
  [Parameter(Mandatory=$true, Position=0)]
  [ValidateSet("prepare", "sync", "refresh", "active")]
  [string]$Command,

  [Parameter(Position=1)]
  [string]$Path = ""
)

$ErrorActionPreference = "Stop"

$SidekickRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ToolsDir = Join-Path $SidekickRoot "tools"
$SidekickDoc = Join-Path $ToolsDir "sidekick-doc.ps1"
$RhwpInspect = Join-Path $ToolsDir "rhwp-inspect.bat"
$StartSidecar = Join-Path $SidekickRoot "Start-DocumentSidecar.ps1"
$DataDir = Join-Path $env:APPDATA "document-cursor\data"
$WorkspaceDir = Join-Path $DataDir "workspace"
$ActivePath = Join-Path $DataDir "sidekick-active.json"

function Ensure-Dir([string]$Dir) {
  if (-not (Test-Path -LiteralPath $Dir)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
  }
}

function Resolve-DocPath([string]$InputPath) {
  if ([string]::IsNullOrWhiteSpace($InputPath)) {
    if (Test-Path -LiteralPath $ActivePath) {
      $active = Get-Content -LiteralPath $ActivePath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($active.source) { return (Resolve-Path -LiteralPath $active.source).Path }
    }
    throw "Path is required, and no active Sidekick document is set."
  }
  return (Resolve-Path -LiteralPath $InputPath).Path
}

function Get-WorkspacePath([string]$SourcePath) {
  Ensure-Dir $WorkspaceDir
  return Join-Path $WorkspaceDir ([System.IO.Path]::GetFileName($SourcePath))
}

function Refresh-Sidecar {
  try {
    Invoke-WebRequest -Uri "http://127.0.0.1:4195/api/sidecar?reset=1" -UseBasicParsing -TimeoutSec 5 | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Start-SidecarIfNeeded {
  $serverOk = $false
  try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:4195" -UseBasicParsing -TimeoutSec 2
    $serverOk = [int]$response.StatusCode -lt 500
  } catch {
    $serverOk = $false
  }

  $appRunning = Get-Process -Name "Document Sidecar" -ErrorAction SilentlyContinue
  if (-not $serverOk -or -not $appRunning) {
    Start-Process -FilePath "powershell.exe" `
      -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $StartSidecar) `
      -WindowStyle Hidden | Out-Null
    for ($i = 0; $i -lt 30; $i++) {
      if (Refresh-Sidecar) { break }
      Start-Sleep -Milliseconds 500
    }
  }
}

function Write-ActiveDocument([string]$SourcePath, [string]$WorkspacePath, $Preview) {
  Ensure-Dir $DataDir
  $payload = [ordered]@{
    source = $SourcePath
    workspace = $WorkspacePath
    title = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
    updated_at = (Get-Date).ToString("o")
    preview = $Preview
  }
  $json = $payload | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($ActivePath, $json, [Text.UTF8Encoding]::new($false))
}

function Sync-ToWorkspace([string]$SourcePath) {
  $workspacePath = Get-WorkspacePath $SourcePath
  Copy-Item -LiteralPath $SourcePath -Destination $workspacePath -Force
  return $workspacePath
}

function Get-RhwpPreview([string]$SourcePath) {
  try {
    $raw = & $RhwpInspect $SourcePath --json
    $jsonLine = @($raw | Where-Object { $_ -match '^\{' } | Select-Object -First 1)
    if ($jsonLine) {
      return ($jsonLine | ConvertFrom-Json)
    }
  } catch {
    return [pscustomobject]@{ ok = $false; error = $_.Exception.Message }
  }
  return $null
}

switch ($Command) {
  "prepare" {
    $source = Resolve-DocPath $Path
    Start-SidecarIfNeeded
    & $SidekickDoc link $source | Out-Null
    $workspace = Sync-ToWorkspace $source
    $preview = Get-RhwpPreview $source
    Write-ActiveDocument $source $workspace $preview
    Refresh-Sidecar | Out-Null
    Write-Output "Prepared active document."
    Write-Output "Source:    $source"
    Write-Output "Workspace: $workspace"
    if ($preview -and $preview.pageCount) { Write-Output "Preview:   $($preview.pageCount) pages" }
  }
  "sync" {
    $source = Resolve-DocPath $Path
    $workspace = Sync-ToWorkspace $source
    $preview = Get-RhwpPreview $source
    Write-ActiveDocument $source $workspace $preview
    Refresh-Sidecar | Out-Null
    Write-Output "Synced active document."
    Write-Output "Source:    $source"
    Write-Output "Workspace: $workspace"
    if ($preview -and $preview.pageCount) { Write-Output "Preview:   $($preview.pageCount) pages" }
  }
  "refresh" {
    Start-SidecarIfNeeded
    Refresh-Sidecar | Out-Null
    Write-Output "Sidecar refreshed."
  }
  "active" {
    if (-not (Test-Path -LiteralPath $ActivePath)) {
      Write-Output "No active document."
    } else {
      Get-Content -LiteralPath $ActivePath -Raw -Encoding UTF8
    }
  }
}
