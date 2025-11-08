local RepStorage = game:GetService("ReplicatedStorage")


local GeneralWeapons = require(script.Parent:WaitForChild("GeneralWeapons"))
local Ragdoll = require(RepStorage.ModuleScripts.ragdoll)

local Swords = setmetatable({},GeneralWeapons)
Swords.__index = Swords




function Swords.new(sword,Player)
	local self = setmetatable(GeneralWeapons.new(Player,sword), Swords)

	self:GetAnimations()


	self.HitboxSize = sword:FindFirstChild("Hitbox").Size or Vector3.new(5,5,5)
	self.SfxAttackCooldown = 1
	self.SfxAttackDebounce = false


	return self
end


function Swords:SetupWeapon()
	local hitTrack = self.Animations["Hit"]

	if hitTrack then
		local con

		local janitor = self.Janitor.new()
		local Char = self.Owner.Character
		local Humanoid = Char:FindFirstChild("Humanoid")
		local currentHitbox

		con = hitTrack:GetMarkerReachedSignal("swing"):Connect(function()
			local params = self:BuildCombinedParams()
			currentHitbox = self.HitboxClass.new(true,params, self.HitboxSize,10,false)

			local hitHumanoids = {}
			currentHitbox:Start(hitTrack.Length - hitTrack.TimePosition, function(character, humanoid)
				if hitHumanoids[character] then return end
				if humanoid and humanoid.Health > 0 then
					hitHumanoids[character] = humanoid
					self:SwingHitSomeone(character,humanoid)
				end
			end,self.WeaponModel.Hitbox)
		end)


		self.JanitorSwing:Add(con, "Swing")

		con = hitTrack:GetMarkerReachedSignal("endswing"):Connect(function()
			if currentHitbox then currentHitbox:Stop() end
			self:GiveAttackDelay()
		end)
		self.JanitorSwing:Add(con, "EndSwing")

		local function AnimStopped()
			if currentHitbox then
				currentHitbox:Stop()
				currentHitbox = nil
			end
			task.wait(self.AttackCooldown)
			self.IsAttacking = false
		end


		con = hitTrack.Stopped:Connect(function()
			AnimStopped()
		end)
		self.JanitorSwing:Add(con, "SwingTrackStopped")

	end

end


function Swords:SwingHitSomeone(character,humanoid)
	local attackerHrp = self.Character:FindFirstChild("HumanoidRootPart")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	self.Helper.RagdollCharacter(character,self.RagdollTime)

	self.Helper.ApplyKnockback(hrp,attackerHrp,self.KnockBackAttackForce,self.UpForceAttackKnockBack)

	humanoid:TakeDamage(self.AttackDamage)
	self.HitSomeone:Fire()

	if self.WeaponSFX:FindFirstChild("Hit") and not self.SfxAttackDebounce then
		self.SfxAttackDebounce = true
		local hit = self.WeaponSFX:FindFirstChild("Hit"):Clone()
		hit.Parent = self.WeaponModel.PrimaryPart
		hit:Play()
		game.Debris:AddItem(hit,3)

		task.delay(self.SfxAttackCooldown,function()
			self.SfxAttackDebounce = false
		end)
	end



	local vfxHit = self.WeaponVFX:FindFirstChild("NormalHit")

	self.Helper.ApplyVfxFromFolderOnTarget(vfxHit, hrp)


end


function Swords:WeaponUsed()
	local Char = self.Owner.Character
	if self.IsAttacking or not Char:GetAttribute("CanAttack")  then return end
	self.IsAttacking = true
	self.Animations["Hit"]:Play()
end



function Swords:ToolCleanup()
	self.WeaponModel:Destroy()
	self.Owner = nil

	self.JanitorSwing:Destroy()

	self = nil

end


return Swords
