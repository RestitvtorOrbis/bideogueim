# UXR-08 - Validate the integrated 250-NPC build

Status: Open

**Goal**

Validate functional integration, renderer performance, pooling, memory behavior, and asset size before release export.

**Ownership boundary**

- `scripts/benchmark/benchmark_scene.gd`
- `tests/test_runner.gd`
- `docs/ARCHITECTURE.md`
- Validation reports under `reports/**`

**Non-goals**

- Do not redesign or retune gameplay during validation.
- Do not make broad corrective changes. Create a focused follow-up ticket for any failed gate that requires implementation.

**Acceptance criteria**

- Godot 4.7.1 performs a clean import without errors.
- The complete automated test suite passes.
- The ten-minute headless benchmark maintains 250 NPCs, average FPS of at least 30, bounded pool allocations, and no continuous memory growth.
- A Forward+ visible benchmark with 250 NPCs meets the existing reference-PC renderer target.
- No unused character asset, archive, or duplicate source format remains.
- Manual verification confirms an unobstructed camera, visible nearby vehicle, immediate E entry, no initial hostile death, correct human models, and working NPC variation.

**Required tests**

- `godot --headless --path . --editor --import --quit`
- `godot --headless --path . --scene res://tests/TestRunner.tscn -- --report res://reports/test-results.json`
- `./tools/benchmark.ps1`
- A documented Forward+ rendered benchmark and manual startup checklist.

**Dependencies**

- UXR-02, UXR-06, and UXR-07 must be completed and validated.

**Validation evidence**

- Pending.
