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

function BulletCaster.new(startPos, direction, speed, range, ignoreList, onHitCallback,player, firedGun, bullet) --create a new class for the bullet
	local self = setmetatable({}, BulletCaster)
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


function BulletCaster:CreateTracer(origin, direction,gun) --creates a tracer for the client
	local tracer = TracerPool:GetTracer() --Gets a bullet from the tracer pool for less lag
	if origin and direction then
		tracer.CFrame = CFrame.new(origin,origin + direction) * CFrame.new(0, 0, -0.5) 
	else
		tracer.CFrame = CFrame.new(self.Position , self.Position + self.Direction) * CFrame.new(0,0,0.5)
	end
	tracer.Parent = workspace
	local size = tracer.Size

	return tracer
end

function BulletCaster:CreateBullet(gun)-- creates bullet based  on dimensions specified on the weapon
	local BulletD = gun:GetAttribute("BDimensions") or gun:FindFirstChild("BulletChamber"):FindFirstChild("Bullet"):GetAttribute("Dimensions")
	local Bullet
	for _,bullet in ipairs(BulletsFolder:GetChildren()) do
		if bullet:GetAttribute("Dimensions") ~= BulletD then continue end
		Bullet = bullet:Clone()
		Bullet.Transparency = 0
		Bullet.Anchored = 1
		Bullet.CanCollide = false
		Bullet.CanQuery = false
		Bullet.Position = gun:FindFirstChild("Muzzle").Position
		break
	end
	return Bullet
end

function BulletCaster:MakeBulletPassBy(startPos,endPos,head) -- This function checks if a bullet passes a player to create a pass by Sound FX
	local headPos = head.Position -- this function runs on all clients  when a bullet is fired
	local function FindClosestPointOnLine()
		local direction = endPos - startPos
		local t = ((headPos- startPos):Dot(direction)/(direction:Dot(direction)))
		t = math.clamp(t, 0,1)
		return startPos+direction*t
	end
	local closestPoint = FindClosestPointOnLine()
	local distance = (closestPoint-headPos).Magnitude
	local maxDist = 3
	if distance > maxDist then return end
	
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

function BulletCaster:CastTracer(origin, direction, gun,hitPosition)--creates tracer for the client 
	local muzzleOrigin = gun:FindFirstChild("Muzzle").CFrame.Position 
	local tracer = self:CreateTracer(muzzleOrigin, direction, gun)
	if not tracer then return end
	print("Creating tracer")
	local player = game.Players.LocalPlayer
	local head = player.Character:WaitForChild("Head")
	BulletCaster:MakeBulletPassBy(origin,hitPosition, head)
	
	local tweenInfo  = TweenInfo.new(.1, Enum.EasingStyle.Linear)
	local goal = {Position = hitPosition}
	
	local Tween = TweenService:Create(tracer, tweenInfo,goal) --uses tweens to create the bullet tracer as its more optimized than simulating it like on the server (believe me i tried)
	Tween:Play()
	
	tracer.Trail.Enabled = true
	Tween.Completed:Once(function()
		TracerPool:ReturnTracer(tracer) --Return the tracer to the tracer pool for optimization
	end)
end

function BulletCaster:CastRocket(DataPacket) -- casts rocket for the rocket launcher
	local velocity = DataPacket["Direction"] * DataPacket["Speed"]
	local position = DataPacket["Position"]
	local nextPos = position
	local Range = DataPacket["Range"]
	local RunCon
	local DistanceTraveled = 0
	local Direction = DataPacket["Direction"]
	local Bullet = BulletCaster:CreateBullet(DataPacket["Gun"]) --Gets all the Data from the data packet received
	
	local RayCastInfo = OverlapParams.new()
	RayCastInfo.FilterType = Enum.RaycastFilterType.Exclude
	RayCastInfo.FilterDescendantsInstances = DataPacket["IgnoreList"]
	Bullet.Parent = workspace
	
	RunCon = RunService.RenderStepped:Connect(function(dt)
		nextPos = position + velocity * dt
		
		local DebugPart = Instance.new("Part")
		DebugPart.Anchored = true
		DebugPart.CanCollide = false
		DebugPart.CanQuery = false
		DebugPart.CFrame = CFrame.new(position,position + Direction)
		DebugPart.Size = Vector3.new(1,1,7)
		DebugPart.Parent = workspace
		game.Debris:AddItem(DebugPart,3)
		Bullet.CFrame = CFrame.new(position,position + Direction)
		
		local Boundings = workspace:GetPartBoundsInBox(CFrame.new(position, position + Direction), Vector3.new(1,1,5), RayCastInfo)
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
	
	task.delay(15, function()
		if Bullet then Bullet:Destroy() end
	end)
	
end

function BulletCaster:StartTravel()
	local velocity = self.Direction * self.Speed
	
	local nextPos = self.Position
	local RunCon 
	
	local RayCastInfo = OverlapParams.new()
	RayCastInfo.FilterType = Enum.RaycastFilterType.Exclude
	RayCastInfo.FilterDescendantsInstances = self.IgnoreList
	
	local params = RaycastParams.new() 
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self.IgnoreList

	local result = workspace:Raycast(self.Position, self.Direction * self.Range , params)
	local lookVector = Vector3.new(0,0,0)
	
	if result.Instance then
		lookVector = result.Instance.Position
	end
	if self.Gun:FindFirstChild("Bullet") then self.Gun:FindFirstChild("Bullet").Transparency = 1 end
	
	RunCon = RunService.Heartbeat:Connect(function(dt)
		nextPos = self.Position + velocity * dt --Gets the next position of the bullet
		
		local DebugPart = Instance.new("Part")-- debug part
		DebugPart.Anchored = true
		DebugPart.CanCollide = false
		DebugPart.CanQuery = false
		DebugPart.CFrame = CFrame.new(self.Position,self.Position + self.Direction)
		DebugPart.Size = Vector3.new(1,1,5)
		DebugPart.Parent = workspace
		game.Debris:AddItem(DebugPart,3)
		
		local Boundings = workspace:GetPartBoundsInBox(CFrame.new(self.Position, self.Position + self.Direction), Vector3.new(.5,.5,5), RayCastInfo) --gets all parts intersecting the bullet at the current position
		if #Boundings >= 1 then
			--print(Boundings[1])
			RunCon:Disconnect()
			self.OnHit(Boundings[1],self.Position)
			return
		end
		self.DistanceTraveled += (nextPos - self.Position).Magnitude --checks the distance that the bullet travelled so far
		
		if self.DistanceTraveled >= self.Range then
			RunCon:Disconnect()
			self.Alive = false
			self.OnHit(nil)
			return
		end
		self.Position = nextPos
	end)
	local DataPacket = {
		["Position"] = self.Position,
		["Direction"] = self.Direction,
		["IgnoreList"] = self.IgnoreList,
		["Speed"] = self.Speed,
		["Gun"] = self.Gun,
		["Range"] = self.Range
	} --creates a data pack to send to the clients

	for _, plr in ipairs(game.Players:GetPlayers()) do
		if plr ~= self.player then --fires to every client except the owner of the weapon or bullet i guess
			CastTravel:FireClient(plr, DataPacket)
		end
	end
end

function BulletCaster:StartRay()-- casts a ray on the server
	local velocity = self.Direction * self.Speed

	local gravity = Vector3.new(0, -workspace.Gravity + 160, 0) 
	local muzzle = self.Gun:FindFirstChild("Muzzle")

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = self.IgnoreList

	local touchingParts = workspace:GetPartsInPart(muzzle, overlapParams)-- verifys if the player has the weapon in like a wall or any rigid object that has collision

	if #touchingParts > 0 then return end
	
	local params = RaycastParams.new() 
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = self.IgnoreList
	
	local result = workspace:Raycast(self.Position, self.Direction * self.Range , params)
	
	local distance = self.Direction.Magnitude
	print( distance)
	local midpoint = self.Position + self.Direction.Unit * (distance / 2)

    local part = Instance.new("Part") --debug part
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = Vector3.new(0.1, 0.1, self.Range)
	part.CFrame = CFrame.new(midpoint, self.Position + self.Direction)
	part.BrickColor = BrickColor.Red()
	part.Material = Enum.Material.Neon
	part.Parent = workspace 
	
	game.Debris:AddItem(part , 5)
 
	local finalPos
	if result then
		self.Alive = false
		self.OnHit(result)
		finalPos = result.Position
	else
		finalPos = self.Direction * self.Range
	end
	
	for _, plr in ipairs(game.Players:GetPlayers()) do --fires for every player except the owner
		if plr ~= self.player then
			print(plr)
			CastTracer:FireClient(plr, self.Position, self.Direction,self.Gun,finalPos)
		end
	end
end
return BulletCaster
