# Architecture

Main.tscn is the composition root. It creates a district, player, vehicle, population manager, impact effects, and interface. Reloading the main scene creates a fresh run population while the autoload services survive.

## Services

- GameState owns game-over state, high-score persistence, and the run reset signal.
- ScoreManager owns current score, combo timing, and lifecycle eligibility. It is the only component that writes the current score.
- ImpactBus transports the UI-free ImpactEvent contract to scoring and presentation.
- HostileGroupService expires hostile impact timestamps and transitions group members to panic.
- SettingsService persists the active violence preset.
- CameraShake exposes a presentation request while respecting the disabled preset.

## Pool lifecycle

NpcPool keeps instantiated NPC nodes and returns them to an inactive list. Ordinary turnover calls deactivate() and never calls queue_free(). A checkout assigns a new lifecycle ID, resets health and navigation state, and registers a hostile group membership when applicable.

Population updates are tiered by distance:

- near NPCs run every physics frame with full perception and attacks;
- mid-range NPCs run on a staggered interval with full AI;
- far NPCs use simplified movement and never run hostile attack checks.

## Validation boundary

The headless benchmark measures simulation cost and pooling behavior. A separate Forward+ run at 1920×1080 on the reference PC is still required for the visible-renderer target in TICKETS.md.
