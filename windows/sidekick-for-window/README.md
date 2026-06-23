# Sidekick for Window

This folder contains the Windows runtime adapter for the Sidekick desktop app.

## Current Version

```text
0.1.0-mvp
```

## Integration Contract

The macOS-built Sidekick Windows shell can call the Windows runtime through these commands:

```bat
Sidekick for Window.bat start
Sidekick for Window.bat prepare "C:\path\document.hwp"
Sidekick for Window.bat active
Sidekick for Window.bat sync
Sidekick for Window.bat status "C:\path\document.hwp"
```

## Runtime Responsibilities

- Launch or refresh Document Sidecar.
- Link the active document into the local vault.
- Copy the active file into the Sidecar workspace.
- Generate `rhwp` preview metadata.
- Prefer `rhwp` for simple HWP/HWPX search, replace, export, and verification.
- Keep Hancom COM automation as a fallback only.

## Packaging

The runtime scripts are stored in git. Large installer binaries should be uploaded as GitHub Release assets.
