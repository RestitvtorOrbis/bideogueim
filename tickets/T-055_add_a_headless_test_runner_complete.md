# T-055 - Add a headless test runner

Status: Complete

Create a dependency-free GDScript test runner that executes registered unit tests with `--headless` and produces a machine-readable report.

**Acceptance criteria**

- Passing tests return exit code zero.
- Failing assertions return a non-zero exit code.
- The report is written under `reports/`.
