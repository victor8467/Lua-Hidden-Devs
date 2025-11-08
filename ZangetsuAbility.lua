local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local GetsugaTenshoModel = ServerStorage:WaitForChild("Abilities"):WaitForChild("Zangetsu"):WaitForChild("Getsuga")

local Zangetsu = {}

local GetsugaTenshoCooldowns = {}


function Zangetsu.GetsugaTensho(ToolClass, packet)
	local Player = ToolClass.Owner
	if not Player then return end
	
	local playerName = Player.Name
	if GetsugaTenshoCooldowns[playerName] then return end
	GetsugaTenshoCooldowns[playerName] = true
	
	
	local Character = Player.Character
	if not Character then return end
	
	local hrp = Character:WaitForChild("HumanoidRootPart")
	if not hrp then return end
	
	local hum = Character:WaitForChild("Humanoid")
	if not hum then return end
	
	
	local GetsugaModel = GetsugaTenshoModel:Clone()
	local HitboxPart = GetsugaModel:WaitForChild("Hitbox")
	
	local Weapon = ToolClass.WeaponModel
	
	local Range = Weapon:GetAttribute("GetsugaTenshoRange")
	local Speed = Weapon:GetAttribute("GetsugaTenshoSpeed")
	local Cooldown = Weapon:GetAttribute("GetsugaTenshoCooldown")
	
	local TimeNeeded = Range / Speed
	
	local AbilityTrack = ToolClass.Animations["Ability1"]
	
	local helper = ToolClass.Helper
	
	local con
	local Janitor = packet["Janitor"]
	
	local params = ToolClass:BuildCombinedParams()

	local hitbox = ToolClass.HitboxClass.new(true,params,HitboxPart.Size,10,false)
	local abilitySfx = ToolClass.WeaponSFX:FindFirstChild("Ability1"):Clone()
	abilitySfx.Parent = hrp
	
	local GetsugaSfx = ToolClass.WeaponSFX:FindFirstChild("GetsugaSlash"):Clone()
	GetsugaSfx.Parent = Weapon
	
	game.Debris:AddItem(abilitySfx, abilitySfx.TimeLength + 1)
	game.Debris:AddItem(GetsugaSfx, GetsugaSfx.TimeLength + 3)
	
	
	local VfxFolder = ToolClass.WeaponVFX:FindFirstChild(Weapon.Name)
	local Static1 = VfxFolder:FindFirstChild("Static"):FindFirstChild("0")
	local Static2 = VfxFolder:FindFirstChild("Static"):FindFirstChild("1")
	
	local SlashVFX = VfxFolder:FindFirstChild("Slash"):Clone()
	
	game.Debris:AddItem(SlashVFX, 10)
	
	local attaches = {}
	
	for _,attach in ipairs(Static1:GetChildren()) do
		local att = attach:Clone()
		att.Parent = hrp
		game.Debris:AddItem(att, 10)
		table.insert(attaches, att)
	end
	
	for _,attach in ipairs(Static2:GetChildren()) do
		local att
		att = attach:Clone()
		att.Parent = hrp
		game.Debris:AddItem(att, 10)
		table.insert(attaches, att)
	end
	
	AbilityTrack:Play()
	abilitySfx:Play()

	Character:SetAttribute("CanRagdoll" , false)
	hum:SetAttribute("WalkDisabled",true)
	
	

	hum.AutoRotate = false
	con = AbilityTrack:GetMarkerReachedSignal("slash"):Once(function()
		print("Ability hit slash")
		local face = hrp.CFrame.LookVector
		local StartPos = hrp.Position + face * 5
		local finishPos = StartPos + face * Range
		
		SlashVFX.Parent = workspace
		SlashVFX.CFrame = CFrame.new(hrp.Position,hrp.Position - hrp.CFrame.LookVector)
		
		for _, vfx in ipairs(SlashVFX:GetDescendants()) do
			if not vfx:IsA("ParticleEmitter") then continue end
			vfx:Emit(vfx:GetAttribute("EmitCount") or 1)
		end
		
		GetsugaModel.Parent = workspace
		GetsugaModel:MoveTo(StartPos)
		GetsugaSfx:Play()
		
		GetsugaModel:SetPrimaryPartCFrame(
			CFrame.new(StartPos, StartPos - face)
		)
		
		local hitChars = {}
		hitbox:Start(TimeNeeded, function(AttackedChar,AttackHumanoid)
			if hitChars[AttackedChar] then return end
			hitChars[AttackedChar] = true

			AttackHumanoid:TakeDamage(Weapon:GetAttribute("GetsugaTenshoDamage"))

			local AttackedHrp = AttackedChar:FindFirstChild("HumanoidRootPart")

			ToolClass.Helper.RagdollCharacter(AttackedChar,ToolClass.RagdollTime)
			ToolClass.Helper.ApplyKnockback(AttackedHrp,hrp,ToolClass.KnockBackAttackForce)

		end,HitboxPart)
		
		local con2 
		local timePassed = 0
		con2 = RunService.Heartbeat:Connect(function(DeltaTime)
			timePassed += DeltaTime
			
			local alpha = math.clamp(timePassed / TimeNeeded, 0, 1)
			local NextPos = helper.Lerp(StartPos, finishPos ,alpha)
			GetsugaModel:MoveTo(NextPos)
			
			if alpha >= 1 or timePassed >= TimeNeeded then
				if GetsugaModel then GetsugaModel:Destroy() end
				Janitor:Destroy()
				con2:Disconnect()
			end
		end)
		
	end)
	Janitor:Add(con,"Slash Hit")
	
	con = AbilityTrack.Stopped:Once(function()
		hum:SetAttribute("WalkDisabled",false)
		Character:SetAttribute("CanRagdoll" , true)
		hum.AutoRotate = true
		
		for _, att in attaches do
			att:Destroy()
		end
		
		print("Ability Track Stopped")
	end)
	Janitor:Add(con,"Ability Stopped")
	
	task.delay(Cooldown, function()
		if GetsugaModel then GetsugaModel:Destroy() end
		GetsugaTenshoCooldowns[playerName] = nil
	end)
	
	
end


return Zangetsu
