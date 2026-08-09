# UXR-09B - Export and package the refreshed combat closed-beta candidate

Status: Open

**Goal**

Produce a new Windows closed-beta candidate containing the validated COMBAT-01 survivability changes, package its executable artifacts in a fresh ZIP, and prepare the validated source commits for delivery to `origin`.

**Ownership boundary**

- `exports/windows/UrbanDrivePrototype.exe`
- `exports/windows/UrbanDrivePrototype.pck`
- `exports/closed_beta.zip`
- `reports/uxr-09b-combat-closed-beta-2026-08-09.*`
- This UXR-09B record in `TICKETS.md`
- Post-closure delivery may push the current `master` branch to its configured `origin`; it must not rewrite remote history.

**Non-goals**

- Do not modify gameplay, scenes, resources, tests, build tooling, export presets, or repository rules.
- Do not mark UXR-08 or UXR-09 complete, claim final release readiness, suppress the eight authorized UXR-05B1 locomotion failures, or resolve unrelated pending tickets.
- Do not add ignored binary export artifacts to Git.

**Acceptance criteria**

- The process-scoped command `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1` exits 0 and produces fresh non-empty Windows x86-64 EXE and PCK artifacts from a source tree containing commit `cce433d`.
- `exports/closed_beta.zip` is rebuilt after the export and contains exactly the refreshed `UrbanDrivePrototype.exe` and `UrbanDrivePrototype.pck` entries, both non-empty.
- SHA-256 hashes and byte sizes are recorded for the EXE, PCK, and ZIP together with the exact source commit.
- A bounded hidden native Windows launch remains alive for 12 seconds without an immediate crash and is then stopped by its exact process ID.
- The candidate manifest discloses the eight authorized UXR-05B1 locomotion failures, the pre-existing shutdown diagnostics, and that UXR-08/UXR-09 plus unrelated visual/animation tickets remain open.
- The dedicated UXR-09B commit contains only its completed `TICKETS.md` record; ignored exports/reports remain local delivery artifacts. After closure, a normal non-force push updates `origin/master` to the local validated HEAD.

**Required tests**

- Run the repository Windows export pipeline with the required process-scoped execution-policy bypass.
- Verify artifact existence, non-zero sizes, timestamps, SHA-256 hashes, and ZIP entry names/sizes.
- Perform the bounded native Windows startup smoke by exact PID.
- Run `git diff --check`, verify tracked scope, create the dedicated UXR-09B commit, and verify local branch ancestry before the post-closure push.

**Dependencies**

- COMBAT-01 must be completed and committed.
- UXR-08A remains the authorized playable-candidate gate. The user explicitly authorizes this refreshed closed-beta candidate while UXR-08 and UXR-09 remain open.

**Validation evidence**

- Pending.
