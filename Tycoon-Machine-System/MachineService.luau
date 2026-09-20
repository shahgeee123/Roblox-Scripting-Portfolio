--!strict
local MachineService = {}
export type State = { coins: number, level: number, remainder: number }
local INTERVAL = 2
local MAX_LEVEL = 10
local MAX_COINS = 1_000_000_000

function MachineService.new(): State
	return { coins = 0, level = 1, remainder = 0 }
end

function MachineService.advance(state: State, delta: number): number
	if delta ~= delta or delta <= 0 or delta == math.huge then return 0 end
	-- Cap catch-up; this sample deliberately does not award offline production.
	state.remainder += math.min(delta, 10)
	local ticks = math.floor(state.remainder / INTERVAL)
	state.remainder -= ticks * INTERVAL
	local earned = math.min(ticks * state.level * 5, MAX_COINS - state.coins)
	state.coins += earned
	return earned
end

function MachineService.upgrade(state: State): (boolean, string)
	if state.level >= MAX_LEVEL then return false, "MaxLevel" end
	local price = 50 * state.level * state.level
	if state.coins < price then return false, "InsufficientCoins" end
	-- Atomic within this non-yielding operation. Never accept price from a client.
	state.coins -= price
	state.level += 1
	return true, "Upgraded"
end

function MachineService.snapshot(state: State): State
	return table.clone(state)
end

return table.freeze(MachineService)
