# Windows Development Guide

Use this guide on the school Windows notebook.

## First Setup

```powershell
git clone https://github.com/risky-dice/sidekick-releases.git
cd sidekick-releases\windows\sidekick-for-window\0.1.0-mvp
```

Install the current Sidekick desktop app from the latest GitHub Release:

```text
https://github.com/risky-dice/sidekick-releases/releases/latest
```

Use `Sidekick-*-win-x64-setup.exe` for the normal installer. Use the portable exe only for quick checks.

## Daily Windows Work

```powershell
git pull
git checkout -b windows-runtime/<short-topic>
.\Sidekick for Window.bat help
.\Sidekick for Window.bat start
.\Sidekick for Window.bat prepare "C:\path\sample.hwpx"
.\Sidekick for Window.bat active
.\Sidekick for Window.bat sync
git status
```

Keep commits focused on `windows/sidekick-for-window/`.

## What To Validate On Windows

- HWP and HWPX path handling with Korean filenames.
- Hancom prompt behavior.
- `rhwp` preview and export behavior.
- Local vault rollback behavior.
- Sync from workspace back to Sidekick.
- No hardcoded Mac paths.

## Handoff Back To Mac Mini

Push the branch:

```powershell
git push -u origin windows-runtime/<short-topic>
```

Then the Mac mini should review, merge, and decide whether to publish a new GitHub Release.
