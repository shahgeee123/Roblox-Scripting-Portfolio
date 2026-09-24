# Studio review checklist

## Vault Guardian

**Status:** the script compiles in Studio, and its math (intercept solver, ballistic launch, zone clamping, patrol route) and its `Cleaner` class pass unit checks. It has **not been playtested yet**. Run these checks in the demo place before submitting.

| Action | Expected behavior |
| --- | --- |
| Press Play in an empty Baseplate | Vault, pillars, pedestal, present and drone appear; Output prints `Guardian(Spawned) -> Patrol`; no errors |
| Watch the drone | Circles the pedestal, facing where it moves, with its spotlight marking the view cone |
| Steal the present while the drone faces away and is more than 9 studs from you | Present rides above your head; the drone keeps patrolling until it sees or hears you |
| Get spotted while carrying the present | Eye turns yellow with `!` for 1 second, then red `!!` and it chases |
| Stay 12 to 26 studs away in open ground | It leaps on an arc at the spot you are heading for; sidestepping mid-leap makes it miss |
| Get caught | Knocked back; present returns to the pedestal; `Caught` +1 |
| Break line of sight behind a pillar | It goes to your last known position, then `?` and sweeps left and right; back to Patrol after 4 seconds |
| Carry the present over the green line | `Steals` +1; present disappears and respawns on the pedestal 3 seconds later |
| Reset your character or leave while carrying | Present goes straight back to the pedestal |

## Other samples

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
