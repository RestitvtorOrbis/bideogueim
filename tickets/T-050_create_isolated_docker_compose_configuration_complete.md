# T-050 - Create isolated Docker Compose configuration

Status: Complete

Create Compose configuration for headless tooling with dropped capabilities, `no-new-privileges`, resource limits, named caches, and no runtime network.

**Acceptance criteria**

- The project directory, import cache, and export directory are the only mounts.
- Normal test/export services use `network_mode: none`.
- The configuration does not use privileged mode.
