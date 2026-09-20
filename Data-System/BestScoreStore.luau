--!strict
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PortfolioBestScores_v1")
local Scores = {}
local MAX_SCORE = 1_000_000_000
type Record = { Version: number, BestScore: number }

local function integerInRange(value: any, minimum: number, maximum: number): boolean
	return typeof(value) == "number" and value == value
		and value >= minimum and value <= maximum and value % 1 == 0
end

local function keyFor(userId: number): string
	assert(integerInRange(userId, 1, 9_007_199_254_740_991), "Invalid user ID")
	return "player_" .. tostring(userId)
end

local function decode(raw: any): Record
	if raw == nil then return { Version = 2, BestScore = 0 } end
	assert(typeof(raw) == "table", "Malformed score record")
	-- Explicit migration of the older Score field; future schemas fail closed.
	assert(raw.Version == 1 or raw.Version == 2, "Unsupported score schema")
	local score = if raw.Version == 1 then raw.Score else raw.BestScore
	assert(integerInRange(score, 0, MAX_SCORE), "Malformed best score")
	return { Version = 2, BestScore = score }
end

local function retry(operation: () -> any): (boolean, any)
	local lastError: any = "No attempt made"
	for attempt = 1, 4 do
		local ok, result = pcall(operation)
		if ok then return true, result end
		lastError = result
		if attempt < 4 then
			task.wait(0.5 * 2 ^ (attempt - 1) + math.random() * 0.2)
		end
	end
	return false, tostring(lastError)
end

function Scores.load(userId: number): (boolean, any)
	local key = keyFor(userId)
	return retry(function()
		return decode(store:GetAsync(key))
	end)
end

function Scores.submit(userId: number, score: number): (boolean, any)
	local key = keyFor(userId)
	assert(integerInRange(score, 0, MAX_SCORE), "Invalid score")
	return retry(function()
		return store:UpdateAsync(key, function(raw: any)
			local record = decode(raw)
			-- Pure, non-yielding and idempotent even if Roblox reruns the callback.
			record.BestScore = math.max(record.BestScore, score)
			return record
		end)
	end)
end

return table.freeze(Scores)
