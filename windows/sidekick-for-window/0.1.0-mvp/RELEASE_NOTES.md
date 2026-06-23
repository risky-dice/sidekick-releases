# Sidekick for Window 0.1.0-mvp

## Included

- Windows launcher: `Sidekick for Window.bat`
- PowerShell app entry: `app/SidekickForWindow.ps1`
- Document workflow: `tools/sidekick-workflow.ps1`
- Local version vault tooling: `tools/sidekick-doc.ps1`
- rhwp inspection/edit helper: `tools/rhwp-inspect.mjs`
- Hancom access prompt helper: `tools/hwp-allow-all-watcher.ps1`
- Desktop shortcut installer: `install-sidekick-for-window.ps1`

## Verified

- `prepare` links and selects an HWP document.
- `active` reports selected document metadata.
- `sync` updates the Sidecar workspace.
- `rhwp` reads the active HWP and reports 7 preview pages on the test document.

## Intended Workflow

Codex receives a document, Sidekick for Window prepares it for Sidecar preview, Codex edits through `rhwp`, and Sidekick syncs the modified file back into the Sidecar workspace.
