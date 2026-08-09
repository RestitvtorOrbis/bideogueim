# T-032 - Implement continuous population management

Status: Complete

Spawn and recycle NPCs from off-screen zones to maintain the configured civilian and hostile targets.

**Acceptance criteria**

- Active NPC count does not exceed the configured cap.
- NPCs are not spawned inside the active camera frustum.
- The target population is restored after NPC removal.
