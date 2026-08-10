# BUG-04 — Align imported vehicle model with gameplay forward

## Goal

Correct the Ignition Labs Lamborghini visual so the car's nose faces the vehicle's gameplay-forward direction instead of rendering with its rear end first, while preserving the accepted physical footprint and all driving behavior.

## Context and evidence

- The user reports that the shipped car model is reversed: the rear is at the front and the nose is at the back.
- `scripts/vehicle/arcade_vehicle.gd` defines vehicle forward as local negative Z (`-global_transform.basis.z`).
- `scenes/ArcadeVehicle.tscn` places the front suspension markers at Z `-1.35` and the rear markers at Z `+1.35`.
- The imported OBJ's named wheel groups prove that its source convention is opposite: `Wheel_FL` and `Wheel_FR` are centered at source Z `+99.439`, while `Wheel_RL` and `Wheel_RR` are centered at source Z `-175.468`.
- The source left/right convention is also opposite to the game's X convention: `Wheel_FL` is centered at source X `+65.888`, while the game's front-left marker is X `-0.92`. A 180-degree local Y rotation corrects both axes without modifying geometry.
- The OBJ body bounds have source center approximately X `-19.541`, Z `-27.049`. At scale `0.009`, the current unrotated centering offset is `(0.176, 0, 0.243)`. After a 180-degree Y rotation, the evidence-backed centering offset is `(-0.176, 0, -0.243)`.
- Existing untracked root archives and `sourcesforblood.md` are user-owned and must remain untouched.

## Ownership boundary

- `scenes/ArcadeVehicle.tscn`
- `tests/test_system_contracts.gd`
- This ticket file

## Exact implementation scope

- Rotate only the `IgnitionLabsCar` visual node by 180 degrees around local Y.
- Update only that visual node's position to `Vector3(-0.176, 0.0, -0.243)` so its accepted footprint remains centered after rotation.
- Extend the existing imported-vehicle system contract to assert the corrected Y orientation and centering offset, together with the existing scale check.
- Do not edit the vendor OBJ, MTL, textures, import metadata, or any gameplay node.

## Non-goals

- Do not modify vehicle controls, propulsion, steering, braking, reverse tuning, collision, suspension, mass, camera, health, reset behavior, entry/exit, or spawn orientation.
- Do not remodel, re-export, mirror, or otherwise alter the source asset.
- Do not animate the imported wheel groups or change materials.
- Do not touch unrelated open tickets or user-owned untracked files.

## Acceptance criteria

- The visible car nose faces local negative Z, matching throttle-forward movement and front wheel markers.
- The imported model remains centered on the gameplay body with uniform scale `0.009` and position `Vector3(-0.176, 0.0, -0.243)`.
- The visual node has a 180-degree Y rotation and no X/Z rotation.
- Collision, suspension markers/raycasts, camera, health, controls, and vehicle script remain unchanged.
- The focused automated contract and the minimum repository test suite pass.

## Required validation

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`
- `git diff --check -- scenes/ArcadeVehicle.tscn tests/test_system_contracts.gd tickets/BUG-04_align_imported_vehicle_model_with_gameplay_forward.md`
- Decision-owner inspection of the scene/test diff and confirmation that the transform maps the OBJ front-wheel centers to local negative Z and left wheels to local negative X.
- After the dedicated accepted BUG-04 commit, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1`.
- Rebuild `exports/closed_beta.zip` from the matching non-empty `UrbanDrivePrototype.exe` and `UrbanDrivePrototype.pck`, verify the ZIP contains exactly those two files, commit the refreshed ZIP, and push normally to `origin` only if export and ZIP validation succeed.

## Dependencies and handoff

- Depends on the already integrated FEATURE-02 imported vehicle model.
- Luna must report changed files, exact validation commands/results, known limitations, and deferred decisions.
- Sol alone inspects acceptance evidence, records validation here, renames this file with `_complete`, and closes it in the dedicated atomic BUG-04 commit.

## Validation record

- Sol inspected the implementation diff and accepted it within the ownership boundary: only `IgnitionLabsCar` position/rotation and the matching system contract changed; all gameplay nodes and values remain untouched.
- Geometry audit: a 180-degree Y rotation maps the OBJ front-wheel centers from source positive Z to game-local negative Z and maps source `Wheel_FL` positive X to game-local negative X. Negating the previous centering offset preserves the accepted visual center after that rotation.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: PASS (exit code 0), including `imported vehicle model keeps the corrected scale, offset, and orientation` and the existing vehicle physics contracts.
- `git diff --check -- scenes/ArcadeVehicle.tscn tests/test_system_contracts.gd tickets/BUG-04_align_imported_vehicle_model_with_gameplay_forward_complete.md`: PASS; Git emitted only line-ending conversion notices for the existing Windows checkout.
- Known non-fatal baseline diagnostics: Godot reports 6 leaked ObjectDB instances and 2 resources still in use during test-run shutdown; the suite exits 0.
- No known implementation limitation and no deferred product decision.
