# T-053 - Add Docker benchmark script

Status: Complete

Create `tools/benchmark.ps1` to run the crowd benchmark scene in the isolated container and save a report.

**Acceptance criteria**

- The report is written under `reports/`.
- The command returns non-zero when the configured performance threshold fails.
