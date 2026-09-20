# Data System

A deliberately narrow persistence service: merge a player's **best score** safely when saves arrive out of order or multiple servers submit the same result. This is not a general-purpose profile or currency store.

## Install and exercise

Place `BestScoreStore` as a ModuleScript in ServerScriptService. Publish a separate test place and enable Studio API access for that test place. Do not test against a live game's data stores.

From a temporary server Script, use your own positive Roblox user ID in place of `YOUR_USER_ID`:

```lua
local Scores = require(game.ServerScriptService.BestScoreStore)
local userId = YOUR_USER_ID -- replace before running
local ok, result = Scores.load(userId)
if not ok then
    warn("Could not load score:", result)
    return -- never interpret a failed load as a confirmed zero score
end
print("Loaded best:", result.BestScore)

local saved, recordOrError = Scores.submit(userId, 100)
if saved then
    print("Confirmed best:", recordOrError.BestScore)
else
    warn("Score was not confirmed saved:", recordOrError)
end
```

`load` and `submit` return `(true, record)` or `(false, errorMessage)` for storage/schema failures. Invalid API arguments throw assertions because these functions are intended for trusted server callers. Validate and derive scores on the server before calling them. Remove the temporary script after testing.

## Design decisions

- Version 1 `{Version = 1, Score = n}` records migrate to version 2 `{Version = 2, BestScore = n}`. Loading normalizes in memory; a successful submit persists the current schema.
- Unknown versions and malformed records fail without being overwritten with defaults.
- `UpdateAsync` merges the maximum against the latest value. Duplicate submissions and retrying an uncertain write do not inflate a score.
- Four attempts with exponential delay and jitter bound retries. Schema failures also pass through this bounded retry path for simplicity.
- No credentials or HTTP services are required. The namespace is explicitly a portfolio test store.

## Limits and integration obligations

Only a monotonic best score can use this merge strategy. **Do not copy it for spendable currency, inventories, or session profiles.** Those need a different ownership and transaction design. This module does not provide autosave, a request queue, budget scheduling, player lifecycle hooks, or shutdown flushing. For gameplay, coalesce submissions and save confirmed milestones; never call it directly on every client event. Reads may be cached; use the successful write's returned record as the immediate confirmation. A returned failure can represent an uncertain write outcome, so retrying the same best score is safe.
