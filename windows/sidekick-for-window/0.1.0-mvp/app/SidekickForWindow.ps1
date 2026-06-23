param(
  [Parameter(Position=0)]
  [ValidateSet("start", "prepare", "sync", "active", "status", "docs", "restore", "export", "refresh", "help")]
  [string]$Command = "start",

  [Parameter(Position=1)]
  [string]$Path = "",

  [int]$Version = 0,
  [string]$ExportPath = ""
)

$ErrorActionPreference = "Stop"

$AppName = "Sidekick for Window"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Tools = Join-Path $Root "tools"
$Workflow = Join-Path $Tools "sidekick-workflow.bat"
$Doc = Join-Path $Tools "sidekick-doc.bat"
$StartSidecar = Join-Path $Root "Start-DocumentSidecar.ps1"
$DataDir = Join-Path $env:APPDATA "document-cursor\data"
$ActivePath = Join-Path $DataDir "sidekick-active.json"

function Show-Help {
  Write-Output "$AppName"
  Write-Output ""
  Write-Output "Commands:"
  Write-Output "  start                         Start Document Sidecar and refresh"
  Write-Output "  prepare <document.hwp>         Link, preview, and select active document"
  Write-Output "  sync [document.hwp]            Sync source to Sidecar workspace"
  Write-Output "  active                         Show active document metadata"
  Write-Output "  status <document.hwp>          Show vault status"
  Write-Output "  docs                           List linked documents"
  Write-Output "  restore <document.hwp> -Version N"
  Write-Output "  export <document.hwp> -ExportPath <folder>"
  Write-Output "  refresh                        Refresh Sidecar"
}

function Require-Path([string]$Value, [string]$Message) {
  if ([string]::IsNullOrWhiteSpace($Value)) { throw $Message }
  return $Value
}

function Get-ActiveSource {
  if (-not (Test-Path -LiteralPath $ActivePath)) {
    throw "No active document. Run: `"Sidekick for Window.bat`" prepare <document>"
  }
  $active = Get-Content -LiteralPath $ActivePath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $active.source) { throw "Active document metadata is missing source." }
  return [string]$active.source
}

switch ($Command) {
  "help" {
    Show-Help
  }
  "start" {
    Start-Process -FilePath "powershell.exe" `
      -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $StartSidecar) `
      -WindowStyle Hidden | Out-Null
    & $Workflow refresh
  }
  "prepare" {
    & $Workflow prepare (Require-Path $Path "Document path is required.")
  }
  "sync" {
    if ([string]::IsNullOrWhiteSpace($Path)) {
      & $Workflow sync
    } else {
      & $Workflow sync $Path
    }
  }
  "active" {
    & $Workflow active
  }
  "status" {
    $target = if ([string]::IsNullOrWhiteSpace($Path)) { Get-ActiveSource } else { $Path }
    & $Doc status $target
  }
  "docs" {
    & $Doc docs
  }
  "restore" {
    $target = Require-Path $Path "Document path is required."
    if ($Version -le 0) { throw "Version is required. Example: -Version 3" }
    & $Doc restore $target -Version $Version
    & $Workflow sync $target
  }
  "export" {
    $target = Require-Path $Path "Document path is required."
    & $Doc export $target -ExportPath $ExportPath -Label "Sidekick for Window export" -Summary "Exported from Sidekick for Window"
  }
  "refresh" {
    & $Workflow refresh
  }
}
