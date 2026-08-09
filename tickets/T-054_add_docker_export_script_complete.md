# T-054 - Add Docker export script

Status: Complete

Create `tools/export.ps1` to create a Windows export in `exports/windows/` from the isolated container.

**Acceptance criteria**

- The output includes a Windows executable and required data files.
- The script fails clearly when export templates or export presets are missing.
