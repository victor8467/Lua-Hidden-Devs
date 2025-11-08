local RepStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollService = game:GetService("CollectionService")
local UGS = UserSettings():GetService("UserGameSettings")
local SoundService = game:GetService("SoundService")


local BulletCaster = require(RepStorage.Modules.weapons.BulletCaster)
local BulletDimensions = require(RepStorage.Lists.Weapon.AmmoDimensions)


local GunEquiped = RepStorage.Events.Remote.Guns.GunEquiped
local GunActivated = RepStorage.Events.Remote.Guns.GunActivated
local CastBullet = RepStorage.Events.Remote.Guns.CastBullet
local ReloadEvent = RepStorage.Events.Remote.Guns.Reload
local CreateRecoilEvent = RepStorage.Events.Bindable.Guns.CreateRecoil
local CastTravel = RepStorage.Events.Remote.Guns.CastTravel

local HitEvent = RepStorage.Events.Remote.Guns.HitSomething


local PlayerBindable = RepStorage.Events.Bindable.Player
--local lockCamera = PlayerBindable.LockCamera
--local unlockCamera = PlayerBindable.UnlockCamera
local toggleCam = PlayerBindable.ToggleLock

local outOfAmmo = RepStorage.GunEffects.GenericSounds.GunSFX.OutOfAmmo
local HeadShot = RepStorage.GunEffects.GenericSounds.GunSFX.Headshot

local GunSFX = RepStorage.SFX.GunSFX
local ScopeOffSFX = GunSFX.ScopeOFF
local ScopeOnSFX = GunSFX.ScopeON
local gunModeSwitchSFX = GunSFX.gunModeSwitch

local HeadHitColor = Color3.new(1,0,0)
local NormalHitColor = Color3.new(1,1,1)

local NormalZoom = 70
local ZoomedIn = 40
local SniperZoom = 10

local gunManager = {}
gunManager.__index = gunManager


function gunManager.new(player)
	local self = setmetatable({},gunManager)
	self.Player = player
	self.Char = player.Character or player.CharacterAdded:Wait()
	self.Hum = self.Char:FindFirstChild("Humanoid")
	self.HRP = self.Char:FindFirstChild("HumanoidRootPart")
	self.Torso = self.Char:FindFirstChild("Torso")
	
	
	self.Hips = {["LeftHip"] = self.Torso:FindFirstChild("Left Hip") ,["RightHip"] = self.Torso:FindFirstChild("Right Hip")}
	
	self.Mouse = player:GetMouse()
	self.Camera = workspace.CurrentCamera
	--General Stuff
	self.Connections = {}
	self.Animations = {}
	self.CurrentGun = nil
	self.Position = nil
	self.Firing = false
	self.DebounceFire = false
	self.Reloading = false
	self.IsAiming = false
	

	self.InaccuracyRate = 0
	self.MaxInaccuracy = 0
	self.Inaccuracy = 0
	self.MovingInaccuracy = 0
	
	self.RecoilCon = nil
	self.TotalRecoil = 0
	self.RecoilPerShot = 2
	
	self.OriginalCameraOffset = 0
	
	self.ShotgunAttributes = {}
	
	
	self.ZoomInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine , Enum.EasingDirection.Out)
	
	
	self.CrossHairMain = player:WaitForChild("PlayerGui"):WaitForChild("WeaponUI"):WaitForChild("CrosshairMain")
	self.Crosshair = self.CrossHairMain:WaitForChild("Crosshair")
	self.HitMarker = self.CrossHairMain:WaitForChild("Hitmarker")
	
	self.HitInInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self.HitOutInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	
	self.WeaponUI = player:WaitForChild("PlayerGui"):WaitForChild("WeaponUI"):WaitForChild("Main"):WaitForChild("GunUI")
	self.Details = self.WeaponUI:WaitForChild("Details")
	self.AmmoTxt = self.Details:WaitForChild("AmmoTxt")
	self.WNameTxt = self.Details:WaitForChild("WeaponName")
	self.WModeTxt = self.Details:WaitForChild("WeaponMode")
	self.WAmmoType = self.Details:WaitForChild("AmmoType")
	
	self.BulletImages = {
		["38 x 9.1mm"] = self.WeaponUI:WaitForChild("Pistol"),
		["9 x 18mm"] = self.WeaponUI:WaitForChild("Pistol"),
		["7.62 x 39mm"] = self.WeaponUI:WaitForChild("Rifle"),
		["18.5 x 70mm"] = self.WeaponUI:WaitForChild("Shotgun"), 
		['7.62 x 54mm'] = self.WeaponUI:WaitForChild("Sniper"),
		['1250 x 90mm'] = self.WeaponUI:WaitForChild("Rocket"),
		["7.65 × 17mm"] = self.WeaponUI:WaitForChild("Pistol"),
	}
	
	
	self.ScopeFrame = player:WaitForChild("PlayerGui"):WaitForChild("WeaponUI"):WaitForChild("ScopeFrame")
	self.ScopeGradient = self.ScopeFrame:WaitForChild("UIGradient")
	self.ScopeImage = self.ScopeFrame:WaitForChild("ScopeImage")
	self.ScopeTween = nil
	
	self.CurrentWeaponMode = nil

	
	self:Init()
	return self
end

function gunManager:ApplyInnacuracy(direction)
	if self.Inaccuracy <= 0 then
		return direction
	end

	local spreadAngle = math.rad(self.Inaccuracy)
	
	local randomAxis = Vector3.new(math.random() - .5,math.random() - .5,math.random() - .5)
	local spreadCFrame = CFrame.fromAxisAngle(randomAxis,spreadAngle)
	local spreadDirection = (spreadCFrame * direction).Unit
	return spreadDirection
end

function gunManager:FireRPG()
	if not self.CurrentGun then return end
	if self.Reloading then return end
	local muzzle = self.CurrentGun:FindFirstChild("Muzzle")
	if not muzzle then return end
	
	
	if self.IsAiming then
		self.Animations["AimShoot"]:Play()
	else
		self.Animations["ShootR6"]:Play()
	end
	if self.Animations["ShootW"] then self.Animations["ShootW"]:Play() end


	local muzzle = self.CurrentGun:FindFirstChild("Muzzle")
	if not muzzle then return end

	local maxDistance = 1500
	local IgnoreList = {self.Player.Character,self.CurrentGun}

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = IgnoreList


	local mouseRay = self.Camera:ViewportPointToRay(self.Camera.ViewportSize.X / 2, self.Camera.ViewportSize.Y / 2)


	local spreadDirection = self:ApplyInnacuracy(mouseRay.Direction)
	local result = workspace:Raycast(mouseRay.Origin, spreadDirection * maxDistance, rayParams)


	local hitPosition
	if result then
		hitPosition = result.Position
	else
		hitPosition = mouseRay.Origin + spreadDirection * maxDistance
	end
	local origin = mouseRay.Origin

	local direction = (hitPosition - origin).Unit


	local muzzleOrigin = muzzle.Position
	local DataPacket = {
		["Position"] = muzzle.Position,
		["Direction"] = direction,
		["IgnoreList"] = IgnoreList,
		["Speed"] = self.CurrentGun:GetAttribute("BulletSpeed") or 1000,
		["Gun"] = self.CurrentGun,
		["Range"] = maxDistance
	}
	
	BulletCaster:CastRocket(DataPacket)

	local serverOrigin = self.Camera.CFrame.Position
	GunActivated:FireServer(direction,serverOrigin)
	CreateRecoilEvent:Fire()	

	local increaseValue = 1
	local moveSpeed = self.Hum.MoveDirection.Magnitude

	if self.IsAiming then
		increaseValue *= .5 
	end
	if moveSpeed > 0 then
		increaseValue *= 2
	end

	self.Inaccuracy = math.clamp(self.Inaccuracy + (self.InaccuracyRate*increaseValue),0 , self.MaxInaccuracy)

	
end


function gunManager:FireShotgun(gun)
	if not self.CurrentGun then return end
	if self.Reloading then return end
	local muzzle = self.CurrentGun:FindFirstChild("Muzzle")
	if not muzzle then return end

	local maxDistance = 1500

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {self.Player.Character}

	local mouseRay = self.Camera:ViewportPointToRay(self.Camera.ViewportSize.X / 2, self.Camera.ViewportSize.Y / 2)


	local spreadDirection = self:ApplyInnacuracy(mouseRay.Direction)
	local result = workspace:Raycast(mouseRay.Origin, spreadDirection * maxDistance, rayParams)


	local hitPosition
	if result then
		hitPosition = result.Position
	else
		hitPosition = mouseRay.Origin + spreadDirection * maxDistance
	end
	local origin = mouseRay.Origin

	local direction = (hitPosition - origin).Unit


	local muzzleOrigin = muzzle.Position
	BulletCaster:CastTracer(muzzleOrigin, direction,gun,hitPosition)

	local serverOrigin = self.Camera.CFrame.Position
	GunActivated:FireServer(direction,serverOrigin)
	
	local increaseValue = 1
	local moveSpeed = self.Hum.MoveDirection.Magnitude

	if self.IsAiming then
		increaseValue *= .5 
	end
	if moveSpeed > 0 then
		increaseValue *= 2
	end
	self.Inaccuracy = math.clamp(self.Inaccuracy + (self.InaccuracyRate*increaseValue),0 , self.MaxInaccuracy)

end


function gunManager:FireGun(gun,isShotgun)
	if not self.CurrentGun then return end
	if self.Reloading then return end
	
	if self.IsAiming then
		self.Animations["AimShoot"]:Play()
	else
		self.Animations["ShootR6"]:Play()
	end
	if self.Animations["ShootW"] then self.Animations["ShootW"]:Play() end
	
	
	local muzzle = self.CurrentGun:FindFirstChild("Muzzle")
	if not muzzle then return end
	
	local maxDistance = 1500
	

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {self.Player.Character}

	
	local mouseRay = self.Camera:ViewportPointToRay(self.Camera.ViewportSize.X / 2, self.Camera.ViewportSize.Y / 2)
	

	local spreadDirection = self:ApplyInnacuracy(mouseRay.Direction)
	local result = workspace:Raycast(mouseRay.Origin, spreadDirection * maxDistance, rayParams)
	
	
	local hitPosition
	if result then
		hitPosition = result.Position
	else
		hitPosition = mouseRay.Origin + spreadDirection * maxDistance
	end
	local origin = mouseRay.Origin
	
	local direction = (hitPosition - origin).Unit
	
	
	local muzzleOrigin = muzzle.Position	
	
	BulletCaster:CastTracer(muzzleOrigin, direction,gun,hitPosition)
	
	local serverOrigin = self.Camera.CFrame.Position
	GunActivated:FireServer(direction,serverOrigin)
	CreateRecoilEvent:Fire()
	
	local bulletChamber = self.CurrentGun:FindFirstChild("Chamber")
	
	if bulletChamber and not isShotgun then
		local bullet = bulletChamber:FindFirstChild("Bullet")
		if not bullet then return end
		local bulletClone = bullet:Clone()
		bulletClone.Transparency = 0
		bulletClone.Name = "bulletClone"
		bulletClone.CanCollide = true
		bulletClone.Parent = workspace 

		local localDirection = Vector3.new(0, 1, 1)

		local worldDirection = bulletChamber.CFrame:VectorToWorldSpace(localDirection)

		bulletClone:ApplyImpulse(worldDirection.Unit * 0.01)
		game.Debris:AddItem(bulletClone, 4)
	end
	
	if bulletChamber then
		local vfx = bulletChamber:FindFirstChild("VFX")

		for _, effect in ipairs(vfx:GetChildren()) do
			effect:Emit(effect:GetAttribute("EmitCount"))
		end
	end
	
	local increaseValue = 1
	local moveSpeed = self.Hum.MoveDirection.Magnitude

	if self.IsAiming then
		increaseValue *= .5 
	end
	if moveSpeed > 0 then
		increaseValue *= 2
	end
	
	self.Inaccuracy = math.clamp(self.Inaccuracy + (self.InaccuracyRate*increaseValue),0 , self.MaxInaccuracy)
	
end

function gunManager:FireBasedOnGun(gun)
	local shotgun = false
	for i,u in self.ShotgunAttributes do
		shotgun = true
	end
	
	
	if shotgun then
		for i = 0, self.ShotgunAttributes['PalletsShot'] do
			self:FireShotgun(gun,shotgun)
			CreateRecoilEvent:Fire()
		end
		
		if self.IsAiming then
			self.Animations["AimShoot"]:Play()
		else
			self.Animations["ShootR6"]:Play()
		end
		if self.Animations["ShootW"] then self.Animations["ShootW"]:Play() end
		
		local bulletChamber = self.CurrentGun:FindFirstChild("Chamber")
		local bullet = bulletChamber:FindFirstChild("Bullet")
		local bulletClone = bullet:Clone()
		bulletClone.Transparency = 0
		bulletClone.Name = "bulletClone"
		bulletClone.CanCollide = true
		bulletClone.Parent = workspace 

		local localDirection = Vector3.new(0, 1, 1)

		local worldDirection = bulletChamber.CFrame:VectorToWorldSpace(localDirection)

		bulletClone:ApplyImpulse(worldDirection.Unit * 0.01)
		game.Debris:AddItem(bulletClone, 4)
		return
	end
	
	if CollService:HasTag(self.CurrentGun,"RPG") then
		self:FireRPG(gun)
		return
	end
	
	self:FireGun(gun,shotgun)
	
end


function gunManager:ManageFire(gun)
	--print(gun,self.Reloading)
	if not gun then return end
	if self.Reloading then return end
	
	local isAuto = gun:GetAttribute("IsAuto")
	
	if self.CurrentGun:GetAttribute("Ammo") <= 0 then
		local sfx = outOfAmmo:Clone()
		sfx.Parent = gun:FindFirstChild("Chamber")
		sfx:Play()
		sfx.Ended:Once(function()
			sfx:Destroy()
		end)
		return
	end
	
	if isAuto and self.CurrentWeaponMode == "Auto" then
		self.Firing = true
		while self.Firing and self.CurrentGun == gun and self.CurrentGun:GetAttribute("Ammo") > 0 and self.CurrentWeaponMode == "Auto" do
			if not self.DebounceFire then
				
				self.DebounceFire = true
				self:FireBasedOnGun(gun)
				task.delay(gun:GetAttribute("FireRate"), function()
					self.DebounceFire = false
				end)
				
			end
			task.wait()
		end
	else
		if self.DebounceFire then return end
		self.Firing = true
		self.DebounceFire = true
		self:FireBasedOnGun(gun)
		
		
		task.delay(.1, function()
			self.Firing = false
			self.DebounceFire = false
		end)
	end
end


function gunManager:GetSpecificAttributes()
	if CollService:HasTag(self.CurrentGun, "Shotgun") then
		self.ShotgunAttributes["PalletsShot"] = self.CurrentGun:GetAttribute("PalletsShot")
		return
	end
	
end

function gunManager:CreateAnimations(animations , animController)
	
	for _,anim in self.Animations do
		if anim and anim.IsPlaying then anim:Stop() end
	end
	
	local humAnimator = self.Hum:WaitForChild("Animator")
	self.Animations["Idle"] = humAnimator:LoadAnimation(animations.Idle)
	self.Animations["ShootR6"] = humAnimator:LoadAnimation(animations.Shoot)
	self.Animations["ReloadR6"] = humAnimator:LoadAnimation(animations.Reload)
	self.Animations["ReloadR6"].Looped = false
	self.Animations["Aim"] = humAnimator:LoadAnimation(animations.Aim)
	self.Animations["AimShoot"] = humAnimator:LoadAnimation(animations.AimShoot)
	if animations:FindFirstChild("Equip") then self.Animations["Equip"] = humAnimator:LoadAnimation(animations.Equip) end
	
	if not animController then return end
	local gunAnimator = animController:FindFirstChild("Animator")

	if animController:FindFirstChild("Shoot") then self.Animations["ShootW"] = gunAnimator:LoadAnimation(animController.Shoot) self.Animations["ShootW"].Looped = false end
	self.Animations["ReloadW"] = gunAnimator:LoadAnimation(animController.Reload)
	
	if animController:FindFirstChild("Idle") then self.Animations["IdleW"] = gunAnimator:LoadAnimation(animController.Idle) end
	
	
	
	
end

function gunManager:ManageReload()
	if self.Reloading then return end
	self.Reloading = true
	
	if self.CurrentGun:GetAttribute("Ammo") >= self.CurrentGun:GetAttribute("MaxAmmo") then self.Reloading = false return end
	
	ReloadEvent:FireServer(self.CurrentGun)
	self.Animations["ReloadR6"]:Play()
	self.Animations["ReloadR6"]:AdjustSpeed(self.Animations["ReloadR6"].Length/self.CurrentGun:GetAttribute("ReloadTime"))
	
	if self.Animations["ReloadW"] then
		self.Animations["ReloadW"]:Play()
		self.Animations["ReloadW"]:AdjustSpeed(self.Animations["ReloadW"].Length/self.CurrentGun:GetAttribute("ReloadTime"))
	end
	task.delay(self.CurrentGun:GetAttribute("ReloadTime"), function()
		self.Reloading = false
	end)
end

function gunManager:Aim()
	if self.IsAiming then return end
	self.IsAiming = true
	if self.Animations['Aim'] then self.Animations["Aim"]:Play() end
	if not self.CurrentGun then return end
	local neededZoom = self.CurrentGun:GetAttribute("Sniper") and SniperZoom or ZoomedIn
	
	TweenService:Create(self.Camera, self.ZoomInfo,{FieldOfView = neededZoom}):Play()
	UIS.MouseDeltaSensitivity = (self.CurrentGun:GetAttribute("AimSensibility") or .25) / UGS.MouseSensitivity
	
	if self.CurrentGun:GetAttribute("Sniper") then
		local TWI = TweenInfo.new(.4 ,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
		if self.ScopeTween then self.ScopeTween:Cancel() end
		local scopeClone = ScopeOnSFX:Clone()
		scopeClone.Parent = SoundService
		self.ScopeTween = TweenService:Create(self.ScopeFrame, TWI,{BackgroundTransparency = .35})
		self.ScopeTween:Play()
		scopeClone:Play()
		self.ScopeImage.Visible = true
		
		game.Debris:AddItem(scopeClone, 3)
		
	end
end


function gunManager:DisableAim()
	if not self.IsAiming then return end
	self.IsAiming = false
	if self.Animations["Aim"] then self.Animations["Aim"]:Stop() end
	TweenService:Create(self.Camera, self.ZoomInfo,{FieldOfView = NormalZoom}):Play()
	UIS.MouseDeltaSensitivity = 0.5  / UGS.MouseSensitivity
	if (self.CurrentGun and self.CurrentGun:GetAttribute("Sniper")) or self.ScopeImage.Visible == true then
		local TWI = TweenInfo.new(.4 ,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
		if self.ScopeTween then self.ScopeTween:Cancel() end
		local scopeClone = ScopeOffSFX:Clone()
		scopeClone.Parent = SoundService
		self.ScopeTween = TweenService:Create(self.ScopeFrame, TWI,{BackgroundTransparency = 1})
		self.ScopeTween:Play()
		scopeClone:Play()
		self.ScopeImage.Visible = false
		
		game.Debris:AddItem(scopeClone, 3)
	end
end

function gunManager:SetupAmmoUI()
	self.AmmoTxt.Text = self.CurrentGun:GetAttribute("Ammo").."/"..self.CurrentGun:GetAttribute("MaxAmmo")
	self.WNameTxt.Text = self.CurrentGun.Name
	self.WeaponUI.Visible = true
	local t
	t = self.CurrentGun:GetAttributeChangedSignal("Ammo"):Connect(function()
		if not self.CurrentGun then return end
		self.AmmoTxt.Text = self.CurrentGun:GetAttribute("Ammo").."/"..self.CurrentGun:GetAttribute("MaxAmmo")
	end)
	self.WAmmoType.Text = self.CurrentGun:GetAttribute("BDimensions") or self.CurrentGun:FindFirstChild("Chamber"):FindFirstChild("Bullet"):GetAttribute("Dimensions")
	
	for _ ,child in ipairs(self.WeaponUI:GetChildren()) do
		if not child:IsA("ImageLabel") or child.Name == "IGNORE" then continue end
		child.Visible = false
	end
	self.BulletImages[self.CurrentGun:GetAttribute("BDimensions") or self.CurrentGun:FindFirstChild("Chamber"):FindFirstChild("Bullet"):GetAttribute("Dimensions")].Visible = true
	self.WModeTxt.Text = "["..self.CurrentWeaponMode..'][v]'
	
	
	return t
end

function gunManager:Unequip(t1,t2,t3,t4,t5, t6)
	if self.Animations["Idle"] then self.Animations["Idle"]:Stop() end
	if self.Animations["IdleW"] then self.Animations["IdleW"]:Stop() end
	local disconnects = {t1, t2,t3,t4,t5,t6}
	self.ShotgunAttributes = {}
	
	UIS.MouseDeltaSensitivity = 0.5  / UGS.MouseSensitivity
	self.Camera.FieldOfView = NormalZoom
	self.CurrentGun = nil
	self.Firing = false
	toggleCam:Fire(false)
	self:DisableAim()
	self.Animations = {}
	
	for _,con in disconnects do
		if not con.Connected then continue end
		con:Disconnect()
	end
	
	self.WeaponUI.Visible = false
	self.Crosshair.Visible = false
	UIS.MouseIconEnabled = true
end

function gunManager:AnimateHitMarker(isHead)
	if not self.CurrentGun then return end
	
	local hitmarker = self.HitMarker:Clone()
	
	for _,frame in ipairs(hitmarker:GetChildren()) do
		if not frame:IsA("Frame") then continue end
		if isHead then
			
			frame.BackgroundColor3 = HeadHitColor
			local soundClone = HeadShot:Clone()
			soundClone.Parent = self.Player.Character
			soundClone:Play()
			soundClone.Ended:Once(function()
				soundClone:Destroy()
			end)
			
		else
			frame.BackgroundColor3 = NormalHitColor
		end
	end
	
	hitmarker.Parent = self.HitMarker.Parent
	local UIScale = hitmarker:FindFirstChild("UIScale")
	
	local grow = TweenService:Create(UIScale, self.HitInInfo, {Scale = 3})
	local shrink = TweenService:Create(UIScale, self.HitOutInfo, {Scale = .2})
	
	hitmarker.Visible = true
	grow:Play()
	
	grow.Completed:Once(function()
		shrink:Play()
	end)
	
	shrink.Completed:Once(function()
		hitmarker:Destroy()
	end)
end

function gunManager:ChangeGunModes()
	if not self.CurrentGun then return end
	local gunCloneSwitch = gunModeSwitchSFX:Clone()
	gunCloneSwitch.Parent = SoundService
	game.Debris:AddItem(gunCloneSwitch, 3)
	print("Here Running")
	if self.CurrentWeaponMode == "Auto" then
		self.CurrentWeaponMode = "Semi"
		self.CurrentGun:SetAttribute("CurrentMode","Semi")
		self.WModeTxt.Text = "["..self.CurrentWeaponMode..'][v]'
		gunCloneSwitch:Play()
		
	elseif self.CurrentWeaponMode == "Semi" and self.CurrentGun:GetAttribute("IsAuto") then
		self.CurrentWeaponMode = "Auto"
		self.CurrentGun:SetAttribute("CurrentMode","Auto")
		self.WModeTxt.Text = "["..self.CurrentWeaponMode..'][v]'
		gunCloneSwitch:Play()
	else return
	end
end


function gunManager:SetupCons()
	self.Hum.Died:Once(function()
		toggleCam:Fire(false)
		for i,v in pairs(self.Connections) do
			if not v.Connected then continue end
			v:Disconnect()
		end
		self.CurrentGun = nil
		self.Animations = nil
		UIS.MouseIconEnabled = true
		self:DisableAim()
	end)
	local tempCon1


	tempCon1 = GunEquiped.OnClientEvent:Connect(function(gun)
		self.OriginalCameraOffset =  self.Hum.CameraOffset
		self.CurrentGun = gun
		self.Crosshair.Visible = true
		UIS.MouseIconEnabled = false
		toggleCam:Fire(true)
		self:GetSpecificAttributes()
		
		self.CurrentWeaponMode = self.CurrentGun:GetAttribute("IsAuto") and self.CurrentGun:GetAttribute("CurrentMode") or "Semi"
		
		self:CreateAnimations(gun:FindFirstChild("Animations"), gun:FindFirstChild("AnimationController"))
		if self.Animations["Equip"] then self.Animations["Equip"]:Play() end

		self.Animations["Idle"]:Play()
		if self.Animations["IdleW"] then self.Animations["IdleW"]:Play() end
		
		local tempCon5 = self:SetupAmmoUI()
		table.insert(self.Connections , tempCon5)

		local tCon2
		tCon2 = UIS.InputBegan:Connect(function(inpt, gm)
			if gm then return end
			if inpt.KeyCode == Enum.KeyCode.R then
				self:ManageReload()
			elseif inpt.UserInputType == Enum.UserInputType.MouseButton2 then
				self:Aim()
			end
		end)

		table.insert(self.Connections , tCon2)

		local tCon3

		tCon3 = UIS.InputEnded:Connect(function(inpt,gm)
			if gm then return end

			if inpt.UserInputType == Enum.UserInputType.MouseButton2 then
				self:DisableAim()
			end
		end)
		table.insert(self.Connections , tCon3)


		local tempCon2 
		tempCon2 = gun.Activated:Connect(function()
			self:ManageFire(gun)
		end)

		table.insert(self.Connections , tempCon2)

		local tempCon4
		tempCon4 = gun.Deactivated:Connect(function()
			self.Firing = false
		end)
		table.insert(self.Connections , tempCon4)
		
		local tempCON6
		
		
		
		local tempCon3
		tempCon3 = gun.Unequipped:Connect(function() 
			self:Unequip(tempCon2,tempCon3,tempCon4,tCon2,tCon3,tempCon5)
		end)

		table.insert(self.Connections , tempCon3)
		
		self.InaccuracyRate = gun:GetAttribute("InaccuracyRate") or 0
		self.MaxInaccuracy = gun:GetAttribute("StationaryInaccuracy") or 0
		self.MovingInaccuracy = gun:GetAttribute("MovingInaccuracy") or 0
	
	end)
	table.insert(self.Connections , tempCon1)

	local tCon

	tCon = CastBullet.OnClientEvent:Connect(function(origin,direction,gun,endPos)
		BulletCaster:CastTracer(origin,direction,gun,endPos)
	end)
	table.insert(self.Connections, tCon)
	
	
	tCon = CastTravel.OnClientEvent:Connect(function(DataPacket)
		print("Casting rocket")
		BulletCaster:CastRocket(DataPacket)
	end)
	table.insert(self.Connections, tCon)
	
	tCon = HitEvent.OnClientEvent:Connect(function(isHead)
		self:AnimateHitMarker(isHead)
	end)
	
	table.insert(self.Connections,tCon)
	
	local debounce = false
	tCon = RunService.Heartbeat:Connect(function(dt)
		if not self.Hum then return end
		
		if self.Inaccuracy > 0 and not debounce and not self.Firing then
			debounce = true
			self.Inaccuracy = math.max(0, self.Inaccuracy - .4)
			task.delay(.1, function()
				debounce = false
			end)
		end
	end)

	table.insert(self.Connections, tCon)
	
	tCon = UIS.InputBegan:Connect(function(inpt,gm)
		if gm then return end
		if inpt.KeyCode == Enum.KeyCode.V then
			self:ChangeGunModes()
			print('Running here')
		end
		
	end)
	table.insert(self.Connections, tCon)
	
end


function gunManager:Init()
	self:SetupCons()
	
	self.Camera.FieldOfView = NormalZoom
	UIS.MouseDeltaSensitivity = 0.5  / UGS.MouseSensitivity
end


return gunManager
