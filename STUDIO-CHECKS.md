# Studio review checklist

**Status: not executed in Studio.** These are reproducible acceptance checks, not claimed test results. Use a separate test place; the persistence example uses `PortfolioBestScores_v1` and should not be connected to live player data.

| System | Action | Expected behavior |
| --- | --- | --- |
| Placement | Start a two-player local server; click each plot | Each player can place only on their assigned plot |
| Placement | Click the same occupied cell twice | Second object is rejected |
| Placement | Send a string, NaN, infinity, fractional cell, or huge coordinate through the remote | Request is ignored; server remains responsive |
| Placement | Place outside the plot, rotate the plot, then place near its edge | Bounds remain plot-local; out-of-bounds requests fail |
| Placement | Send repeated requests; reach the object cap | Cooldown and cap prevent unbounded placement |
| Machines | Run the supplied server harness | All assertions pass; output reports completion |
| Inventory | Run the supplied server harness | Overflow fails atomically; snapshots cannot mutate stored inventory |
| Data | Save 100, then save 50, then read | Stored best remains 100 |
| Data | Save 100 and 200 concurrently for one test user | Stored best becomes 200 regardless of write order |
| Data | Disable API access and attempt a save | Bounded retries finish with failure, not a false success |
| Data | Seed a record with an unsupported version | Load/save fail without overwriting that record |
| UI | Press B rapidly while a transition is running | Latest requested state wins without stacked tweens |
| UI | Focus a TextBox and type B | Panel does not toggle |
| UI | Call controller Destroy twice, then press B | No errors and no remaining input handler |

Also inspect Studio Script Analysis and Output for warnings/errors after installation. The data module needs a published test place and Studio API access for real DataStore calls. Placement and UI should be checked with a local server and client, not only editor inspection.
