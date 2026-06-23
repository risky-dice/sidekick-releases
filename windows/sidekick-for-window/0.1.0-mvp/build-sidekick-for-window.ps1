$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppName = "Sidekick for Window"
$Version = "0.1.0-mvp"
$DistRoot = Join-Path $Root "dist"
$PackageDir = Join-Path $DistRoot "$AppName-$Version"
$ZipPath = Join-Path $DistRoot "$AppName-$Version.zip"

if (Test-Path -LiteralPath $PackageDir) {
  Remove-Item -LiteralPath $PackageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $Root "Sidekick for Window.bat") -Destination $PackageDir -Force
Copy-Item -LiteralPath (Join-Path $Root "Start-DocumentSidecar.ps1") -Destination $PackageDir -Force
Copy-Item -LiteralPath (Join-Path $Root "install-sidekick-for-window.ps1") -Destination $PackageDir -Force
Copy-Item -LiteralPath (Join-Path $Root "README.md") -Destination $PackageDir -Force
Copy-Item -LiteralPath (Join-Path $Root "RELEASE_NOTES.md") -Destination $PackageDir -Force

foreach ($dir in @("app", "tools", "specs", "rules")) {
  $source = Join-Path $Root $dir
  if (Test-Path -LiteralPath $source) {
    Copy-Item -LiteralPath $source -Destination (Join-Path $PackageDir $dir) -Recurse -Force
  }
}

$setup = Join-Path $Root "Document.Sidecar-0.1.6-x64-setup.exe"
if (Test-Path -LiteralPath $setup) {
  Copy-Item -LiteralPath $setup -Destination $PackageDir -Force
}

$manifest = [ordered]@{
  name = $AppName
  version = $Version
  built_at = (Get-Date).ToString("o")
  platform = "windows"
  entry = "Sidekick for Window.bat"
  includes_document_sidecar_setup = (Test-Path -LiteralPath $setup)
}
$manifestJson = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $PackageDir "package-manifest.json"), $manifestJson, [Text.UTF8Encoding]::new($false))

if (Test-Path -LiteralPath $ZipPath) {
  Remove-Item -LiteralPath $ZipPath -Force
}
Compress-Archive -LiteralPath $PackageDir -DestinationPath $ZipPath -Force

Write-Output "Built $AppName $Version"
Write-Output "Package: $PackageDir"
Write-Output "Zip:     $ZipPath"
