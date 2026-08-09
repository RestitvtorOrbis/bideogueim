# UXR-09 - Export and smoke-test the Windows release

Status: Open

**Goal**

Produce the final Windows x86-64 release executable and its required PCK after every implementation and validation gate passes.

**Ownership boundary**

- `exports/windows/**`
- A release manifest under `reports/**`

**Non-goals**

- Do not modify source code, scenes, resources, tests, export presets, or build tooling during this ticket.
- Do not export before UXR-08 is completed and validated.

**Acceptance criteria**

- `./tools/export.ps1` completes successfully using the Godot 4.7.1 Windows Desktop release preset.
- `exports/windows/UrbanDrivePrototype.exe` and `exports/windows/UrbanDrivePrototype.pck` both exist and are non-empty.
- The executable launches successfully on Windows x86-64 and opens the configured Main scene without missing resources or import errors.
- A release smoke test confirms the camera, nearby vehicle, immediate E entry, hostile grace period, player model, and NPC models in the exported build.
- The release manifest records the build date, Godot version, file sizes, and SHA-256 values for both artifacts.

**Required tests**

- Run `./tools/export.ps1` and retain its exit result.
- Verify both artifacts and their hashes.
- Launch `UrbanDrivePrototype.exe` on Windows and complete the documented release smoke test.

**Dependencies**

- UXR-08 must be completed and validated.

**Validation evidence**

- Pending.
