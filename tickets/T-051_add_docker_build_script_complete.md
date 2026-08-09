# T-051 - Add Docker build script

Status: Complete

Create `tools/build.ps1` to build the pinned tools image.

**Acceptance criteria**

- The script fails clearly when Docker Desktop is unavailable.
- The script contains no administrator-elevation command.
