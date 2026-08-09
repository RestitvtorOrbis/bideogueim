# T-036 - Implement impact eligibility protection

Status: Complete

Ensure an NPC can only score once per life cycle and is ignored after becoming `disabled`.

**Acceptance criteria**

- Repeated collision frames do not award repeated points.
- Reused pooled NPCs become score-eligible only after full reset.
