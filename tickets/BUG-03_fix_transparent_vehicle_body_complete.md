# BUG-03 — Fix transparent vehicle body

## Goal

Make the imported Ignition Labs vehicle body render opaque while retaining intentionally transparent glass, then regenerate the Windows beta artifacts.

## Evidence and likely root cause

- User-visible reproduction: the newly imported car body renders transparent.
- `Lamborghini_Aventador.mtl` defines the body with contradictory Wavefront opacity fields: `d 1.0000` (opaque dissolve) and `Tr 1.0000` (fully transparent).
- The glass material likewise uses both fields, currently as `d 0.0600` and `Tr 0.0600`; the two conventions are inverse and should not be emitted together.
- Godot's imported material must be checked directly to prevent recurrence.

## Ownership boundary

- `assets/vehicles/ignition_labs_car/Lamborghini_Aventador.mtl`
- `tests/test_system_contracts.gd`
- `ASSET_MANIFEST.md`
- This ticket file

## Implementation

- Remove the ambiguous `Tr` rows and retain the authoritative `d` values: body `d 1.0000`, glass `d 0.0600`.
- Add a minimal contract asserting that the imported body surface is opaque and the glass surface remains transparent.
- Update the retained MTL size/hash and modification notes in `ASSET_MANIFEST.md`.

## Non-goals

- Do not alter OBJ geometry, textures, vehicle transform, physics, collision, camera, controls, or other materials.

## Acceptance criteria

- Imported body material has transparency disabled and an effectively opaque alpha.
- Imported glass material remains transparent.
- Existing tests pass.
- Windows EXE/PCK export succeeds and `closed_beta.zip` contains exactly those two non-empty artifacts.

## Required validation

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1`
- ZIP entry and non-empty artifact validation.

## Investigation and validation record

- Reproduction: after adding direct imported-material assertions, `tools/test.ps1` failed once with the original conflicting `d`/`Tr` rows.
- First correction attempt: removed both inverse `Tr` rows and retained body `d 1.0` plus glass `d 0.06`; a second `tools/test.ps1` run still failed one material assertion.
- Required advisor consultation after two failures: the advisor identified stale OBJ import data. Godot's generated `.obj.import` listed only the OBJ as its source and did not declare the MTL as a dependency, so changing the MTL alone had not rebuilt the cached mesh.
- Final correction: removed the generated stale OBJ import descriptor, allowing Godot to perform a clean reimport, and made the regression test identify body/glass by surface/material name rather than brittle fixed indices.
- Final `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: PASS (exit code 0). Both `imported vehicle body material is opaque` and `imported vehicle glass remains transparent` pass, as does the full existing suite.
- Updated MTL: 696 bytes, SHA-256 `4C29038BCAD28F2F639223F92FD13FA0C649D6B452C18DF34F82449FEACA3A85`.
- Non-fatal baseline diagnostics remain: ignored legacy OBJ ambient-light fields and Godot shutdown cleanup warnings.
