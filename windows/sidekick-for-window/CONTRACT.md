# Sidekick for Window Contract

This contract keeps the Mac mini Sidekick app and the school Windows runtime from drifting apart.

## Roles

- Mac mini/Catleaf owns the main Sidekick app, version bumps, release notes, GitHub Release uploads, and update manifests.
- School Windows notebook owns this Windows runtime, Hancom/HWP/HWPX behavior, PowerShell compatibility, and real-device smoke tests.

## Current Baseline

- Sidekick desktop app: `0.1.17`
- Windows runtime adapter: `0.1.0-mvp`
- Release repository: `risky-dice/sidekick-releases`
- Runtime root: `windows/sidekick-for-window/0.1.0-mvp`

## Commands

The Mac-side app and human operator may rely on these commands staying stable:

```bat
"Sidekick for Window.bat" help
"Sidekick for Window.bat" start
"Sidekick for Window.bat" prepare "C:\path\document.hwp"
"Sidekick for Window.bat" active
"Sidekick for Window.bat" sync
"Sidekick for Window.bat" status "C:\path\document.hwp"
```

## Command Meaning

| Command | Responsibility |
| --- | --- |
| `help` | Print available commands and local paths. |
| `start` | Start or refresh the local Sidekick/Document Sidecar runtime. |
| `prepare <file>` | Register a target HWP/HWPX file, copy it into the workspace, and create preview metadata when possible. |
| `active` | Print the currently active document and workspace state. |
| `sync` | Copy the latest edited workspace document back through the Windows runtime flow. |
| `status <file>` | Print local state for a target document without mutating it. |

## Output Rules

- Human-readable output is allowed.
- If a command emits JSON, it should include `ok`, `command`, and either `result` or `error`.
- Do not print secrets, access tokens, private drive credentials, or full unrelated user directories.
- Error messages should say what failed and the next local action, not just a stack trace.

## Compatibility Rules

- Keep PowerShell syntax compatible with Windows PowerShell 5.1 unless the README explicitly raises the requirement.
- Prefer local-first file operations.
- Treat Hancom COM automation as a fallback; prefer `rhwp` for inspect/search/replace/export where it works.
- Large installers belong on GitHub Releases, not in git.

## Smoke Test Before Pushing

On the school Windows notebook, run:

```powershell
.\Sidekick for Window.bat help
.\Sidekick for Window.bat start
.\Sidekick for Window.bat prepare "C:\path\sample.hwpx"
.\Sidekick for Window.bat active
.\Sidekick for Window.bat sync
```

Record the Windows version, Hancom version, sample extension, and pass/fail in the branch or release notes.
