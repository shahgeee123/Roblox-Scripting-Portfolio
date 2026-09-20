# Placement System

A minimal plot-local building loop. The client converts a click into grid coordinates; the server selects the player's plot and computes the actual transform. The client never supplies an owner, object template, or final CFrame.

## Install

| File | Studio instance | Location |
| --- | --- | --- |
| `GridUtil.luau` | ModuleScript `GridUtil` | ReplicatedStorage |
| `PlacementService.server.luau` | Script `PlacementService` | ServerScriptService |
| `PlacementController.client.luau` | LocalScript `PlacementController` | StarterPlayer → StarterPlayerScripts |

Start Play. Click the generated green plot to place a crate. Press R to change orientation in 90-degree steps; the cube's orientation is intentionally visually subtle. The server creates the remote, plots, and crates. Install only one copy. For multiple players, plots are spaced 44 studs apart along X.

## Review notes

- Rejects non-numbers, NaN, infinity, fractional cells, and invalid rotations before geometry work.
- Ownership is derived from the remote's authenticated Player argument.
- Bounds include the whole crate footprint, even on a rotated plot.
- Rate limiting and a per-player object cap bound request work and object growth.
- The overlap query checks placed objects on that player's plot; validation and insertion do not yield.
- Player departure removes the plot and its instances.

## Deliberate limits

This is a fixed-size crate demonstration, not a Bloxburg clone. No persistence, pricing, undo, ghost preview, wall dragging, stack placement, touch/controller input, or rejection UI is included. World obstacles and characters are excluded from overlap queries. Players can build anywhere on their own plot without a character-distance check, suitable for a free-camera building mode. Slots increase for each joining player and are not recycled; a production server should use a finite plot allocator.

See the root Studio checklist for adversarial input and multiplayer checks.
