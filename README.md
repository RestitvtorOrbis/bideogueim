# Urban Drive Prototype

Urban Drive Prototype is a small single-player Godot driving prototype for Windows desktop. It targets keyboard/mouse and gamepad input, uses GDScript, and is configured for the Forward+ renderer.

## Required editor

- Godot 4.7.1 exactly
- Windows 10 or newer
- Forward+ capable graphics hardware

Open the repository folder in Godot and run scenes/Main.tscn. The project window title is Urban Drive Prototype.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Walk | W/A/S/D | Left stick |
| Look | Mouse or arrow keys | Right stick |
| Sprint | Shift | Left stick button |
| Jump | Space | A |
| Enter/exit vehicle | E | X |
| Accelerate | W | Right trigger |
| Brake/reverse | S | Left trigger |
| Steer | A/D | Left stick |
| Handbrake | Space | Left shoulder |
| Reset vehicle | R | Y |
| Toggle impact preset | G | Right stick button |
| Pause/settings | Escape or P | Start |

## Project layout

- scenes/ — startup, world, actor, vehicle, interface, and benchmark scenes.
- scripts/ — gameplay, services, resources, effects, and UI scripts.
- resources/ — Inspector-editable rules and default profiles.
- assets/ — original or future documented CC0 assets.
- tests/ — dependency-free headless test runner and unit suites.
- tools/ — Docker and PowerShell build, test, benchmark, and export commands.
- docs/ — architecture and validation notes.

## Local checks

When Godot 4.7.1 is installed:

~~~powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_runner.gd -- --report res://reports/test-results.json
~~~

Docker Desktop provides the pinned headless environment:

~~~powershell
.\tools\build.ps1
.\tools\test.ps1
.\tools\benchmark.ps1
.\tools\export.ps1
~~~

The benchmark runs for ten minutes by default, maintains 250 NPCs, records average FPS, peak memory, and pool allocations, and returns a non-zero exit code when its thresholds fail.

## Design constraints

All repository files and UI copy are written in English. Gameplay services do not reference UI nodes. ScoreManager is the only score mutator, and pooled NPCs receive a new lifecycle identifier on every checkout so a repeated collision cannot score twice. Only original placeholders or documented CC0 assets may be used.
