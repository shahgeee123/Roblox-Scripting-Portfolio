-- Discord: StackedVault | Roblox: VaultStacked
--[[
	Vault Guardian
	Server Script: put it in ServerScriptService and press Play. An empty Baseplate is enough,
	the script builds everything it needs.

	The idea
	A hovering security drone guards a present inside a walled vault. Players sneak in, hold E on
	the present to steal it and try to carry it over the green exit line. The drone patrols around
	the pedestal and notices a thief through a view cone, a hearing radius and a line-of-sight ray.
	After a short head start it chases: it aims at where the thief is going rather than where they
	are, steers around pillars, and when the gap is right it leaps on a real ballistic arc to the
	spot the thief will be when it lands. A catch knocks the thief back and returns the present;
	escaping scores a steal on the leaderboard.

	How the file is organised (each section only uses the sections above it)
	  1. Config      every tunable value in one frozen table
	  2. Helpers     instance creation, flat vectors, character lookup, welding models together
	  3. Math        intercept time (quadratic), lead prediction, ballistic launch velocity
	  4. Cleaner     small metatable class that undoes connections and instances in one call
	  5. Zone        the vault as an oriented box: zone space, clamping, the exit test
	  6. Arena       builds the floor, walls, pillars, pedestal and exit line
	  7. Loot        the present: pickup prompt, carrying it (weld), sending it home
	  8. Guardian    the drone: physics body, senses, steering and a table-driven state machine
	  9. Bootstrap   connects everything: leaderstats, one Heartbeat loop, the escape check

	Guardian states                                     what moves it on
	  Patrol    circles the pedestal                    sees a thief                 -> Alert
	  Alert     freezes and stares (the head start)     head start is over           -> Chase
	  Chase     leads the thief, steers around cover    thief within leap range      -> Leap
	                                                    thief within catch range     -> Recover
	                                                    lost the thief               -> Search
	  Leap      ballistic jump at the predicted spot    landed                       -> Recover
	  Recover   short pause after a leap or a catch     thief still has the present  -> Chase
	                                                    otherwise                    -> Search
	  Search    sweeps its view where it lost them      spots the thief              -> Chase
	                                                    search time is over          -> Patrol

	Known limit: character movement is client-authoritative on Roblox, so a production version
	would also sanity-check the thief's speed before awarding a steal.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--------------------------------------------------------------------------------------------------
-- 1. CONFIG
-- All tuning lives here so behaviour can change without touching the logic. The table is frozen,
-- so an accidental write like CONFIG.ChaseSpeed = 99 somewhere else errors instead of silently
-- changing the game for everyone.
--------------------------------------------------------------------------------------------------
local CONFIG = table.freeze({
	-- Arena. ZoneCFrame is the centre of the vault floor and its LookVector points out through the
	-- exit, so the whole vault can be moved or turned by editing this one CFrame.
	ZoneCFrame = CFrame.new(0, 0.2, -60) * CFrame.Angles(0, math.pi, 0),
	ZoneSize = Vector3.new(64, 12, 88), -- width, wall height, depth
	PostOffset = Vector2.new(0, 26), -- pedestal position in zone space (x, z)
	PedestalHeight = 2.5,
	Pillars = { Vector2.new(-12, 4), Vector2.new(12, 4), Vector2.new(0, -12), Vector2.new(-18, -26), Vector2.new(18, -26) },
	PillarSize = Vector3.new(5, 12, 5),
	WallMargin = 4, -- the guardian never gets closer than this to a wall or the exit line

	-- Guardian movement
	HoverHeight = 5.5,
	BobHeight = 0.35,
	BobSpeed = 3,
	PatrolRadius = 14,
	PatrolPoints = 8,
	PatrolSpeed = 9,
	ChaseSpeed = 21, -- faster than a walking player (16), so a thief has to use cover or dodge
	ArriveDistance = 2,
	HullRadius = 3, -- radius of the sphere cast that checks whether a direction is blocked
	Lookahead = 7,
	SteerStep = math.rad(20),
	SteerTries = 8, -- 8 steps of 20 degrees: it turns up to 160 degrees each way to get around cover
	MaxLean = math.rad(14),
	MaxLeadTime = 1.2, -- never predict a target further ahead than this many seconds

	-- Guardian senses
	ViewDistance = 60,
	ViewAngle = 100, -- full width of the view cone in degrees
	HearRadius = 9, -- inside this radius a thief is noticed whichever way the drone faces
	HeadStart = 1,
	MemoryTime = 3, -- how long it keeps chasing a thief it can no longer see
	SearchTime = 4,
	SearchSweepAngle = math.rad(70),
	SearchSweepSpeed = 2.2,

	-- Catching and leaping
	CatchDistance = 4.5,
	LeapMinDistance = 12,
	LeapMaxDistance = 26,
	LeapSpeed = 40, -- horizontal speed during a leap
	LeapMinTime = 0.45,
	LeapMaxTime = 0.85,
	LeapCooldown = 4,
	LeapCatchBonus = 2, -- the landing covers a wider area than a normal grab
	LeapRecoverTime = 0.8,
	CatchRecoverTime = 1.5,
	KnockbackSpeed = 55,
	KnockbackLift = 30,
	KnockbackTime = 0.18,

	-- Loot
	CarryOffset = CFrame.new(0, 3.9, 0), -- where the present sits relative to the thief's root part
	RespawnDelay = 3,

	DebugStates = true, -- print every guardian state change to the output
})

local COLORS = table.freeze({
	Floor = Color3.fromRGB(46, 50, 60),
	Wall = Color3.fromRGB(72, 76, 88),
	Pillar = Color3.fromRGB(96, 101, 114),
	Exit = Color3.fromRGB(80, 255, 140),
	Pedestal = Color3.fromRGB(225, 225, 232),
	Present = Color3.fromRGB(220, 60, 72),
	Ribbon = Color3.fromRGB(255, 205, 80),
	Hull = Color3.fromRGB(38, 42, 52),
	Trim = Color3.fromRGB(122, 130, 148),
})

--------------------------------------------------------------------------------------------------
-- 2. HELPERS
--------------------------------------------------------------------------------------------------

-- Creates an instance from a property table. Parent is applied last on purpose: parenting first
-- would replicate a half-built instance and then send every following property change on its own.
local function create(className: string, properties: { [string]: any }): any
	local instance = Instance.new(className)
	for property, value in properties do
		if property ~= "Parent" then
			(instance :: any)[property] = value
		end
	end
	instance.Parent = properties.Parent
	return instance
end

-- Drops the vertical component. Steering, facing and catch distances all work on the ground plane
-- because the drone hovers at a different height from the players it chases.
local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

-- A player's root part, but only while their character is alive. The humanoid comes back as a
-- second value for the callers that need to listen to it.
local function getRootPart(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and humanoid.RootPart then
		return humanoid.RootPart, humanoid
	end
	return nil, nil
end

type PartSpec = {
	Name: string,
	Size: Vector3,
	Offset: CFrame, -- relative to the root part the piece gets welded to
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
}

-- Builds decorative pieces from specs and welds them to `root`, so a whole model moves as one
-- assembly driven by whatever moves the root. The pieces are massless and never collide, so they
-- change how a model looks but never how it moves. The drone and the present are both built here.
local function weldParts(root: BasePart, specs: { PartSpec }, parent: Instance): { [string]: BasePart }
	local parts = {}
	for _, spec in specs do
		local part = create("Part", {
			Name = spec.Name,
			Shape = spec.Shape or Enum.PartType.Block,
			Size = spec.Size,
			CFrame = root.CFrame * spec.Offset,
			Color = spec.Color,
			Material = spec.Material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			Parent = parent,
		})
		create("WeldConstraint", { Part0 = root, Part1 = part, Parent = part })
		parts[spec.Name] = part
	end
	return parts
end

--------------------------------------------------------------------------------------------------
-- 3. MATH
--------------------------------------------------------------------------------------------------

-- Earliest time t > 0 at which something moving at `speed` can meet a target that starts `offset`
-- away and keeps moving with `velocity`. Meeting means |offset + velocity * t| = speed * t, and
-- squaring both sides turns that into the quadratic
--     (v.v - s^2) t^2 + 2 (offset.v) t + offset.offset = 0
-- Returns nil when there is no meeting point (the target is faster and running away).
local function solveInterceptTime(offset: Vector3, velocity: Vector3, speed: number): number?
	local a = velocity:Dot(velocity) - speed * speed
	local b = 2 * offset:Dot(velocity)
	local c = offset:Dot(offset)
	if math.abs(a) < 1e-6 then
		-- Equal speeds: the t^2 term vanishes and only a target coming towards us can be met.
		return if b < 0 then -c / b else nil
	end
	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then
		return nil
	end
	local root = math.sqrt(discriminant)
	local early = math.min((-b - root) / (2 * a), (-b + root) / (2 * a))
	local late = math.max((-b - root) / (2 * a), (-b + root) / (2 * a))
	-- The earlier meeting wins unless it is in the past.
	local t = if early > 0 then early else late
	return if t > 0 then t else nil
end

-- Where to aim to cut a target off instead of trailing behind it: the target's position pushed
-- along its ground velocity by the intercept time. The lead is capped at MaxLeadTime so a noisy
-- velocity reading can't send the drone to the far side of the vault.
local function predictPosition(from: Vector3, targetPosition: Vector3, targetVelocity: Vector3, speed: number): Vector3
	local velocity = flat(targetVelocity)
	local leadTime = solveInterceptTime(flat(targetPosition - from), velocity, speed) or 0
	return targetPosition + velocity * math.min(leadTime, CONFIG.MaxLeadTime)
end

-- Launch velocity that carries a body from `from` to `to` in exactly `flightTime` seconds under
-- gravity. Rearranging the projectile equation  to = from + v0*t + 0.5*g*t^2  for v0 gives
--     v0 = (to - from) / t - 0.5*g*t
local function ballisticVelocity(from: Vector3, to: Vector3, flightTime: number): Vector3
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	return (to - from) / flightTime - gravity * (flightTime / 2)
end

--------------------------------------------------------------------------------------------------
-- 4. CLEANER
-- Collects the things that have to be undone later (connections and instances) and undoes all of
-- them with one call. It is a minimal version of the Maid/Trove pattern used in many Roblox
-- codebases. Loot relies on it so that everything created while a present is being carried goes
-- away the moment the carry ends, however it ends.
--------------------------------------------------------------------------------------------------
local Cleaner = {}
Cleaner.__index = Cleaner

type Cleaner = typeof(setmetatable({} :: { items: { any } }, Cleaner))

function Cleaner.new(): Cleaner
	return setmetatable({ items = {} }, Cleaner)
end

function Cleaner:add(item: any): any
	table.insert(self.items, item)
	return item
end

-- Works backwards (last added, first cleaned) so listeners are disconnected before the instances
-- they were watching get destroyed.
function Cleaner:clean()
	local items = self.items
	for index = #items, 1, -1 do
		local item = items[index]
		items[index] = nil
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		else
			item:Destroy()
		end
	end
end

--------------------------------------------------------------------------------------------------
-- 5. ZONE
-- The vault as an oriented box. CFrame:PointToObjectSpace moves a point into "zone space", where
-- the box is centred on the origin and lined up with the axes, so testing and clamping become
-- simple per-axis comparisons however the vault is rotated in the world.
-- In zone space X runs across the vault, Y is the height above the floor and -Z points out
-- through the exit (the same way as the zone CFrame's LookVector).
--------------------------------------------------------------------------------------------------
local Zone = {}
Zone.__index = Zone

type Zone = typeof(setmetatable({} :: { cframe: CFrame, size: Vector3, half: Vector3 }, Zone))

function Zone.new(cframe: CFrame, size: Vector3): Zone
	return setmetatable({ cframe = cframe, size = size, half = size / 2 }, Zone)
end

function Zone:toWorld(x: number, y: number, z: number): CFrame
	return self.cframe * CFrame.new(x, y, z)
end

-- True once a point is past the exit line, the -Z face of the box.
function Zone:hasEscaped(point: Vector3): boolean
	return self.cframe:PointToObjectSpace(point).Z < -self.half.Z
end

-- Pulls a point inside the vault, at least `margin` studs from every edge, at `height` above the
-- floor. Every goal the drone moves to passes through here, which is what keeps it inside: it can
-- chase a thief right up to the exit line but never past it.
function Zone:project(point: Vector3, margin: number, height: number): Vector3
	local localPoint = self.cframe:PointToObjectSpace(point)
	return self.cframe:PointToWorldSpace(Vector3.new(
		math.clamp(localPoint.X, -self.half.X + margin, self.half.X - margin),
		height,
		math.clamp(localPoint.Z, -self.half.Z + margin, self.half.Z - margin)
	))
end

--------------------------------------------------------------------------------------------------
-- 6. ARENA
-- Everything is positioned in zone space through Zone:toWorld, so the arena follows
-- CONFIG.ZoneCFrame wherever it is placed. Walls and pillars go in an Obstacles folder, which is
-- the only thing the drone's sight rays and steering casts can hit.
--------------------------------------------------------------------------------------------------
type Arena = { folder: Folder, obstacles: Folder, post: CFrame }

local function buildArena(zone: Zone): Arena
	local folder = create("Folder", { Name = "VaultGuardianDemo", Parent = workspace })
	local obstacles = create("Folder", { Name = "Obstacles", Parent = folder })
	local size, half = zone.size, zone.half

	local function block(name: string, blockSize: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance)
		create("Part", {
			Name = name,
			Size = blockSize,
			CFrame = cframe,
			Color = color,
			Material = material,
			Anchored = true,
			Parent = parent,
		})
	end

	block("Floor", Vector3.new(size.X, 0.2, size.Z), zone:toWorld(0, -0.1, 0), COLORS.Floor, Enum.Material.DiamondPlate, folder)
	block("LeftWall", Vector3.new(1, size.Y, size.Z), zone:toWorld(-half.X - 0.5, half.Y, 0), COLORS.Wall, Enum.Material.Concrete, obstacles)
	block("RightWall", Vector3.new(1, size.Y, size.Z), zone:toWorld(half.X + 0.5, half.Y, 0), COLORS.Wall, Enum.Material.Concrete, obstacles)
	block("BackWall", Vector3.new(size.X + 2, size.Y, 1), zone:toWorld(0, half.Y, half.Z + 0.5), COLORS.Wall, Enum.Material.Concrete, obstacles)
	for index, spot in CONFIG.Pillars do
		local pillarCFrame = zone:toWorld(spot.X, CONFIG.PillarSize.Y / 2, spot.Y)
		block(`Pillar{index}`, CONFIG.PillarSize, pillarCFrame, COLORS.Pillar, Enum.Material.Concrete, obstacles)
	end

	create("Part", {
		Name = "ExitLine",
		Size = Vector3.new(size.X, 0.05, 1),
		CFrame = zone:toWorld(0, 0.03, -half.Z),
		Color = COLORS.Exit,
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		Parent = folder,
	})

	-- Cylinders are built along their X axis, so the pedestal is rolled 90 degrees to stand upright.
	local post = zone:toWorld(CONFIG.PostOffset.X, 0, CONFIG.PostOffset.Y)
	create("Part", {
		Name = "Pedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(CONFIG.PedestalHeight, 4, 4),
		CFrame = post * CFrame.new(0, CONFIG.PedestalHeight / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = COLORS.Pedestal,
		Material = Enum.Material.Marble,
		Anchored = true,
		Parent = folder,
	})

	return { folder = folder, obstacles = obstacles, post = post }
end

--------------------------------------------------------------------------------------------------
-- 7. LOOT
-- The present. It sits anchored on the pedestal until someone completes its ProximityPrompt, then
-- it is welded above the thief's head and becomes part of their character. reset() is the only
-- way back to the pedestal and handles catches, escapes, deaths and players leaving alike, so
-- there is exactly one place that has to get the clean-up right.
--------------------------------------------------------------------------------------------------
local PRESENT_SIZE = 2.2
local PRESENT_PARTS: { PartSpec } = {
	{ Name = "RibbonX", Size = Vector3.new(PRESENT_SIZE + 0.1, PRESENT_SIZE + 0.1, 0.45), Offset = CFrame.identity, Color = COLORS.Ribbon },
	{ Name = "RibbonZ", Size = Vector3.new(0.45, PRESENT_SIZE + 0.1, PRESENT_SIZE + 0.1), Offset = CFrame.identity, Color = COLORS.Ribbon },
}

local Loot = {}
Loot.__index = Loot

type Loot = typeof(setmetatable({} :: {
	parent: Instance,
	home: CFrame,
	model: Model,
	box: BasePart,
	prompt: ProximityPrompt,
	carrier: Player?,
	cleaner: Cleaner,
}, Loot))

function Loot.new(arena: Arena): Loot
	local self = setmetatable({}, Loot) :: Loot
	self.parent = arena.folder
	self.home = arena.post * CFrame.new(0, CONFIG.PedestalHeight + PRESENT_SIZE / 2, 0)
	self.carrier = nil
	self.cleaner = Cleaner.new()

	self.model = create("Model", { Name = "Present", ModelStreamingMode = Enum.ModelStreamingMode.Atomic })
	self.box = create("Part", {
		Name = "Box",
		Size = Vector3.one * PRESENT_SIZE,
		CFrame = self.home,
		Color = COLORS.Present,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true, -- rides on the thief without making their character any heavier
		Parent = self.model,
	})
	weldParts(self.box, PRESENT_PARTS, self.model)
	self.prompt = create("ProximityPrompt", {
		ActionText = "Steal",
		ObjectText = "Present",
		HoldDuration = 0.4,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
		Parent = self.box,
	})
	self.model.PrimaryPart = self.box
	self.model.Parent = self.parent

	self.prompt.Triggered:Connect(function(player: Player)
		self:pickUp(player)
	end)
	return self
end

function Loot:pickUp(player: Player)
	local root, humanoid = getRootPart(player)
	if self.carrier or not root or not humanoid then
		return
	end
	local character = root.Parent :: Model
	self.carrier = player
	self.prompt.Enabled = false

	-- Move the present above the thief's head while it is still anchored, weld it to their root
	-- part, and only then unanchor it, so it never has a frame where it could fall off.
	self.model:PivotTo(root.CFrame * CONFIG.CarryOffset)
	self.cleaner:add(create("WeldConstraint", { Part0 = root, Part1 = self.box, Parent = self.box }))
	self.box.Anchored = false

	-- However the thief disappears (dies, respawns, leaves the game) the present goes home.
	self.cleaner:add(humanoid.Died:Connect(function()
		self:reset()
	end))
	self.cleaner:add(character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(workspace) then
			self:reset()
		end
	end))
end

-- Puts the present back on its pedestal. After a successful steal a respawn delay is passed in and
-- the present leaves the world for a moment; parenting the model to nil hides every piece at once.
function Loot:reset(respawnDelay: number?)
	self.cleaner:clean() -- breaks the carry weld and drops the listeners on the last thief
	self.carrier = nil
	self.box.Anchored = true
	self.model:PivotTo(self.home)
	self.prompt.Enabled = true
	if respawnDelay then
		self.model.Parent = nil
		task.delay(respawnDelay, function()
			self.model.Parent = self.parent
		end)
	end
end

--------------------------------------------------------------------------------------------------
-- 8. GUARDIAN
-- Physics: the drone is one unanchored assembly (a ball with welded trim) owned by the server. An
-- AlignPosition pulls it towards a goal point, with MaxVelocity acting as its speed limit, and an
-- AlignOrientation turns it. Movement is smooth, replicates like any physics object, and real
-- gravity takes over when the AlignPosition is switched off for a leap.
--
-- Behaviour: the STATES table further down. Each state has a look (eye colour and icon), an
-- optional enter function that runs once, and an update function that runs every Heartbeat and
-- decides when to switch. A new behaviour is one new entry instead of another branch in a big
-- if-chain.
--------------------------------------------------------------------------------------------------
local GUARDIAN_PARTS: { PartSpec } = {
	{ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 5.3, 5.3), Offset = CFrame.Angles(0, 0, math.pi / 2), Color = COLORS.Trim, Material = Enum.Material.Metal },
	{ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Offset = CFrame.new(0, 0.6, -2.05), Color = COLORS.Trim, Material = Enum.Material.Neon },
	{ Name = "LeftFin", Size = Vector3.new(0.3, 1.4, 2.6), Offset = CFrame.new(-2.9, 0, 0.6) * CFrame.Angles(0, 0, math.rad(25)), Color = COLORS.Trim, Material = Enum.Material.Metal },
	{ Name = "RightFin", Size = Vector3.new(0.3, 1.4, 2.6), Offset = CFrame.new(2.9, 0, 0.6) * CFrame.Angles(0, 0, math.rad(-25)), Color = COLORS.Trim, Material = Enum.Material.Metal },
}

local Guardian = {}
Guardian.__index = Guardian

type GuardianState = {
	color: Color3,
	icon: string,
	enter: ((Guardian, ...any) -> ())?,
	update: (Guardian, number) -> (),
}

type Guardian = typeof(setmetatable({} :: {
	zone: Zone,
	loot: Loot,
	onCatch: (Player) -> (),
	body: BasePart,
	eye: BasePart,
	light: SpotLight,
	indicator: TextLabel,
	mover: AlignPosition,
	turner: AlignOrientation,
	rayParams: RaycastParams,
	viewCos: number,
	route: { Vector3 },
	routeIndex: number,
	steerSide: number,
	state: GuardianState,
	stateName: string,
	stateStarted: number,
	target: Player?,
	lastSeenPosition: Vector3,
	lastSeenVelocity: Vector3,
	lastSeenTime: number,
	nextLeapTime: number,
	leapTime: number,
	leapLanding: Vector3,
	recoverTime: number,
	searchYaw: number,
}, Guardian))

local STATES: { [string]: GuardianState } = {}

-- Patrol waypoints on a circle around the pedestal. Each one comes from turning the post's CFrame
-- around its up axis and stepping out along the turned look direction,
--     post * Angles(0, angle, 0) * (0, 0, -radius)
-- and is then projected into the vault in case the circle pokes through a wall.
local function buildPatrolRoute(zone: Zone, post: CFrame): { Vector3 }
	local route = table.create(CONFIG.PatrolPoints)
	for index = 1, CONFIG.PatrolPoints do
		local angle = index / CONFIG.PatrolPoints * math.pi * 2
		local spoke = post * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -CONFIG.PatrolRadius)
		route[index] = zone:project(spoke.Position, CONFIG.WallMargin, CONFIG.HoverHeight)
	end
	return route
end

function Guardian.new(zone: Zone, arena: Arena, loot: Loot, onCatch: (Player) -> ()): Guardian
	local self = setmetatable({}, Guardian) :: Guardian
	self.zone = zone
	self.loot = loot
	self.onCatch = onCatch
	self.route = buildPatrolRoute(zone, arena.post)
	self.routeIndex = 1
	self.steerSide = 1
	self.nextLeapTime = 0
	self.lastSeenPosition, self.lastSeenVelocity, self.lastSeenTime = Vector3.zero, Vector3.zero, 0
	-- cos(half the view angle) is worked out once; canSee compares dot products against it.
	self.viewCos = math.cos(math.rad(CONFIG.ViewAngle / 2))
	-- One RaycastParams shared by every sight ray and steering cast: only obstacles can block them.
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Include
	self.rayParams.FilterDescendantsInstances = { arena.obstacles }

	self:buildBody(arena.folder, self.route[1])
	self.stateName = "Spawned"
	self:setState("Patrol")
	return self
end

function Guardian:buildBody(parent: Instance, position: Vector3)
	local model = create("Model", { Name = "VaultGuardian", ModelStreamingMode = Enum.ModelStreamingMode.Atomic })
	local body = create("Part", {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 5,
		CFrame = CFrame.new(position),
		Color = COLORS.Hull,
		Material = Enum.Material.Metal,
		CanCollide = false, -- it passes through players instead of shoving them; catches are explicit
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local parts = weldParts(body, GUARDIAN_PARTS, model)
	local attachment = create("Attachment", { Parent = body })

	self.mover = create("AlignPosition", {
		Mode = Enum.PositionAlignmentMode.OneAttachment,
		Attachment0 = attachment,
		Position = position,
		MaxForce = math.huge,
		Responsiveness = 40,
		Parent = body,
	})
	self.turner = create("AlignOrientation", {
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		Attachment0 = attachment,
		MaxTorque = math.huge,
		Responsiveness = 18,
		Parent = body,
	})
	-- The spotlight has the same shape as the view cone, so players can see where the drone looks.
	self.light = create("SpotLight", {
		Face = Enum.NormalId.Front,
		Angle = CONFIG.ViewAngle,
		Range = CONFIG.ViewDistance,
		Brightness = 3,
		Parent = parts.Eye,
	})
	local billboard = create("BillboardGui", {
		Size = UDim2.fromOffset(80, 50),
		StudsOffset = Vector3.new(0, 4.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = body,
	})
	self.indicator = create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextStrokeTransparency = 0,
		Text = "",
		Parent = billboard,
	})

	model.PrimaryPart = body
	model.Parent = parent
	-- Unanchored parts near a player are normally simulated by that player's client. Keeping the
	-- server as the owner means every client sees the same drone and no client can move it.
	body:SetNetworkOwner(nil)
	self.body, self.eye = body, parts.Eye
end

function Guardian:__tostring(): string
	return `Guardian({self.stateName})`
end

function Guardian:setState(name: string, ...: any)
	if CONFIG.DebugStates then
		print(self, "->", name)
	end
	local state = STATES[name]
	self.state, self.stateName, self.stateStarted = state, name, os.clock()
	-- Eye, spotlight and icon all take the state's colour so players can read the drone's mood.
	self.eye.Color = state.color
	self.light.Color = state.color
	self.indicator.TextColor3 = state.color
	self.indicator.Text = state.icon
	if state.enter then
		state.enter(self, ...)
	end
end

function Guardian:update()
	self.state.update(self, os.clock())
end

-- Movement -----------------------------------------------------------------------------------------

-- A slow sine wave on the hover height, so the drone looks airborne even while it holds still.
function Guardian:hoverHeight(now: number): number
	return CONFIG.HoverHeight + math.sin(now * CONFIG.BobSpeed) * CONFIG.BobHeight
end

-- Stops by pinning the goal to where the drone is now; it keeps bobbing in place.
function Guardian:hold(now: number)
	self.mover.Position = self.zone:project(self.body.Position, CONFIG.WallMargin, self:hoverHeight(now))
end

-- Turns the drone to face a direction on the ground plane and tips it forward by up to MaxLean
-- (lean goes from 0 to 1), so speed shows as the drone leaning into its movement.
function Guardian:face(direction: Vector3, lean: number)
	local heading = flat(direction)
	if heading.Magnitude < 1e-3 then
		return
	end
	self.turner.CFrame = CFrame.lookAt(Vector3.zero, heading) * CFrame.Angles(-CONFIG.MaxLean * math.min(lean, 1), 0, 0)
end

-- Returns a direction close to `direction` that the drone's hull can travel `distance` along
-- without touching an obstacle. When the straight line is blocked it fans out in growing angles,
-- trying the side that worked last time first, so it commits to rounding a pillar one way instead
-- of flickering between both sides.
function Guardian:steer(direction: Vector3, distance: number): Vector3
	local origin = self.body.Position
	if not workspace:Spherecast(origin, CONFIG.HullRadius, direction * distance, self.rayParams) then
		return direction
	end
	for step = 1, CONFIG.SteerTries do
		for attempt = 1, 2 do
			local side = if attempt == 1 then self.steerSide else -self.steerSide
			local candidate = CFrame.Angles(0, side * step * CONFIG.SteerStep, 0):VectorToWorldSpace(direction)
			if not workspace:Spherecast(origin, CONFIG.HullRadius, candidate * distance, self.rayParams) then
				self.steerSide = side
				return candidate
			end
		end
	end
	return direction -- boxed in on every side: push on and let the AlignPosition slide it along
end

-- Moves towards `goal` at `speed` and returns the ground distance still left. The AlignPosition is
-- not given the goal itself but a point a few studs ahead in the steered direction (a "carrot"),
-- which is what makes the drone curve around cover while MaxVelocity keeps its speed exact.
function Guardian:moveTo(goal: Vector3, speed: number, now: number): number
	local position = self.body.Position
	local offset = flat(goal - position)
	local distance = offset.Magnitude
	if distance <= CONFIG.ArriveDistance then
		self:hold(now)
		return distance
	end
	local reach = math.min(distance, CONFIG.Lookahead)
	local direction = self:steer(offset / distance, reach)
	self.mover.MaxVelocity = speed
	self.mover.Position = self.zone:project(position + direction * reach, CONFIG.WallMargin, self:hoverHeight(now))
	self:face(direction, speed / CONFIG.ChaseSpeed)
	return distance
end

function Guardian:nearestRouteIndex(): number
	local position = self.body.Position
	local bestIndex, bestDistance = 1, math.huge
	for index, point in self.route do
		local distance = flatDistance(point, position)
		if distance < bestDistance then
			bestIndex, bestDistance = index, distance
		end
	end
	return bestIndex
end

-- Senses ---------------------------------------------------------------------------------------------

-- Hearing, then the view cone, then line of sight, cheapest check first so the raycast only runs
-- for targets that passed everything else.
function Guardian:canSee(root: BasePart): boolean
	local eye = self.eye.Position
	local offset = root.Position - eye
	local distance = offset.Magnitude
	if distance <= CONFIG.HearRadius then
		return true
	end
	if distance > CONFIG.ViewDistance then
		return false
	end
	-- The dot product of two unit vectors is the cosine of the angle between them, so the target is
	-- inside the cone when that dot is at least cos(half the view angle). Both vectors are flattened
	-- so the drone's lean and its hover height don't squeeze the cone.
	local forward = flat(self.body.CFrame.LookVector).Unit
	if forward:Dot(flat(offset).Unit) < self.viewCos then
		return false
	end
	return workspace:Raycast(eye, offset, self.rayParams) == nil
end

-- The thief this drone is locked on to, as long as they are alive and still carry the present.
function Guardian:getTargetRoot(): BasePart?
	if self.target and self.target == self.loot.carrier then
		return (getRootPart(self.target))
	end
	return nil
end

-- Looks for whoever carries the present. On sight it locks on and switches to `nextState`.
function Guardian:spotThief(nextState: string): boolean
	local thief = self.loot.carrier
	local root = thief and getRootPart(thief)
	if root and self:canSee(root) then
		self.target = thief
		self:setState(nextState)
		return true
	end
	return false
end

function Guardian:remember(root: BasePart, now: number)
	self.lastSeenPosition = root.Position
	self.lastSeenVelocity = root.AssemblyLinearVelocity
	self.lastSeenTime = now
end

-- Knocks the thief away and sends the present home. Characters are simulated by their own client,
-- so a velocity set directly by the server would be overwritten. A constraint parented into the
-- character replicates to that client and its physics applies it, so the knockback is a
-- LinearVelocity that lives for a fraction of a second.
function Guardian:catch(root: BasePart)
	local thief = self.target :: Player
	self.loot:reset()
	local away = flat(root.Position - self.body.Position)
	if away.Magnitude < 1e-3 then
		away = flat(self.body.CFrame.LookVector)
	end
	local attachment = create("Attachment", { Parent = root })
	create("LinearVelocity", {
		Attachment0 = attachment,
		MaxForce = math.huge,
		VectorVelocity = away.Unit * CONFIG.KnockbackSpeed + Vector3.yAxis * CONFIG.KnockbackLift,
		Parent = attachment,
	})
	task.delay(CONFIG.KnockbackTime, attachment.Destroy, attachment)
	self.onCatch(thief)
	self:setState("Recover", CONFIG.CatchRecoverTime)
end

-- States ---------------------------------------------------------------------------------------------

STATES.Patrol = {
	color = Color3.fromRGB(90, 200, 255),
	icon = "",
	enter = function(self: Guardian)
		self.target = nil
		self.routeIndex = self:nearestRouteIndex()
	end,
	update = function(self: Guardian, now: number)
		if self:spotThief("Alert") then
			return
		end
		if self:moveTo(self.route[self.routeIndex], CONFIG.PatrolSpeed, now) <= CONFIG.ArriveDistance then
			self.routeIndex = self.routeIndex % #self.route + 1
		end
	end,
}

STATES.Alert = {
	color = Color3.fromRGB(255, 200, 60),
	icon = "!",
	update = function(self: Guardian, now: number)
		local root = self:getTargetRoot()
		if not root then
			self:setState("Search")
			return
		end
		-- Freeze and stare. This pause is the thief's head start.
		self:hold(now)
		self:face(root.Position - self.body.Position, 0)
		if now - self.stateStarted >= CONFIG.HeadStart then
			self:setState("Chase")
		end
	end,
}

STATES.Chase = {
	color = Color3.fromRGB(255, 60, 60),
	icon = "!!",
	enter = function(self: Guardian)
		local root = self:getTargetRoot()
		if root then
			self:remember(root, os.clock())
		end
	end,
	update = function(self: Guardian, now: number)
		local root = self:getTargetRoot()
		if not root then
			self:setState("Search") -- escaped, died or lost the present
			return
		end
		local visible = self:canSee(root)
		if visible then
			self:remember(root, now)
		end

		local distance = flatDistance(root.Position, self.body.Position)
		if distance <= CONFIG.CatchDistance then
			self:catch(root)
			return
		end
		if visible and now >= self.nextLeapTime and distance >= CONFIG.LeapMinDistance and distance <= CONFIG.LeapMaxDistance then
			self:setState("Leap", root)
			return
		end

		-- Chase the predicted position built from the last sighting. While the thief is visible
		-- that is live data; once they slip behind cover the drone keeps going along their last
		-- known heading until it arrives or its memory runs out, and then it searches.
		local goal = predictPosition(self.body.Position, self.lastSeenPosition, self.lastSeenVelocity, CONFIG.ChaseSpeed)
		local remaining = self:moveTo(goal, CONFIG.ChaseSpeed, now)
		if not visible and (remaining <= CONFIG.ArriveDistance or now - self.lastSeenTime > CONFIG.MemoryTime) then
			self:setState("Search")
		end
	end,
}

STATES.Leap = {
	color = Color3.fromRGB(255, 60, 60),
	icon = "!!",
	enter = function(self: Guardian, root: BasePart)
		local start = self.body.Position
		local velocity = flat(root.AssemblyLinearVelocity)
		-- The chase's intercept maths again, solved for the leap's horizontal speed, gives the flight
		-- time after which a thief who keeps running is right under the landing spot.
		local flightTime = solveInterceptTime(flat(root.Position - start), velocity, CONFIG.LeapSpeed) or CONFIG.LeapMaxTime
		flightTime = math.clamp(flightTime, CONFIG.LeapMinTime, CONFIG.LeapMaxTime)
		local landing = self.zone:project(root.Position + velocity * flightTime, CONFIG.WallMargin, CONFIG.HoverHeight)

		-- Hand the body to gravity: the AlignPosition lets go and the launch velocity does the rest.
		-- The AlignOrientation stays on, which keeps the drone upright and tipped into the dive.
		self.mover.Enabled = false
		self.body.AssemblyLinearVelocity = ballisticVelocity(start, landing, flightTime)
		self:face(landing - start, 1)
		self.leapTime, self.leapLanding = flightTime, landing
		self.nextLeapTime = os.clock() + CONFIG.LeapCooldown
	end,
	update = function(self: Guardian, now: number)
		if now - self.stateStarted < self.leapTime then
			return
		end
		-- Landed: cancel the leftover fall speed and give control back to the AlignPosition.
		self.body.AssemblyLinearVelocity = Vector3.zero
		self.mover.Position = self.leapLanding
		self.mover.Enabled = true
		local root = self:getTargetRoot()
		if root and flatDistance(root.Position, self.body.Position) <= CONFIG.CatchDistance + CONFIG.LeapCatchBonus then
			self:catch(root)
			return
		end
		self:setState("Recover", CONFIG.LeapRecoverTime)
	end,
}

STATES.Recover = {
	color = Color3.fromRGB(150, 150, 160),
	icon = "...",
	enter = function(self: Guardian, duration: number)
		self.recoverTime = duration
	end,
	update = function(self: Guardian, now: number)
		self:hold(now)
		if now - self.stateStarted >= self.recoverTime then
			self:setState(if self:getTargetRoot() then "Chase" else "Search")
		end
	end,
}

STATES.Search = {
	color = Color3.fromRGB(190, 120, 255),
	icon = "?",
	enter = function(self: Guardian)
		local _, yaw = self.body.CFrame:ToOrientation()
		self.searchYaw = yaw
	end,
	update = function(self: Guardian, now: number)
		-- No second head start: it already knows who it is looking for.
		if self:spotThief("Chase") then
			return
		end
		self:hold(now)
		-- Sweep the view cone left and right on a sine wave around the way it was facing.
		local elapsed = now - self.stateStarted
		local sweep = math.sin(elapsed * CONFIG.SearchSweepSpeed) * CONFIG.SearchSweepAngle
		self.turner.CFrame = CFrame.Angles(0, self.searchYaw + sweep, 0)
		if elapsed >= CONFIG.SearchTime then
			self:setState("Patrol")
		end
	end,
}

--------------------------------------------------------------------------------------------------
-- 9. BOOTSTRAP
--------------------------------------------------------------------------------------------------
local STAT_NAMES = { "Steals", "Caught" }

local function addLeaderstats(player: Player)
	local leaderstats = create("Folder", { Name = "leaderstats" })
	for _, statName in STAT_NAMES do
		create("IntValue", { Name = statName, Parent = leaderstats })
	end
	leaderstats.Parent = player
end

local function addPoint(player: Player, statName: string)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(statName)
	if stat then
		stat.Value += 1
	end
end

local zone = Zone.new(CONFIG.ZoneCFrame, CONFIG.ZoneSize)
local arena = buildArena(zone)
local loot = Loot.new(arena)
local guardian = Guardian.new(zone, arena, loot, function(thief: Player)
	addPoint(thief, "Caught")
end)

Players.PlayerAdded:Connect(addLeaderstats)
for _, player in Players:GetPlayers() do
	addLeaderstats(player)
end

-- One Heartbeat drives everything: the drone thinks, then the carrier is checked against the exit.
-- Testing the position every frame (instead of a Touched event on the exit line) can't be missed
-- by a fast or lagging character, because it asks "which side of the line are you on", not "did
-- you touch it".
RunService.Heartbeat:Connect(function()
	guardian:update()
	local thief = loot.carrier
	local root = thief and getRootPart(thief)
	if thief and root and zone:hasEscaped(root.Position) then
		addPoint(thief, "Steals")
		loot:reset(CONFIG.RespawnDelay)
	end
end)
