# UXR-08A - Validate a playable release candidate with known pending visuals

Status: Complete

**Goal**

Establish that the current tree remains launchable and playable enough to export while UXR-05B1, UXR-06A's global gate, and UXR-07A remain explicitly pending by user authorization.

**Ownership boundary**

- Validation reports under `reports/**`
- No source, scene, asset, resource, test, tooling, ticket, or workspace-rule edits.

**Non-goals**

- Do not correct or suppress the eight known locomotion test failures.
- Do not replace NPC primitives, add animation, mark UXR-08 complete, or claim full release readiness.

**Acceptance criteria**

- Godot 4.7.1 imports the project without parse/import failures.
- Main scene starts headlessly and remains alive for a bounded smoke interval without a fatal error or missing runtime resource.
- The automated suite has no failure beyond the eight documented UXR-05B1 locomotion assertions.
- A short 250-NPC benchmark completes with 250 active NPCs, average FPS at least 30, bounded post-warmup allocations, and no fatal runtime error.
- Reports clearly retain the known pending status; a pass authorizes export only as a playable candidate, not completion of UXR-08.

**Required tests**

- Clean/headless import.
- Bounded Main-scene headless smoke.
- Complete Docker test suite with exact failure allowlist comparison.
- At least a 60-second 250-NPC headless benchmark.

**Dependencies**

- UXR-05A and UXR-06A implementation must be present; the user explicitly authorizes bypassing only non-game-breaking pending tickets.

**Validation evidence**

- Decision-owner review accepted the Luna validation-only run as `PLAYABLE-CANDIDATE`: Godot 4.7.1 import and bounded Main-scene smoke both exit 0 with no parse/import/missing-resource failure.
- The complete suite reports 1,620 assertions: 1,612 pass and exactly the eight authorized UXR-05B1 locomotion failures, with no unexpected failure.
- The 60-second 250-NPC benchmark passes at 144.33 average FPS with 250 active NPCs and allocations stable at 250; the supplemental 90-second run passes with memory analysis ready, 58,976-byte delta, and no continuous growth.
- Reports are recorded under `reports/uxr-08a-*`. Existing shutdown warnings remain two ObjectDB instances and one process-cache Resource in use; UXR-08 remains open and this gate authorizes only a candidate export.
