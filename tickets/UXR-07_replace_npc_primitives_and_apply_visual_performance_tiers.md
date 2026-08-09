# UXR-07 - Replace NPC primitives and apply visual performance tiers

Status: Open

**Goal**

Use varied adult human models for civilians and hostiles while keeping 250 pooled NPCs within the project's performance target.

**Ownership boundary**

- `scenes/Npc.tscn`
- `scripts/npc/npc.gd`
- `scripts/npc/population_manager.gd`
- `scripts/visual/npc_visuals.gd`
- NPC and pooling-focused tests

**Non-goals**

- Do not alter the safety and combat decisions validated in UXR-03.
- Do not add teen models or additional animation libraries.

**Acceptance criteria**

- Civilians and hostiles both reuse the Superhero Male and Superhero Female bases; role-specific shared palettes, hairstyles, accessories, scale bands, and animation behavior provide differentiation.
- Civilian visual heights are deterministic between 1.68 and 1.86 meters; hostile visual heights are 1.78 or 1.86 meters.
- All NPCs use a common gameplay capsule 1.75 meters tall with radius 0.35 and center Y 0.875.
- NPC yaw interpolates toward movement direction.
- The hostile prop uses a right-hand `BoneAttachment3D`; the warning marker remains above the head.
- At 0-35 meters animations update normally; at 35-75 meters visual animation updates at no more than 10 Hz; at 75-100 meters the NPC is frozen in idle with hair and shadows disabled; beyond 100 meters its visual is hidden.
- NPC dynamic shadow casting is disabled.
- Role palettes and hairstyles use shared cached resources with no per-instance material duplication.
- Pool checkout and release reset all visual, animation, attachment, and tier state.

**Required tests**

- Test deterministic model, height, palette, and hairstyle distribution.
- Test movement orientation and each visual tier boundary.
- Test pooling reuse for civilians and hostiles.
- Re-run the UXR-03 hostile safety tests after integration.

**Dependencies**

- UXR-03 and UXR-05 must be completed and validated.

**Validation evidence**

- Pending.
