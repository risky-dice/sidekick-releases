param(
  [Parameter(Mandatory=$true, Position=0)]
  [ValidateSet("link", "snapshot", "commit", "list", "restore", "cleanup", "status", "docs", "export", "protect", "unprotect", "meta")]
  [string]$Command,

  [Parameter(Position=1)]
  [string]$Path,

  [string]$Candidate,
  [string]$Label = "",
  [string]$Summary = "",
  [int]$Version = 0,
  [switch]$Protect,
  [string]$ExportPath = "",
  [int]$KeepRecent = 10,
  [int]$MaxMegabytes = 300
)

$ErrorActionPreference = "Stop"

$SidekickRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$VaultRoot = Join-Path $SidekickRoot "document-vault"
$IndexPath = Join-Path $VaultRoot "index.json"

function Ensure-Dir([string]$Dir) {
  if (-not (Test-Path -LiteralPath $Dir)) {
    New-Item -ItemType Directory -Path $Dir | Out-Null
  }
}

function Get-AbsolutePath([string]$InputPath) {
  if ([string]::IsNullOrWhiteSpace($InputPath)) {
    throw "Path is required."
  }
  return (Resolve-Path -LiteralPath $InputPath).Path
}

function Get-DocumentId([string]$AbsolutePath) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($AbsolutePath.ToLowerInvariant())
    $hash = $sha.ComputeHash($bytes)
    return -join ($hash | ForEach-Object { $_.ToString("x2") })
  } finally {
    $sha.Dispose()
  }
}

function Read-JsonFile([string]$JsonPath, $DefaultValue) {
  if (-not (Test-Path -LiteralPath $JsonPath)) {
    return $DefaultValue
  }
  $raw = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return $DefaultValue
  }
  return $raw | ConvertFrom-Json
}

function Write-JsonFile([string]$JsonPath, $Value) {
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($JsonPath, $json, [Text.UTF8Encoding]::new($false))
}

function Get-ManifestPath([string]$DocumentId) {
  return Join-Path (Join-Path $VaultRoot $DocumentId) "manifest.json"
}

function Get-HistoryPath([string]$DocumentId) {
  return Join-Path (Join-Path $VaultRoot $DocumentId) "history.md"
}

function Load-ManifestByPath([string]$InputPath) {
  $absolute = Get-AbsolutePath $InputPath
  $documentId = Get-DocumentId $absolute
  $manifestPath = Get-ManifestPath $documentId
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Document is not linked yet. Run: .\tools\sidekick-doc.ps1 link `"$absolute`""
  }
  return Read-JsonFile $manifestPath $null
}

function Save-Manifest($Manifest) {
  $manifestPath = Get-ManifestPath $Manifest.id
  Write-JsonFile $manifestPath $Manifest
}

function Update-Index($Manifest) {
  Ensure-Dir $VaultRoot
  $index = @()
  if (Test-Path -LiteralPath $IndexPath) {
    $index = @(Read-JsonFile $IndexPath @())
  }
  $index = @($index | Where-Object { $_.id -ne $Manifest.id })
  $index += [pscustomobject]@{
    id = $Manifest.id
    title = $Manifest.title
    local_path = $Manifest.local_path
    vault_path = $Manifest.vault_path
    current_version = $Manifest.current_version
    status = $Manifest.status
    updated_at = (Get-Date).ToString("o")
  }
  Write-JsonFile $IndexPath $index
}

function Append-History($Manifest, [string]$Title, [string]$Body) {
  $historyPath = Get-HistoryPath $Manifest.id
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $entry = @"

## $Title - $stamp

$Body
"@
  Add-Content -LiteralPath $historyPath -Value $entry -Encoding UTF8
}

function Get-VersionFileName($Manifest, [int]$VersionNo, [string]$LabelText, [string]$Ext) {
  $safe = if ([string]::IsNullOrWhiteSpace($LabelText)) { "snapshot" } else { $LabelText }
  $safe = $safe -replace '[\\/:*?"<>|]', "_"
  $safe = $safe -replace '\s+', "_"
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  return ("v{0:000}_{1}_{2}{3}" -f $VersionNo, $safe, $stamp, $Ext)
}

function New-Snapshot($Manifest, [string]$LabelText, [string]$SummaryText, [bool]$Protected) {
  $sourcePath = $Manifest.local_path
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source document not found: $sourcePath"
  }

  $docDir = Join-Path $VaultRoot $Manifest.id
  $versionsDir = Join-Path $docDir "versions"
  Ensure-Dir $versionsDir

  $nextVersion = [int]$Manifest.current_version + 1
  $ext = [System.IO.Path]::GetExtension($sourcePath)
  $fileName = Get-VersionFileName $Manifest $nextVersion $LabelText $ext
  $dest = Join-Path $versionsDir $fileName
  Copy-Item -LiteralPath $sourcePath -Destination $dest -Force

  $item = Get-Item -LiteralPath $dest
  $versionRecord = [ordered]@{
    version_no = $nextVersion
    label = $(if ([string]::IsNullOrWhiteSpace($LabelText)) { "snapshot" } else { $LabelText })
    summary = $SummaryText
    path = $dest
    protected = [bool]$Protected
    export = $false
    size_bytes = $item.Length
    created_at = (Get-Date).ToString("o")
  }

  $versions = @($Manifest.versions)
  $versions += [pscustomobject]$versionRecord
  $Manifest.versions = $versions
  $Manifest.current_version = $nextVersion
  $Manifest.updated_at = (Get-Date).ToString("o")
  Save-Manifest $Manifest
  Update-Index $Manifest

  Append-History $Manifest ("v{0:000} {1}" -f $nextVersion, $versionRecord.label) $SummaryText
  return [pscustomobject]$versionRecord
}

function Link-Document([string]$InputPath) {
  $absolute = Get-AbsolutePath $InputPath
  if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
    throw "File not found: $absolute"
  }

  Ensure-Dir $VaultRoot
  $documentId = Get-DocumentId $absolute
  $docDir = Join-Path $VaultRoot $documentId
  $originalDir = Join-Path $docDir "original"
  $currentDir = Join-Path $docDir "current"
  $versionsDir = Join-Path $docDir "versions"
  $exportsDir = Join-Path $docDir "exports"
  Ensure-Dir $originalDir
  Ensure-Dir $currentDir
  Ensure-Dir $versionsDir
  Ensure-Dir $exportsDir

  $name = [System.IO.Path]::GetFileName($absolute)
  $ext = [System.IO.Path]::GetExtension($absolute)
  $originalPath = Join-Path $originalDir ("original" + $ext)
  $currentPath = Join-Path $currentDir ("current" + $ext)
  if (-not (Test-Path -LiteralPath $originalPath)) {
    Copy-Item -LiteralPath $absolute -Destination $originalPath -Force
  }
  Copy-Item -LiteralPath $absolute -Destination $currentPath -Force

  $manifestPath = Get-ManifestPath $documentId
  if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Read-JsonFile $manifestPath $null
    $manifest.title = [System.IO.Path]::GetFileNameWithoutExtension($absolute)
    $manifest.original_file_name = $name
    $manifest.local_path = $absolute
    $manifest.vault_path = $docDir
    $manifest.current_path = $currentPath
    $manifest.file_ext = $ext
    $manifest.status = "active"
    $manifest.updated_at = (Get-Date).ToString("o")
    if (-not $manifest.versions) {
      $manifest | Add-Member -NotePropertyName versions -NotePropertyValue @() -Force
    }
  } else {
    $manifest = [pscustomobject][ordered]@{
      id = $documentId
      title = [System.IO.Path]::GetFileNameWithoutExtension($absolute)
      original_file_name = $name
      local_path = $absolute
      vault_path = $docDir
      current_path = $currentPath
      file_ext = $ext
      status = "active"
      current_version = 0
      last_summary = "linked"
      created_at = (Get-Date).ToString("o")
      updated_at = (Get-Date).ToString("o")
      versions = @()
    }
  }

  Save-Manifest $manifest

  $historyPath = Get-HistoryPath $documentId
  if (-not (Test-Path -LiteralPath $historyPath)) {
    $history = @"
# $($manifest.title)

## Current

- Source: $absolute
- Vault: $docDir
- Status: active
"@
    [System.IO.File]::WriteAllText($historyPath, $history, [Text.UTF8Encoding]::new($false))
  } else {
    Append-History $manifest "link" "Document path refreshed."
  }

  Update-Index $manifest

  Write-Output "Linked: $absolute"
  Write-Output "Vault:  $docDir"
}

function Commit-Document([string]$InputPath, [string]$CandidatePath, [string]$LabelText, [string]$SummaryText, [bool]$Protected) {
  if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
    throw "Candidate is required for commit."
  }
  $manifest = Load-ManifestByPath $InputPath
  $candidateAbsolute = Get-AbsolutePath $CandidatePath
  if (-not (Test-Path -LiteralPath $candidateAbsolute -PathType Leaf)) {
    throw "Candidate file not found: $candidateAbsolute"
  }

  $snapshotLabel = if ([string]::IsNullOrWhiteSpace($LabelText)) { "before_commit" } else { "before_" + $LabelText }
  $snapshot = New-Snapshot $manifest $snapshotLabel $SummaryText $Protected

  Copy-Item -LiteralPath $candidateAbsolute -Destination $manifest.local_path -Force
  Copy-Item -LiteralPath $candidateAbsolute -Destination $manifest.current_path -Force
  $manifest.last_summary = $SummaryText
  $manifest.updated_at = (Get-Date).ToString("o")
  Save-Manifest $manifest
  Update-Index $manifest
  Append-History $manifest "commit" ("Overwrote source after snapshot v{0:000}.`n`n{1}" -f $snapshot.version_no, $SummaryText)

  Write-Output ("Committed. Previous version saved as v{0:000}" -f $snapshot.version_no)
  Write-Output "Source overwritten: $($manifest.local_path)"
}

function List-Versions([string]$InputPath) {
  $manifest = Load-ManifestByPath $InputPath
  if (-not $manifest.versions -or @($manifest.versions).Count -eq 0) {
    Write-Output "No versions yet."
    return
  }
  $manifest.versions |
    Sort-Object version_no |
    Select-Object version_no,label,protected,size_bytes,created_at,path |
    Format-Table -AutoSize
}

function Show-Status([string]$InputPath) {
  $manifest = Load-ManifestByPath $InputPath
  $versions = @($manifest.versions)
  $size = 0L
  foreach ($v in $versions) {
    if (Test-Path -LiteralPath $v.path) {
      $size += (Get-Item -LiteralPath $v.path).Length
    }
  }
  [pscustomobject]@{
    title = $manifest.title
    source = $manifest.local_path
    vault = $manifest.vault_path
    current_version = $manifest.current_version
    version_count = $versions.Count
    vault_versions_mb = [math]::Round($size / 1MB, 2)
    updated_at = $manifest.updated_at
  } | Format-List
}

function List-Documents {
  $manifests = @()
  if (Test-Path -LiteralPath $VaultRoot) {
    $manifests = @(Get-ChildItem -LiteralPath $VaultRoot -Directory -ErrorAction SilentlyContinue |
      ForEach-Object {
        $manifestPath = Join-Path $_.FullName "manifest.json"
        if (Test-Path -LiteralPath $manifestPath) {
          Read-JsonFile $manifestPath $null
        }
      } |
      Where-Object { $_ -ne $null })
  }

  if ($manifests.Count -eq 0) {
    Write-Output "No linked documents."
    return
  }

  $index = @($manifests | ForEach-Object {
    [pscustomobject]@{
      id = $_.id
      title = $_.title
      local_path = $_.local_path
      vault_path = $_.vault_path
      current_version = $_.current_version
      status = $_.status
      updated_at = $_.updated_at
    }
  })
  Write-JsonFile $IndexPath $index

  $index |
    Sort-Object updated_at -Descending |
    Select-Object title,current_version,status,updated_at,local_path |
    Format-Table -AutoSize
}

function Restore-Version([string]$InputPath, [int]$VersionNo) {
  if ($VersionNo -le 0) {
    throw "Version must be greater than 0."
  }
  $manifest = Load-ManifestByPath $InputPath
  $record = @($manifest.versions | Where-Object { [int]$_.version_no -eq $VersionNo }) | Select-Object -First 1
  if (-not $record) {
    throw "Version not found: $VersionNo"
  }
  if (-not (Test-Path -LiteralPath $record.path)) {
    throw "Version file is missing: $($record.path)"
  }
  New-Snapshot $manifest ("before_restore_v{0:000}" -f $VersionNo) "Snapshot before restore." $true | Out-Null
  Copy-Item -LiteralPath $record.path -Destination $manifest.local_path -Force
  Copy-Item -LiteralPath $record.path -Destination $manifest.current_path -Force
  $manifest.last_summary = ("Restored v{0:000}" -f $VersionNo)
  $manifest.updated_at = (Get-Date).ToString("o")
  Save-Manifest $manifest
  Append-History $manifest ("restore v{0:000}" -f $VersionNo) "Source overwritten from selected version."
  Write-Output ("Restored v{0:000}: {1}" -f $VersionNo, $manifest.local_path)
}

function Set-VersionProtection([string]$InputPath, [int]$VersionNo, [bool]$Protected) {
  if ($VersionNo -le 0) {
    throw "Version must be greater than 0."
  }
  $manifest = Load-ManifestByPath $InputPath
  $changed = $false
  foreach ($v in @($manifest.versions)) {
    if ([int]$v.version_no -eq $VersionNo) {
      $v.protected = $Protected
      $changed = $true
      break
    }
  }
  if (-not $changed) {
    throw "Version not found: $VersionNo"
  }
  $manifest.updated_at = (Get-Date).ToString("o")
  Save-Manifest $manifest
  Update-Index $manifest
  $verb = if ($Protected) { "Protected" } else { "Unprotected" }
  Append-History $manifest ($verb.ToLowerInvariant() + (" v{0:000}" -f $VersionNo)) "$verb selected version."
  Write-Output ("{0} v{1:000}" -f $verb, $VersionNo)
}

function Export-Current([string]$InputPath, [string]$TargetPath, [string]$LabelText, [string]$SummaryText) {
  $manifest = Load-ManifestByPath $InputPath
  if (-not (Test-Path -LiteralPath $manifest.local_path)) {
    throw "Source document not found: $($manifest.local_path)"
  }

  $exportsDir = Join-Path (Join-Path $VaultRoot $manifest.id) "exports"
  Ensure-Dir $exportsDir

  $ext = [System.IO.Path]::GetExtension($manifest.local_path)
  $labelText = if ([string]::IsNullOrWhiteSpace($LabelText)) { "export" } else { $LabelText }
  $safe = $labelText -replace '[\\/:*?"<>|]', "_"
  $safe = $safe -replace '\s+', "_"
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $exportName = ("export_{0}_{1}{2}" -f $safe, $stamp, $ext)
  $vaultExport = Join-Path $exportsDir $exportName
  Copy-Item -LiteralPath $manifest.local_path -Destination $vaultExport -Force

  if (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
    $targetFull = $TargetPath
    if (Test-Path -LiteralPath $TargetPath -PathType Container) {
      $targetFull = Join-Path $TargetPath $exportName
    }
    Copy-Item -LiteralPath $manifest.local_path -Destination $targetFull -Force
  }

  $nextVersion = [int]$manifest.current_version + 1
  $item = Get-Item -LiteralPath $vaultExport
  $versions = @($manifest.versions)
  $versions += [pscustomobject][ordered]@{
    version_no = $nextVersion
    label = $labelText
    summary = $SummaryText
    path = $vaultExport
    protected = $true
    export = $true
    size_bytes = $item.Length
    created_at = (Get-Date).ToString("o")
  }
  $manifest.versions = $versions
  $manifest.current_version = $nextVersion
  $manifest.status = "submitted"
  $manifest.last_summary = $SummaryText
  $manifest.updated_at = (Get-Date).ToString("o")
  Save-Manifest $manifest
  Update-Index $manifest
  Append-History $manifest ("export v{0:000} {1}" -f $nextVersion, $labelText) $SummaryText
  Write-Output ("Exported: {0}" -f $vaultExport)
}

function Export-Metadata([string]$InputPath, [string]$TargetPath) {
  $manifest = Load-ManifestByPath $InputPath
  $target = if ([string]::IsNullOrWhiteSpace($TargetPath)) {
    Join-Path $manifest.vault_path "supabase-metadata.json"
  } else {
    $TargetPath
  }
  $metadata = [ordered]@{
    document = [ordered]@{
      id = $manifest.id
      title = $manifest.title
      original_file_name = $manifest.original_file_name
      local_path = $manifest.local_path
      vault_path = $manifest.vault_path
      file_ext = $manifest.file_ext
      status = $manifest.status
      current_version = $manifest.current_version
      last_summary = $manifest.last_summary
      created_at = $manifest.created_at
      updated_at = $manifest.updated_at
    }
    versions = @($manifest.versions | ForEach-Object {
      [ordered]@{
        version_no = $_.version_no
        label = $_.label
        change_summary = $_.summary
        local_version_path = $_.path
        is_protected = $_.protected
        is_export = $_.export
        file_size_bytes = $_.size_bytes
        created_at = $_.created_at
      }
    })
  }
  Write-JsonFile $target ([pscustomobject]$metadata)
  Write-Output "Metadata exported: $target"
}

function Cleanup-Versions([string]$InputPath, [int]$RecentCount, [int]$MaxMb) {
  $manifest = Load-ManifestByPath $InputPath
  $versions = @($manifest.versions | Sort-Object version_no)

  $keepNumbers = New-Object "System.Collections.Generic.HashSet[int]"
  foreach ($v in ($versions | Select-Object -Last $RecentCount)) {
    [void]$keepNumbers.Add([int]$v.version_no)
  }
  foreach ($v in $versions) {
    if ($v.protected) {
      [void]$keepNumbers.Add([int]$v.version_no)
    }
  }

  $remaining = @()
  $deleted = @()
  foreach ($v in $versions) {
    if ($keepNumbers.Contains([int]$v.version_no)) {
      $remaining += $v
      continue
    }
    if (Test-Path -LiteralPath $v.path) {
      Remove-Item -LiteralPath $v.path -Force
    }
    $deleted += $v
  }

  $maxBytes = [int64]$MaxMb * 1MB
  while ($true) {
    $total = 0L
    foreach ($v in $remaining) {
      if (Test-Path -LiteralPath $v.path) {
        $total += (Get-Item -LiteralPath $v.path).Length
      }
    }
    if ($total -le $maxBytes) {
      break
    }
    $victim = @($remaining | Where-Object { -not $_.protected -and -not $_.export } | Sort-Object version_no | Select-Object -First 1)
    if (-not $victim) {
      break
    }
    if (Test-Path -LiteralPath $victim.path) {
      Remove-Item -LiteralPath $victim.path -Force
    }
    $remaining = @($remaining | Where-Object { [int]$_.version_no -ne [int]$victim.version_no })
    $deleted += $victim
  }

  $manifest.versions = $remaining
  $manifest.updated_at = (Get-Date).ToString("o")
  Save-Manifest $manifest
  Update-Index $manifest
  Append-History $manifest "cleanup" ("Deleted {0} old automatic versions. KeepRecent={1}, MaxMegabytes={2}." -f $deleted.Count, $RecentCount, $MaxMb)
  Write-Output ("Deleted versions: {0}" -f $deleted.Count)
}

Ensure-Dir $VaultRoot

switch ($Command) {
  "link" {
    Link-Document $Path
  }
  "snapshot" {
    $manifest = Load-ManifestByPath $Path
    $labelText = if ([string]::IsNullOrWhiteSpace($Label)) { "manual_snapshot" } else { $Label }
    $snapshot = New-Snapshot $manifest $labelText $Summary ([bool]$Protect)
    Write-Output ("Snapshot created: v{0:000}" -f $snapshot.version_no)
    Write-Output $snapshot.path
  }
  "commit" {
    Commit-Document $Path $Candidate $Label $Summary ([bool]$Protect)
  }
  "list" {
    List-Versions $Path
  }
  "restore" {
    Restore-Version $Path $Version
  }
  "cleanup" {
    Cleanup-Versions $Path $KeepRecent $MaxMegabytes
  }
  "status" {
    Show-Status $Path
  }
  "docs" {
    List-Documents
  }
  "export" {
    Export-Current $Path $ExportPath $Label $Summary
  }
  "protect" {
    Set-VersionProtection $Path $Version $true
  }
  "unprotect" {
    Set-VersionProtection $Path $Version $false
  }
  "meta" {
    Export-Metadata $Path $ExportPath
  }
}
