# Sidekick for Window

Sidekick for Window is a Windows-first document workflow helper for Codex and Korean HWP/HWPX files.

It wraps the current Document Sidecar installation, keeps local document versions in a vault, and uses `rhwp` first so simple HWP edits can happen without repeatedly opening Hancom Office automation prompts.

## What It Does

- Starts Document Sidecar on Windows.
- Selects the active document for Codex work.
- Copies the active document into the Sidecar workspace.
- Generates a lightweight `rhwp` preview summary.
- Keeps rollback versions in `document-vault`.
- Syncs each Codex/rhwp edit back to Sidecar.

## Quick Start

```bat
"C:\Users\NeoSol\Desktop\sidekick\Sidekick for Window.bat" start
"C:\Users\NeoSol\Desktop\sidekick\Sidekick for Window.bat" prepare "C:\path\document.hwp"
"C:\Users\NeoSol\Desktop\sidekick\Sidekick for Window.bat" active
```

After Codex edits the document:

```bat
"C:\Users\NeoSol\Desktop\sidekick\Sidekick for Window.bat" sync
```

## Install Desktop Shortcut

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\NeoSol\Desktop\sidekick\install-sidekick-for-window.ps1"
```

## Codex Workflow

1. Attach or mention an HWP/HWPX file in a Codex thread.
2. Run `prepare` for that file.
3. Ask Codex for document edits.
4. Codex should use `rhwp` first for search, replace, export, and verification.
5. After each edit, run `sync` so Sidecar shows the current file.

## Windows MVP Status

This is the Windows MVP wrapper around the working Sidecar/rhwp workflow. It is intentionally local-first and uses the installed Document Sidecar runtime.
