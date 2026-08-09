# T-005 - Add a minimal game state service

Status: Complete

Implement an autoload named `GameState` that exposes `is_game_over`, `current_score`, `high_score`, and a `reset_run()` method.

**Acceptance criteria**

- A new run resets only run-specific state.
- `high_score` remains unchanged by `reset_run()`.
- The service has no direct UI dependencies.
