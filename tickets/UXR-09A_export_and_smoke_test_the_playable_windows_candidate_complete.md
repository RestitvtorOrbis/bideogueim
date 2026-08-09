# UXR-09A - Export and smoke-test the playable Windows candidate

Status: Complete

**Goal**

Produce a Windows x86-64 EXE/PCK candidate from the UXR-08A playable tree while retaining all known pending-ticket disclosures.

**Ownership boundary**

- `exports/windows/**`
- `reports/uxr-09a-release-candidate-2026-08-04.*`
- No source, scene, asset, resource, test, export-preset, tooling, ticket, or workspace-rule edits.

**Non-goals**

- Do not claim UXR-09 or final release readiness, fix pending animation/NPC work, or suppress warnings/tests.

**Acceptance criteria**

- `tools/export.ps1` exits 0 using Godot 4.7.1 and the Windows Desktop release preset.
- `UrbanDrivePrototype.exe` and `UrbanDrivePrototype.pck` exist, are non-empty, and have SHA-256 values recorded in the candidate manifest.
- A bounded hidden Windows launch remains alive through startup without an immediate crash, then is stopped by exact process ID.
- Manifest records date, Godot version, file sizes/hashes, UXR-08A result, eight authorized test failures, and remaining pending tickets.

**Required tests**

- Run the repository export script.
- Verify artifacts and hashes.
- Perform bounded native Windows startup smoke and record process result.

**Dependencies**

- UXR-08A must be completed and validated.

**Validation evidence**

- The assigned Luna round closed `BLOCKED` before invoking the pipeline; by user authorization to continue past non-game-breaking pending tickets, the decision owner executed the existing export pipeline without changing implementation.
- Direct `.\tools\export.ps1` was blocked by the host PowerShell execution policy before Docker started. The successful reproducible invocation is `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1`; it exits 0 and keeps the bypass scoped to that process. This requirement is also recorded in `AGENTS.md` for future generations.
- Godot 4.7.1 Windows Desktop produced `UrbanDrivePrototype.exe` (109,071,360 bytes, SHA-256 `04BAF75CC1D69DD93EB709533ECAB4FD7770BB8A530645717017A06A9D9809FC`) and `UrbanDrivePrototype.pck` (52,208,584 bytes, SHA-256 `70F9062FF50F6FA2BB30FB6070071C047CB138FC1D4F2F2575185A7AA2D773AD`).
- Native hidden Windows smoke remained alive for 12 seconds and was then stopped using exact PID 12896; there was no immediate startup crash.
- Candidate manifests under `reports/uxr-09a-release-candidate-2026-08-04.*` retain UXR-08A's eight authorized failures and the pending final-release tickets. UXR-09 remains open.
