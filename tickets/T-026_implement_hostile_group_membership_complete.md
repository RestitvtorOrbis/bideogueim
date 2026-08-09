# T-026 - Implement hostile group membership

Status: Complete

Assign every hostile a group identifier when spawned and provide a group service that tracks recent hostile impact events.

**Acceptance criteria**

- Each hostile belongs to exactly one group.
- Group impact history expires after the configured six-second window.
