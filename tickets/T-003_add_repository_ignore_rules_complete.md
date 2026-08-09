# T-003 - Add repository ignore rules

Status: Complete

Add a `.gitignore` for Godot imports, local editor data, export outputs, test reports, and Docker caches.

**Acceptance criteria**

- `.godot/`, `.import/`, `exports/`, `reports/`, and `.docker-cache/` are ignored.
- Project source, scenes, resources, tests, and Docker configuration are not ignored.
