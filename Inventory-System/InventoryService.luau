--!strict
local Inventory = {}
local MAX_SLOTS = 8
local LIMITS: {[string]: number} = table.freeze({ Wood = 50, Stone = 50, Gear = 10 })
export type Bag = {[string]: number}

local function validAmount(amount: number): boolean
	return amount == amount and amount >= 1 and amount <= 10000 and amount % 1 == 0
end

local function slotsUsed(bag: Bag): number
	local slots = 0
	for id, count in bag do
		slots += math.ceil(count / LIMITS[id])
	end
	return slots
end

function Inventory.new(): Bag
	return {}
end

function Inventory.add(bag: Bag, id: string, amount: number): (boolean, string)
	if not LIMITS[id] or not validAmount(amount) then return false, "InvalidItemOrAmount" end
	local nextBag = table.clone(bag)
	nextBag[id] = (nextBag[id] or 0) + amount
	if slotsUsed(nextBag) > MAX_SLOTS then return false, "Full" end
	-- Commit only after checking capacity: never grant a partial stack silently.
	bag[id] = nextBag[id]
	return true, "Added"
end

function Inventory.remove(bag: Bag, id: string, amount: number): (boolean, string)
	if not LIMITS[id] or not validAmount(amount) then return false, "InvalidItemOrAmount" end
	local available = bag[id] or 0
	if available < amount then return false, "InsufficientItems" end
	local remaining = available - amount
	bag[id] = if remaining == 0 then nil else remaining
	return true, "Removed"
end

function Inventory.snapshot(bag: Bag): Bag
	return table.clone(bag)
end

return table.freeze(Inventory)
