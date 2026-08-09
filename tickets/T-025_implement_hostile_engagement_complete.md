# T-025 - Implement hostile engagement

Status: Complete

Implement hostile detection of the player and an `engage` state that approaches the player and applies periodic damage at range.

**Acceptance criteria**

- Civilians never enter `engage`.
- A hostile in range can damage the player or occupied vehicle.
- Attack rate and range are configurable.
