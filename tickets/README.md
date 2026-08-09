# Ticket Tracking

Each ticket is stored in its own Markdown file in this directory.

- Open ticket: `<ticket-id>_<slug>.md`
- Completed ticket: `<ticket-id>_<slug>_complete.md`
- Determine pending work from filenames only; do not open completed tickets during backlog discovery.
- Rename a ticket to add `_complete` only after its acceptance criteria and required tests have been validated.

Migrated tickets: 90 total, 11 open, 79 complete.

## Language Policy

All repository files, source code, identifiers, comments, documentation, commit messages, issue titles, ticket descriptions, UI copy, and asset manifests **must be written in English**. This applies even when product discussions with the project owner are in another language.

Add every future implementation ticket as a separate file in this directory. Keep each ticket in English, independently implementable, narrowly scoped, and supplied with explicit acceptance criteria.

## Working Rules

- Engine: Godot `4.7.1`.
- Target: Windows desktop, single-player, keyboard/mouse and gamepad.
- Language: GDScript.
- Renderer: Forward+.
- Do not add gameplay systems outside the tickets without creating a new ticket first.
- Use only original placeholder assets or assets documented as CC0 in `ASSET_MANIFEST.md`.
- Target performance: 250 visible NPCs and at least 30 FPS at 1080p on the reference PC (Ryzen 5 3600, GTX 1660, 16 GB RAM).

## UXR Execution Order

1. Run UXR-01, UXR-02, UXR-03, and UXR-04 in parallel only while their ownership boundaries remain disjoint.
2. Run UXR-05 after UXR-01.
3. Run UXR-06 after UXR-04 and UXR-05.
4. Run UXR-07 after UXR-03 and UXR-05. UXR-06 and UXR-07 may run in parallel because their write boundaries are disjoint.
5. Run UXR-08 only after UXR-02, UXR-06, and UXR-07 are validated.
6. Run UXR-09 only after UXR-08 is validated.
