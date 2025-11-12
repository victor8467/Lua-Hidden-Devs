local RunService = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PLRService = game:GetService("Players")

local TracerPool = require(RepStorage.Modules.weapons.BulletCaster.TracerPool)

local bulletSounds = RepStorage.GunEffects.GenericSounds
local CastTracer = RepStorage.Events.Remote.Guns.CastBullet
local CastTravel = RepStorage.Events.Remote.Guns.CastTravel
local BulletsFolder = RepStorage.VFX.Bullets

local BulletCaster = {}
BulletCaster.__index = BulletCaster

-- WHY: Each bullet cast instance represents a single fired shot
-- This object-based design allows multiple bullets to be simulated independently with different speeds, range, and callbacks

function BulletCaster.new(startPos, direction, speed, range, ignoreList, onHitCallback, player, firedGun, bullet)
	local self = setmetatable({}, BulletCaster)

	-- WHY: Store projectile state locally instead of globals so that multiple bullets don’t interfere with each other.
	self.Position = startPos
	self.Direction = direction
	self.Speed = speed
	self.Range = range
	self.DistanceTraveled = 0
	self.IgnoreList = ignoreList or {}
	self.OnHit = onHitCallback or function() end
	self.Alive = true
	self.player = player
	self.Gun = firedGun
	self.Bullet = bullet
	return self
end


-- WHY: Tracers are reused instead of created/destroyed every shot, reusing prevents memory churn and GC lag when firing rapidly. This function is only ran on the client because it prevents lag
function BulletCaster:CreateTracer(origin, direction)
	local tracer = TracerPool:GetTracer()

	-- WHY: The tracers CFrame is offset slightly backwards, in my case (-0.5) so it visually starts at the muzzle rather than clipping through it.
	if origin and direction then
		tracer.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -0.5)
	else
		tracer.CFrame = CFrame.new(self.Position, self.Position + self.Direction) * CFrame.new(0, 0, 0.5)
	end

	tracer.Parent = workspace
	return tracer
end

-- WHY: Instead of creating a generic bullet, this function matches bullet dimensions to the weapon. It helps ensure consistent scaling between gun types (sniper or pistol or AR). Anyway, every gun has those dimensions. 
function BulletCaster:CreateBullet(gun)
	local BulletD = gun:GetAttribute("BDimensions")
		or gun:FindFirstChild("BulletChamber"):FindFirstChild("Bullet"):GetAttribute("Dimensions")

	local Bullet
	for _, bullet in ipairs(BulletsFolder:GetChildren()) do
		if bullet:GetAttribute("Dimensions") ~= BulletD then continue end
		Bullet = bullet:Clone()
		Bullet.Transparency = 0
		Bullet.Anchored = true
		Bullet.CanCollide = false
		Bullet.CanQuery = false
		Bullet.Position = gun:FindFirstChild("Muzzle").Position
		break
	end
	return Bullet
end

-- WHY: This simulates the auditory feedback when a bullet passes close to a players head. Its not random ,its based on actual spatial proximity to make gunfire feel more immersive and reactive.

function BulletCaster:MakeBulletPassBy(startPos, endPos, head)
	local headPos = head.Position

	-- WHY: This projection finds the closest point along the bullets trajectory to the head, rather than using distance checks. And in general its more responsive than distance checks.
	local function FindClosestPointOnLine()
		local direction = endPos - startPos
		local t = ((headPos - startPos):Dot(direction) / (direction:Dot(direction)))
		t = math.clamp(t, 0, 1)
		return startPos + direction * t
	end

	local closestPoint = FindClosestPointOnLine()
	local distance = (closestPoint - headPos).Magnitude

	-- WHY: Limit to small radius so than not every nearby bullet triggers sound
	local maxDist = 3
	if distance > maxDist then return end

	-- WHY: Randomize the sound slightly to avoid repetition because it becomes annoying at one point
	local bulletPasses = bulletSounds.BulletPassingBy
	local rndNum = math.random(0, #bulletPasses:GetChildren())

	local passSfx
	for i, sfx in ipairs(bulletPasses:GetChildren()) do
		if i ~= rndNum then continue end
		passSfx = sfx:Clone()
		break
	end
	if not passSfx then return end

	passSfx.Parent = head
	passSfx:Destroy()
end


-- WHY: Tracer tweens give visual feedback of bullet travel. Even if the bullet logic is server-side, tweened tracers make weapons "feel" responsive with minimal network cost. I find this a great way to make predictions
function BulletCaster:CastTracer(origin, direction, gun, hitPosition)
	local muzzleOrigin = gun:FindFirstChild("Muzzle").CFrame.Position
	local tracer = self:CreateTracer(muzzleOrigin, direction, gun)
	if not tracer then return end

	local player = game.Players.LocalPlayer
	local head = player.Character:WaitForChild("Head")
	BulletCaster:MakeBulletPassBy(origin, hitPosition, head)

	-- WHY: Tweening avoids physics overhead, making tracers smooth
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear)
	local goal = { Position = hitPosition }

	local Tween = TweenService:Create(tracer, tweenInfo, goal)
	Tween:Play()
	tracer.Trail.Enabled = true

	Tween.Completed:Once(function()
		-- WHY: To return the tracer to the tracer pool. This avoids allocating memory for a new tracer next time is created
		TracerPool:ReturnTracer(tracer)
	end)
end


-- WHY: Rockets are simulated continuously because they move slower than hitscan bullets, and can collide mid-flight.
function BulletCaster:CastRocket(DataPacket)
	local velocity = DataPacket["Direction"] * DataPacket["Speed"]
	local position = DataPacket["Position"]
	local nextPos = position
	local Range = DataPacket["Range"]
	local RunCon
	local DistanceTraveled = 0
	local Direction = DataPacket["Direction"]
	local Bullet = BulletCaster:CreateBullet(DataPacket["Gun"])

	local RayCastInfo = OverlapParams.new()
	RayCastInfo.FilterType = Enum.RaycastFilterType.Exclude
	RayCastInfo.FilterDescendantsInstances = DataPacket["IgnoreList"]
	Bullet.Parent = workspace

	RunCon = RunService.RenderStepped:Connect(function(dt)
		-- WHY: Compute movement using frame time to ensure consistent motion across FPS differences
		nextPos = position + velocity * dt

		-- WHY: Debug parts help visualize trajectory for dev tuning
		local DebugPart = Instance.new("Part")
		DebugPart.Anchored = true
		DebugPart.CanCollide = false
		DebugPart.CanQuery = false
		DebugPart.CFrame = CFrame.new(position, position + Direction)
		DebugPart.Size = Vector3.new(1, 1, 7)
		DebugPart.Parent = workspace
		game.Debris:AddItem(DebugPart, 3)

		Bullet.CFrame = CFrame.new(position, position + Direction)

		-- WHY: GetPartBoundsInBox is cheaper than full raycast for large projectiles
		local Boundings = workspace:GetPartBoundsInBox(
			CFrame.new(position, position + Direction),
			Vector3.new(1, 1, 5),
			RayCastInfo
		)

		if #Boundings >= 1 then
			RunCon:Disconnect()
			Bullet:Destroy()
			return
		end

		DistanceTraveled += (nextPos - position).Magnitude
		if DistanceTraveled >= Range then
			RunCon:Disconnect()
			Bullet:Destroy()
			return
		end

		position = nextPos
	end)

	-- WHY: Cleanup safety timeout in case rocket never hits anything
	task.delay(15, function()
		if Bullet then Bullet:Destroy() end
	end)
end

-- WHY: This handles bullets that travel continuously (like fast projectiles) instead of instant hitscan. It uses OverlapParams to cheaply check impacts. This function is only server-side
function BulletCaster:StartTravel()
	local velocity = self.Direction * self.Speed
	local nextPos = self.Position
	local RunCon

	local RayCastInfo = OverlapParams.new()
	RayCastInfo.FilterType = Enum.RaycastFilterType.Exclude
	RayCastInfo.FilterDescendantsInstances = self.IgnoreList

	if self.Gun:FindFirstChild("Bullet") then
		self.Gun:FindFirstChild("Bullet").Transparency = 1
	end

	RunCon = RunService.Heartbeat:Connect(function(dt)
		-- WHY: Update movement incrementally so it can detect collisions mid-flight
		nextPos = self.Position + velocity * dt

		local DebugPart = Instance.new("Part")
		DebugPart.Anchored = true
		DebugPart.CanCollide = false
		DebugPart.CanQuery = false
		DebugPart.CFrame = CFrame.new(self.Position, self.Position + self.Direction)
		DebugPart.Size = Vector3.new(1, 1, 5)
		DebugPart.Parent = workspace
		game.Debris:AddItem(DebugPart, 3)

		local Boundings = workspace:GetPartBoundsInBox(
			CFrame.new(self.Position, self.Position + self.Direction),
			Vector3.new(0.5, 0.5, 5),
			RayCastInfo
		)

		-- WHY: Immediately trigger hit callback and stop sim once a collision is found so that if it hits a player it does whatever the callback is
		if #Boundings >= 1 then
			RunCon:Disconnect()
			self.OnHit(Boundings[1], self.Position)
			return
		end

		self.DistanceTraveled += (nextPos - self.Position).Magnitude
		if self.DistanceTraveled >= self.Range then
			RunCon:Disconnect()
			self.Alive = false
			self.OnHit(nil)
			return
		end

		self.Position = nextPos
	end)

	-- WHY: Tell all other clients except the owner to show bullet travel locally using the cast tracer functiom, reducing server load and ensuring smoother visuals
	local DataPacket = {
		["Position"] = self.Position,
		["Direction"] = self.Direction,
		["IgnoreList"] = self.IgnoreList,
		["Speed"] = self.Speed,
		["Gun"] = self.Gun,
		["Range"] = self.Range
	}

	for _, plr in ipairs(game.Players:GetPlayers()) do
		if plr ~= self.player then
			CastTravel:FireClient(plr, DataPacket)
		end
	end
end

-- WHY: This version uses a single raycast to find impact instantly. Ideal for hitscan weapons (snipers, rifles) that don’t simulate travel. Every weapon either uses the Start ray or start travel function or the rocket of course
function BulletCaster:StartRay()
	local velocity = self.Direction * self.Speed

	-- WHY: Reduce gravity a bit for short-range weapons to avoid bullet drop feel
	local gravity = Vector3.new(0, -workspace.Gravity + 160, 0)
	local muzzle = self.Gun:FindFirstChild("Muzzle")

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = self.IgnoreList

	local touchingParts = workspace:GetPartsInPart(muzzle, overlapParams)
	if #touchingParts > 0 then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self.IgnoreList

	local result = workspace:Raycast(self.Position, self.Direction * self.Range, params)
	local distance = self.Direction.Magnitude
	local midpoint = self.Position + self.Direction.Unit * (distance / 2)

	-- WHY: Visual debug line to confirm accuracy of hitscan logic
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = Vector3.new(0.1, 0.1, self.Range)
	part.CFrame = CFrame.new(midpoint, self.Position + self.Direction)
	part.BrickColor = BrickColor.Red()
	part.Material = Enum.Material.Neon
	part.Parent = workspace
	game.Debris:AddItem(part, 5)

	local finalPos
	if result then
		self.Alive = false
		self.OnHit(result)
		finalPos = result.Position
	else
		finalPos = self.Direction * self.Range
	end

	for _, plr in ipairs(game.Players:GetPlayers()) do
		if plr ~= self.player then
			CastTracer:FireClient(plr, self.Position, self.Direction, self.Gun, finalPos)
		end
	end
end

return BulletCaster
