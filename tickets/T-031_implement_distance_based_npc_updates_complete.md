# T-031 - Implement distance-based NPC updates

Status: Complete

Update near NPCs every frame, mid-range NPCs on a staggered interval, and far NPCs with simplified movement.

**Acceptance criteria**

- Full AI distance is configurable through `CrowdSettings`.
- Far NPCs do not run hostile attack checks.
