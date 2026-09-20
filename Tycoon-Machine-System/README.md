# Tycoon Machine System

A deterministic production and upgrade module. Keeping time input explicit makes production behavior easy to inspect without starting a separate loop for every machine.

## Install and exercise

Place `MachineService` (ModuleScript) and `MachineChecks` (Script) together in a folder in ServerScriptService. Run Play and inspect Output for the assertion results.

For gameplay integration, keep a `State` per player on the server, call `advance(state, deltaTime)` from one shared Heartbeat connection, and remove the entry on PlayerRemoving. An upgrade remote should use the calling Player to find the state, apply a request cooldown, then call `upgrade`. That remote adapter and player lifecycle are not included in this focused module.

## Design choices

- Two-second production ticks preserve fractional remainder between updates.
- A ten-second catch-up cap prevents long stalls from creating huge payouts; time above that cap is discarded intentionally.
- Upgrade prices and output rates are computed by server code.
- Insufficient funds and maximum level return explicit results without mutation.
- Snapshots are copies; UI consumers cannot change the state through them.

State is trusted server-owned memory, not a remote payload or unchecked save record. Do not pass arbitrary client-created state into these functions. Coins are capped at one billion. This sample has no purchases, physical conveyors, offline income, persistence, or cross-server economy.
