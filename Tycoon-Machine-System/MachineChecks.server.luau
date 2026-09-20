--!strict
local Machines = require(script.Parent.MachineService)
local machine = Machines.new()
assert(Machines.advance(machine, 1) == 0)
assert(Machines.advance(machine, 1) == 5)
assert(not Machines.upgrade(machine))
assert(machine.coins == 5 and machine.level == 1)
Machines.advance(machine, 10)
Machines.advance(machine, 10)
assert(machine.coins == 55)
assert(Machines.upgrade(machine))
assert(machine.coins == 5 and machine.level == 2)
assert(Machines.advance(machine, 1000) == 50) -- capped at ten seconds
local copy = Machines.snapshot(machine)
copy.coins = 0
assert(machine.coins == 55)
assert(Machines.advance(machine, 0 / 0) == 0)
print("Machine checks passed")
