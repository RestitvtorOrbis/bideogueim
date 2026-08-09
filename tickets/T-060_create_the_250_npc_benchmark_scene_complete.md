# T-060 - Create the 250-NPC benchmark scene

Status: Complete

Create a headless benchmark scene that maintains 250 NPCs for ten minutes and records frame time, average FPS, peak memory, and pool allocations.

**Acceptance criteria**

- The scene runs without manual input.
- It writes a report suitable for `tools/benchmark.ps1`.
- It fails when average FPS is below 30 or memory grows continuously.
