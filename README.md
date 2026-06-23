# Sidekick Releases

Public release assets and platform runtimes for the Sidekick desktop app.

## Windows

The Windows HWP/HWPX runtime is published under:

```text
windows/sidekick-for-window/0.1.0-mvp
```

This runtime is the Windows adapter for the Codex + Sidekick document workflow:

1. Start Document Sidecar on Windows.
2. Select and sync the active HWP/HWPX document.
3. Generate an `rhwp` preview summary.
4. Let Codex edit with `rhwp` first.
5. Sync the edited document back to the Sidecar workspace.

Main entry:

```bat
windows\sidekick-for-window\0.1.0-mvp\Sidekick for Window.bat help
```

Typical commands:

```bat
"Sidekick for Window.bat" start
"Sidekick for Window.bat" prepare "C:\path\document.hwp"
"Sidekick for Window.bat" active
"Sidekick for Window.bat" sync
```

## Large Installers

Large installer binaries, such as `Document.Sidecar-*-setup.exe`, should be attached to GitHub Releases instead of committed to this repository. GitHub's normal repository file limit is too small for the full Windows installer bundle.
