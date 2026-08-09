# UXR-05B1 - Load and share the trimmed locomotion resources

Status: Open

**Goal**

Load the retained locomotion GLB once, expose the exact three clips through the shared visual component, and prove that logical character instances reuse the same animation resources.

**Ownership boundary**

- `scripts/visual/characters/human_character_visual.gd`
- `scenes/visuals/characters/HumanCharacterVisual.tscn`
- `tests/test_character_visuals.gd`

**Non-goals**

- Do not select clips from movement speed, advance playback, retarget gameplay motion, or edit Player/Npc.
- Do not modify the GLB, catalog, test runner, unrelated tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The component loads only `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop` from `locomotion.glb` through a process-wide cache.
- Public lookup returns stable shared `Animation` Resource identities across 250 logical instances.
- Missing source, library, skeleton, or clip returns a defined failure without breaking scene instantiation or geometric/accessory state.
- No per-character duplicate animation library or clip Resource is created.

**Required tests**

- Verify exact clip names, shared Resource identity across 250 logical instances, missing-resource behavior, focused visual suite, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A must be completed and validated.

**Validation evidence**

- **Status: PENDING (unresolved in the single beta investigation round).**
- Reproduction: load `res://assets/characters/quaternius/animations/locomotion.glb` as a Godot `PackedScene` and attempt to locate the imported `AnimationPlayer`, library, and exact clip Resources required for a shared cache.
- Impact: UXR-05B2 and locomotion integration in Player/Npc cannot proceed without a verified imported hierarchy and Resource lookup contract; no speculative animation code was added.
- Evidence collected: the source GLB contains exactly `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop`, but the Luna round did not verify Godot's imported node path, library name, or effective animation keys; no B1-owned file changed and zero B1 assertions ran.
- Suspected scope: Godot glTF import hierarchy inspection and the cache/lookup portion of `human_character_visual.gd` plus focused tests. Resume only with a concrete hierarchy dump or import-scene inspection method, not another speculative implementation pass.
- Post-round workspace verification found a delayed B1 partial patch in `human_character_visual.gd` and `test_character_visuals.gd` despite the agent's no-change report. It is not accepted: the full suite exits 1 with 1,612 passes and exactly 8 locomotion failures (`Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, ready/cache/library/bounded-cache/unsupported-clip gates).
- Do not mark B1 complete or start B2 while this unvalidated partial patch remains. Resolving or removing it requires explicit authorization to reopen the beta round.
