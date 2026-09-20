# Inventory System

A server-side, count-based inventory with eight logical slots. Stack size is item-specific: 50 wood, 50 stone, or 10 gears per slot. Counts may span several slots; this module does not maintain individual slot positions.

## Install

Place `InventoryService` (ModuleScript) and `InventoryChecks` (Script) together in a folder in ServerScriptService. Run Play to execute the assertion harness.

In a game, create one bag per player in a server-owned map. Only trusted reward, shop, or crafting logic should call `add`. A client request to use an item must be validated by a remote adapter before calling `remove`; it must never be treated as permission to grant items. No remote that grants arbitrary items is provided.

## Review notes

Capacity is checked on a candidate copy before committing. Failed additions and removals leave the original bag unchanged. Amounts must be finite positive integers within a bounded range. Zero-count entries are removed, and snapshots cannot mutate the original table.

The public functions have typed inputs and expect trusted callers; a remote adapter must check runtime types before calling them. Bags must originate from `new` and remain server-owned. Persisted bags require schema validation before reuse. Trading, equipment, slot ordering, persistence, item instances, and transaction rollback across other services are outside scope.
