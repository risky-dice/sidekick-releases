# Sidekick rhwp-first document workflow

## Why

Hancom Office automation on school Windows laptops can show the file access prompt every time a document is opened through COM automation. That prompt is controlled by Hancom security policy, so the cleanest long-term workaround is to reduce how often Sidekick opens HWP through Hancom itself.

## Proposed default flow

1. Read HWP/HWPX with `rhwp` first.
2. Extract document info, text positions, search results, and simple replacements without launching Hancom.
3. Save every change through the Sidekick version vault before overwriting the working file.
4. Use Hancom COM only for cases `rhwp` cannot safely handle yet: visual final check, very complex table surgery, print/PDF export, or damaged files.

## Practical impact

- Search, inspection, text replacement, and many simple edits can avoid the access-permission dialog.
- Final HWP output can still be opened normally in Hancom for visual review.
- The existing vault keeps rollback copies, so overwrite mode can be used without filling the Desktop with many generated files.

## Local tool

`tools/rhwp-inspect.bat` wraps the `rhwp` runtime bundled with Document Sidecar.

Examples:

```bat
tools\rhwp-inspect.bat "C:\path\document.hwp"
tools\rhwp-inspect.bat "C:\path\document.hwp" --search "이용선"
tools\rhwp-inspect.bat "C:\path\document.hwp" --replace "이성진" --with "이용선" --out "C:\path\document_fixed.hwp"
```

## Current rule

Use `rhwp` for non-visual edits first. Fall back to HWPX XML or Hancom COM only when a task needs layout-sensitive table editing that `rhwp` cannot yet express reliably.
