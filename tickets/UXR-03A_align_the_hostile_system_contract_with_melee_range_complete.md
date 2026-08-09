# UXR-03A - Align the hostile system contract with melee range

Status: Complete

**Goal**

Update the existing hostile damage contract test to exercise the validated 2.25-meter melee range instead of the obsolete four-meter assumption.

**Ownership boundary**

- Hostile engagement assertions in `tests/test_system_contracts.gd` only.

**Non-goals**

- Do not modify gameplay, profiles, scenes, unrelated system tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The contract fixture places the hostile inside the configured 2.25-meter attack range.
- The test still verifies ENGAGE and exactly one damage application.
- The complete test suite passes with UXR-02, UXR-03, and UXR-04 present.

**Required tests**

- Run the complete Docker test suite and report the assertion count.
- Run `git diff --check` for `tests/test_system_contracts.gd`.

**Dependencies**

- UXR-03 implementation must be present.

**Validation evidence**

- Decision-owner review confirmed that only the hostile system fixture changed and now places the hostile at 1.5 meters, inside the 2.25-meter melee range.
- The fixture verifies ENGAGE, damage, and exactly one damage event.
- The integrated Docker suite passed 194/194 assertions; `git diff --check -- tests/test_system_contracts.gd` passed.
