# Repository Agent Rules

## Beta Bug-Fix Policy

This repository is in beta.

- Use only one coordinated agent round to investigate and correct each distinct bug.
- Treat all investigation, advisory consultation, implementation, and verification for that bug as part of the same round. Do not start a second agent round after it closes.
- During the round, reproduce the issue, collect evidence, identify the likely root cause, and make only an evidence-backed correction.
- If the root cause is not identified during that round, do not make speculative changes. Add an open ticket file under `tickets/` with its reproduction steps, impact, evidence collected, and suspected scope.
- After documenting an unresolved bug, continue with the active user instructions. Do not block the task by repeating the investigation.

## Windows PowerShell Build Invocation

- On Windows hosts where the local execution policy blocks repository scripts, invoke the existing export pipeline with `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1`.
- This bypass must remain process-scoped. Do not change the machine or user PowerShell execution policy.
- A direct `./tools/export.ps1` policy failure occurs before Docker starts and does not indicate a Godot export failure.

## Ticket Tracking

- The `tickets/` directory is the single source of truth for implementation work in this workspace. Each ticket must be stored in its own Markdown file.
- Open ticket filenames use `<ticket-id>_<slug>.md`. Completed ticket filenames use `<ticket-id>_<slug>_complete.md`. Backlog discovery must determine status from filenames without reading completed ticket contents.
- Before implementation or delegation, create a decision-complete open ticket containing its goal, ownership boundary, non-goals, acceptance criteria, required tests, and dependencies.
- Only the decision owner may rename a ticket to add `_complete`, and only after inspecting the implementation, confirming the ownership boundary, and validating every acceptance criterion and required test.
- A worker report, implementation claim, or partial test run is not sufficient to complete a ticket. Record the validation commands and results under the ticket before marking it complete.
- Close each ticket in one dedicated, atomic commit. That commit must contain the ticket's validated implementation and the ticket-file rename to `_complete`, use the ticket ID in its commit message, and contain no unrelated changes.
- A ticket is not considered closed until its dedicated commit succeeds. Do not bundle multiple closed tickets into one commit or spread one ticket across multiple commits.
- If validation fails, leave the ticket open and document the failure. Create a narrowly scoped follow-up ticket when additional implementation is required; do not silently expand the original ticket.
- For Sol-Luna work, Sol owns planning and acceptance. Each implementation ticket is assigned to one GPT-5.6 Luna agent with `reasoning_effort: xhigh` unless its recorded dependency and ownership boundaries explicitly permit parallel execution.
- Launch GPT-5.6 Luna subagents through `multi_agent_v1` (the app-backed task creation path) with `reasoning_effort: xhigh`; do not use the generic collaboration `spawn_agent` path for Luna, because that path does not expose the Luna model in this workspace.
