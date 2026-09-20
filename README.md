# Vault · Roblox Scripting Portfolio

**Luau • Server-authoritative systems • Modular gameplay code**

Hey, I'm Vault. This portfolio focuses on the code behind Roblox gameplay: placement, machine progression, persistence, inventory, and responsive interfaces.

## Start here

| Sample | Engineering focus | Entry point |
| --- | --- | --- |
| [Placement System](Placement-System/) | Grid math, plot ownership, input validation, overlap checks | `PlacementService.server.luau` |
| [Tycoon Machine System](Tycoon-Machine-System/) | Deterministic production, capped catch-up, atomic upgrades | `MachineService.luau` |
| [Data System](Data-System/) | Schema migration, retries, concurrent-safe best scores | `BestScoreStore.luau` |
| [Inventory System](Inventory-System/) | Stack limits, capacity checks, all-or-nothing mutations | `InventoryService.luau` |
| [UI System](UI-System/) | Tween cancellation, input binding, connection cleanup | `PanelController.luau` |

**Suggested review:** start with placement to inspect the client/server boundary, then inventory for state invariants, and data for persistence tradeoffs. Each folder explains its setup, design decisions, limitations, and manual checks.

## About these samples

This repository contains focused demonstration systems for code review, with installation instructions and documented design tradeoffs. The samples are independent of the released project linked below. Runtime checks are documented in STUDIO-CHECKS.md and have not yet been executed in Roblox Studio.



## Project context

[Run An Illegal Business — Roblox](https://www.roblox.com/games/93015933934800/Run-An-Illegal-Business)

## Repository approach

- Clients submit intent; the server owns gameplay decisions and state.
- Small modules expose explicit operations instead of sharing mutable tables.
- Invalid requests fail without partially changing gameplay state.
- Comments explain constraints and tradeoffs, not just individual statements.
- Each example has a narrow scope; this is a code-review package, not a complete game framework.

## Run and review

Use a fresh Roblox Studio test place and follow the installation map in each folder. Files ending in `.server.luau` become **Scripts**, `.client.luau` become **LocalScripts**, and other `.luau` files become **ModuleScripts**. Use the base filename for the Studio instance name; omit the extension and `.server`/`.client` suffix.

The folders are independent examples. Placement has its own playable bootstrap; the other folders provide focused integrations or test harnesses. There are no external package dependencies. See [STUDIO-CHECKS.md](STUDIO-CHECKS.md) for the review checklist and [APPLICATION-CHECKLIST.md](APPLICATION-CHECKLIST.md) before publishing.

## Reference documentation

Implementation choices were checked against the official [Roblox client/server security guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary), [DataStore documentation](https://create.roblox.com/docs/cloud-services/data-stores), and [Luau syntax reference](https://luau.org/syntax/).
