# Codex + Sidekick + rhwp fixed workflow

## Default sequence

1. User attaches a document to a Codex thread.
2. Codex runs `tools\sidekick-workflow.bat prepare "<document path>"`.
3. The workflow starts Document Sidecar, links the document into the version vault, copies the document into the Sidecar workspace, writes the active-document metadata, and refreshes Sidecar.
4. Codex edits with `rhwp` first.
5. Codex commits the changed candidate through `sidekick-doc.bat commit`.
6. Codex runs `tools\sidekick-workflow.bat sync "<document path>"` so the Sidecar workspace shows the latest file.

## Rules for Codex work

- Treat the most recently prepared document as the active Sidekick document.
- For HWP/HWPX, use `rhwp-inspect` for search, simple replace, export, and verification before trying Hancom COM automation.
- After every successful document edit, run `sidekick-workflow sync` so Sidecar and the source file stay in agreement.
- Keep rollback versions in the Sidekick vault instead of creating many Desktop copies.

## Commands

```bat
tools\sidekick-workflow.bat prepare "C:\path\document.hwp"
tools\sidekick-workflow.bat active
tools\sidekick-workflow.bat sync
tools\sidekick-workflow.bat refresh
```
