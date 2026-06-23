# Sidekick for Window

This folder contains the Windows runtime adapter for the Sidekick desktop app.

## Development Station

Use the school Windows notebook for this folder. That machine is the source of truth for:

- Hancom Office prompts and permissions.
- HWP/HWPX file-open behavior.
- PowerShell 5.1+ compatibility.
- Real school network/user-profile paths.
- Smoke tests against actual work documents.

Use the Mac mini/Catleaf checkout for the main Electron/Next app and release orchestration.

## Current Version

```text
0.1.0-mvp
```

Compatible Sidekick desktop baseline:

```text
>=0.1.17
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

The stable command contract is documented in:

```text
CONTRACT.md
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

## Recommended Branch Flow

On the Windows notebook:

```powershell
git checkout -b windows-runtime/<short-topic>
```

Change only files under `windows/sidekick-for-window/` unless the contract explicitly needs a Mac-side app change. Push that branch and let the Mac mini merge/release it after review.
