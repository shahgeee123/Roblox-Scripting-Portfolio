--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grid = require(ReplicatedStorage:WaitForChild("GridUtil"))

-- Demo bootstrap: generated assets keep this example self-contained.
local remote = Instance.new("RemoteEvent")
remote.Name = "RequestPlacement"
remote.Parent = ReplicatedStorage
local plots = Instance.new("Folder")
plots.Name = "PortfolioPlots"
plots.Parent = workspace

type Session = { plot: Part, objects: Folder, lastRequest: number, count: number }
local sessions: {[Player]: Session} = {}
local nextSlot = 0

local function addPlayer(player: Player)
	if sessions[player] then return end
	nextSlot += 1
	local plot = Instance.new("Part")
	plot.Name = tostring(player.UserId)
	plot.Anchored = true
	plot.Size = Vector3.new(36, 1, 36)
	plot.Position = Vector3.new((nextSlot - 1) * 44, 0, 0)
	plot.Color = Color3.fromRGB(63, 85, 73)
	plot.Parent = plots
	local objects = Instance.new("Folder")
	objects.Name = "PlacedObjects"
	objects.Parent = plot
	sessions[player] = { plot = plot, objects = objects, lastRequest = -math.huge, count = 0 }
end

Players.PlayerAdded:Connect(addPlayer)
for _, player in Players:GetPlayers() do addPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then session.plot:Destroy() end
	sessions[player] = nil
end)

remote.OnServerEvent:Connect(function(player: Player, x: any, z: any, turn: any)
	local session = sessions[player]
	if not session then return end
	local now = os.clock()
	if now - session.lastRequest < 0.15 then return end
	session.lastRequest = now
	if not Grid.isInteger(x) or not Grid.isInteger(z) or not Grid.isInteger(turn) then return end
	if turn < 0 or turn > 3 or session.count >= 64 then return end
	if not Grid.fits(session.plot, x, z) then return end

	local target = Grid.toCFrame(session.plot, x, z, turn)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {session.objects}
	-- Slightly shrink query extents so adjacent faces are not collisions.
	if #workspace:GetPartBoundsInBox(target, Vector3.new(3.9, 3.9, 3.9), params) > 0 then return end

	-- No yield between validation and insertion: requests cannot interleave here.
	local block = Instance.new("Part")
	block.Name = "DemoCrate"
	block.Size = Vector3.new(4, 4, 4)
	block.Anchored = true
	block.CFrame = target
	block.Color = Color3.fromRGB(220, 165, 86)
	block.TopSurface = Enum.SurfaceType.Smooth
	block.Parent = session.objects
	session.count += 1
end)
