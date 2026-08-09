# T-030 - Implement NPC pooling

Status: Complete

Create an NPC pool that reuses civilian and hostile instances instead of destroying and recreating them during normal population turnover.

**Acceptance criteria**

- Returning an NPC clears state, velocity, navigation target, group membership, and visual effects.
- Population management does not call `queue_free()` during ordinary despawn/reuse.
