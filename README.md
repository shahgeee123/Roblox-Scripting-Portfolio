# Vault · Roblox Scripting Portfolio

**Luau • Server-authoritative systems • Gameplay AI and physics**

Hey, I'm Vault. This portfolio focuses on the code behind Roblox gameplay: AI behaviour, physics, placement, persistence, inventory, and responsive interfaces.

## Featured script: Vault Guardian

**File:** [`Vault-Guardian/VaultGuardian.server.luau`](Vault-Guardian/VaultGuardian.server.luau)

One self-contained server Script with 737 lines of code, not counting comments or blank lines. A hovering security drone guards a present inside a walled vault. Players steal the present and try to carry it over the exit line. The drone notices them, gives them a head start, then chases with lead pursuit, steers around cover, and leaps on a ballistic arc to where the thief is about to be.

| Area | What the script uses |
| --- | --- |
| CFrame math | Zone-space bounds and clamping (`PointToObjectSpace`), a patrol circle built from rotated CFrames, view-cone dot products, facing and lean orientation |
| Physics | Server-owned drone driven by `AlignPosition` / `AlignOrientation`, a ballistic leap solved from projectile motion, `LinearVelocity` knockback on client-owned characters |
| Metatables / OOP | `Cleaner`, `Zone`, `Loot` and `Guardian` classes (`__index`, `__tostring`) and a table-driven state machine |
| Algorithms | Quadratic intercept solver for lead pursuit, sphere-cast steering around obstacles |

### Run the demo

1. Create a new **Baseplate** in Roblox Studio.
2. Insert a **Script** into **ServerScriptService** and paste in the file's contents.
3. Press **Play**. Hold **E** on the present, then carry it over the green line. The Output window logs every state change the guardian makes.

The script builds its own arena, so it needs no models, assets or other scripts.

## Other samples

| Sample | Engineering focus | Entry point |
| --- | --- | --- |
| [Placement System](Placement-System/) | Grid math, plot ownership, input validation, overlap checks | `PlacementService.server.luau` |
| [Tycoon Machine System](Tycoon-Machine-System/) | Deterministic production, capped catch-up, atomic upgrades | `MachineService.luau` |
| [Data System](Data-System/) | Schema migration, retries, concurrent-safe best scores | `BestScoreStore.luau` |
| [Inventory System](Inventory-System/) | Stack limits, capacity checks, all-or-nothing mutations | `InventoryService.luau` |
| [UI System](UI-System/) | Tween cancellation, input binding, connection cleanup | `PanelController.luau` |

These are smaller, focused examples, each with its own README covering setup, design decisions and limitations. They are independent of the released project linked below.

## Project context

[Run An Illegal Business — Roblox](https://www.roblox.com/games/93015933934800/Run-An-Illegal-Business)

## Repository approach

- Clients submit intent; the server owns gameplay decisions and state.
- Small modules expose explicit operations instead of sharing mutable tables.
- Invalid requests fail without partially changing gameplay state.
- Comments explain constraints and tradeoffs, not just individual statements.

## Run and review

Files ending in `.server.luau` become **Scripts**, `.client.luau` become **LocalScripts**, and other `.luau` files become **ModuleScripts**. Use the base filename for the Studio instance name; omit the extension and the `.server`/`.client` suffix. There are no external package dependencies. See [STUDIO-CHECKS.md](STUDIO-CHECKS.md) for the review checklist and [APPLICATION-CHECKLIST.md](APPLICATION-CHECKLIST.md) before applying.

## Reference documentation

Implementation choices were checked against the official [Roblox client/server security guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary), [DataStore documentation](https://create.roblox.com/docs/cloud-services/data-stores), and [Luau syntax reference](https://luau.org/syntax/).
