# UXR-03 - Add initial hostile safety

Status: Complete

**Goal**

Prevent hostile NPCs from spawning dangerously close or damaging the player immediately after a run begins.

**Ownership boundary**

- `scripts/resources/crowd_settings.gd`
- `resources/default_crowd_settings.tres`
- `resources/default_hostile_profile.tres`
- `scripts/npc/population_manager.gd`
- `scripts/npc/npc.gd`
- `tests/test_population.gd`

**Non-goals**

- Do not change NPC models, animation, scoring, impact handling, or panic rules.

**Acceptance criteria**

- Initial civilians spawn at least 20 meters from the player.
- Initial hostiles spawn at least 35 meters from the player.
- Later hostile respawns occur at least 30 meters from the player.
- For 8.0 seconds after `PopulationManager.configure()`, hostiles cannot enter ENGAGE or deal damage.
- During the grace period, hostiles inside the 30-meter safe radius move outward and hostile wander targets cannot cross the safe radius.
- After the grace period, hostile combat resumes with engagement range 18.0, attack range 2.25, interval 1.25, and damage 8.0.

**Required tests**

- Use an injectable or directly controllable elapsed-time source; do not use real-time waits.
- Test behavior at 7.99 and 8.00 seconds.
- Verify zero damage and no ENGAGE during grace, valid attacks after grace, role-specific spawn distances, and correct behavior after pooled NPC reuse.

**Dependencies**

- None.

**Validation evidence**

- Decision-owner review confirmed role-specific spawn floors, the controlled 8.0-second boundary, safe-radius enforcement, post-grace melee tuning, and pooled-state reset within the recorded ownership boundary.
- The focused population assertions passed, including 7.99/8.00 seconds, zero grace damage, post-grace damage, role distances, safe wander targets, outward movement, and pool reuse.
- The integrated Docker suite passed 194/194 assertions after UXR-03A and UXR-04A.
- `git diff --check` passed with line-ending warnings only.
