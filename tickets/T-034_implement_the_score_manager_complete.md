# T-034 - Implement the score manager

Status: Complete

Create an autoload `ScoreManager` that receives `ImpactEvent` objects and is the only component allowed to change score.

**Acceptance criteria**

- A hostile impact adds 100 points by default.
- A civilian impact subtracts 250 points by default.
- Score changes emit a signal containing the delta and resulting total.
