# T-049 - Create the Godot tools Dockerfile

Status: Complete

Create a Dockerfile that pins Godot 4.7.1 headless with export templates and runs as a non-root user.

**Acceptance criteria**

- The image can import the project headlessly.
- The container user is not root.
- The Godot version is asserted by the image build or entrypoint.
