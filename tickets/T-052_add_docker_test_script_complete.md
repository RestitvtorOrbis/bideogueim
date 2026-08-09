# T-052 - Add Docker test script

Status: Complete

Create `tools/test.ps1` to run the test suite inside the isolated container.

**Acceptance criteria**

- The command uses the Compose test service.
- A failing test returns a non-zero PowerShell exit code.
