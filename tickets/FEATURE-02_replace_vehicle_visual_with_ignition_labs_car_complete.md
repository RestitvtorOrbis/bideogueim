# FEATURE-02 — Replace vehicle visual with Ignition Labs car

## Goal

Replace the shipped primitive arcade-car body with the user-supplied `CAR Model by Ignition Labs - 5zUWP5UsLg-.zip` model, while preserving the vehicle's existing physics, controls, collision, camera, suspension, health, entry/exit, and gameplay contracts.

## Context and evidence

- The supplied ZIP is present at the repository root and contains `Lamborghini_Aventador.obj`, `Lamborghini_Aventador.mtl`, `Lamborginhi Aventador_diffuse.jpeg`, and `Lamborginhi Aventador_spec.jpeg`.
- The OBJ contains six groups: body, glass, and four wheels. Its raw bounds are approximately X -134.6429..95.5599, Y 0.0404..117.5937, Z -271.7693..217.6714.
- A uniform scale of `0.009` yields an approximately 2.07 × 1.06 × 4.41 m visual, fitting the current 2.1 × 0.75 × 4.2 m gameplay collision closely. Position X `0.176`, Y `0.0`, Z `0.243` recenters the model at that scale. The longer negative-Z nose matches the current vehicle forward direction.
- The vendor MTL contains machine-local absolute texture paths and must be normalized to the retained local JPEG basenames so Godot can import the textures.
- The original Poly Pizza page `https://poly.pizza/m/5zUWP5UsLg-` identifies the model as “CAR Model,” author Ignition Labs, published 2018-08-16, under Creative Commons Attribution. Attribution must be recorded in `ASSET_MANIFEST.md`.

## Ownership boundary

- `assets/vehicles/ignition_labs_car/**` (new retained files derived from the supplied ZIP)
- `scenes/ArcadeVehicle.tscn`
- `tests/test_system_contracts.gd`
- `ASSET_MANIFEST.md`
- This ticket file

## Exact implementation scope

- Extract only the four OBJ/MTL/JPEG payload files into `assets/vehicles/ignition_labs_car/`; do not commit or modify the source ZIP.
- Normalize only the MTL texture references needed for portable local import; preserve the OBJ geometry and JPEG bytes.
- Replace/hide/remove the primitive visible vehicle body, cabin, hood, roof, accent, lamps, wheels, and hubs so only the supplied model renders as the car.
- Add the imported OBJ as the visible model at uniform scale `0.009` and recenter it with the evidence-backed offset above.
- Preserve every gameplay node and value: root RigidBody3D, CollisionShape3D, four wheel markers and suspension raycasts, camera rig, health component, scripts, layers/masks, and physics configuration.
- Add a minimal automated contract checking that the imported model resource is used, the old primitive body is absent or hidden, and the gameplay collision/suspension contract remains intact.
- Record source, author, CC Attribution license, canonical URL, retained files, source ZIP name/hash/size, and MTL path normalization in `ASSET_MANIFEST.md`.

## Non-goals

- Do not tune collision dimensions, mass, propulsion, suspension, steering, camera, vehicle health, or controls.
- Do not remodel, decimate, recolor, or otherwise alter the mesh or JPEG pixels.
- Do not animate separate wheel groups in this ticket.
- Do not modify NPCs, gore effects, world generation, or unrelated user-supplied archives/files.

## Acceptance criteria

- `ArcadeVehicle.tscn` visibly uses the Ignition Labs OBJ instead of the primitive body kit.
- The imported model is centered, upright, forward-aligned, and approximately matches the existing gameplay footprint.
- Local texture references resolve portably in Godot/Docker import.
- Physics/collision/suspension/camera/health gameplay nodes and settings are unchanged.
- Asset attribution is complete and accurate.
- Automated tests and Windows export pass.

## Required validation

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`
- `git diff --check`
- Decision-owner inspection of retained files, MTL references, scene diff, and relevant test output.
- After accepted commit: mandatory Windows export via `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1`, followed by exact two-file `exports/closed_beta.zip` verification.

## Dependencies and handoff

- Depends on the user-supplied ZIP and the existing `ArcadeVehicle.tscn` gameplay hierarchy.
- Handoff must list changed files, verification commands/results, known limitations, and deferred decisions.

## Validation record

- Decision-owner diff and retained-asset review: accepted. The implementation remains within the ownership boundary and meets every acceptance criterion.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: PASS (exit code 0). Godot imported the OBJ and both JPEG textures; new resource, transform, primitive-removal, collision-footprint, marker-position, and suspension contracts passed alongside the existing suite.
- `git diff --check`: executed. It reports trailing whitespace and the final blank line contained in the byte-identical vendor OBJ, plus two pre-existing trailing spaces in the vendor MTL material rows. All repository-authored scene, test, manifest, and ticket diffs pass the whitespace check. The vendor OBJ is intentionally not normalized because preserving its source bytes and documented SHA-256 is an acceptance requirement; the MTL changes remain limited to its three texture paths.
- Source/archive audit: source ZIP is 753,396 bytes with SHA-256 `6F98750B8E2CD96EE79E5F6969344CD9D4129ED8EB69E45668E3B99AAB352EA1`; retained OBJ/JPEG hashes match their archive entries; the MTL differs only in its three portable local texture references and its final documented SHA-256 is `94875AC6DA58920570DBA17B7F7117FEC1483BEFD349D08F5B5AA4528C2F3493`.
- Known non-fatal diagnostics: Godot ignores legacy OBJ ambient-light fields in its PBR importer and reports baseline shutdown cleanup warnings (4 ObjectDB instances and 1 resource still in use). Tests exit 0.
- Known limitation accepted by scope: the vendor wheel groups remain static as part of the combined imported mesh.
- No deferred product decisions.
