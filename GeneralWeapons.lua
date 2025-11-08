local RepStorage = game:GetService("ReplicatedStorage")
local ScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local weaponSfxs = ServerStorage:WaitForChild("SFX"):WaitForChild("Weapons")
local CollectionService = game:GetService("CollectionService")

local HitSomeoneEvent = RepStorage:WaitForChild("Events"):WaitForChild("Weapons"):WaitForChild("HitSomeone")
local LoadAnimations = RepStorage:WaitForChild("Events"):WaitForChild("Weapons"):WaitForChild("LoadAnimations")

local HitboxClass = require(ScriptService:WaitForChild("Classes"):WaitForChild("Misc"):WaitForChild("Hitbox"))
local MiscHelper = require(ScriptService:WaitForChild("Classes"):WaitForChild("Misc"):WaitForChild("MiscHelper"))
local Janitor = require(RepStorage:WaitForChild("ModuleScripts"):WaitForChild("Janitor"))

local WeaponAnimations = RepStorage:WaitForChild("Animations"):WaitForChild("Weapons")
local WeaponVFX = ServerStorage.VFX.Weapons

type Player = Player
type Tool = Tool
type Animator = Animator
type Hitbox = typeof(HitboxClass)
type MiscHelper = typeof(MiscHelper)
type Janitor = typeof(Janitor.new())

export type GeneralWeapons = {
	WeaponModel: Tool,
	Owner: Player,
	Character: Model,
	HumanoidAnimator: Animator,
	RepStorage: Instance,
	WeaponAnimations: Folder,
	GeneralAnimations: Folder,
	WeaponSFX: Folder?,
	Animations: { [string]: AnimationTrack },
	HitboxClass: Hitbox,
	IsAttacking: boolean,
	AttackDamage: number,
	AttackCooldown: number,
	KnockBackAttackForce: number,
	UpForceAttackKnockBack: number,
	WeaponVFX: Folder,
	HitSomeone: RemoteEvent,
	AttackDelay: number,
	CanAbilityWhileM1: boolean,
	Helper: MiscHelper,
	RagdollTime: number,
	Janitor: any,
	JanitorSwing: Janitor,
	IsUsingAbility: boolean,

	
	new: (Player, Tool) -> GeneralWeapons,
	GetAnimations: (self: GeneralWeapons) -> (),
	WeaponEquiped: (self: GeneralWeapons) -> (),
	WeaponUnequiped: (self: GeneralWeapons) -> (),
	GiveAttackDelay: (self: GeneralWeapons) -> (),
	BuildCombinedParams: (self: GeneralWeapons) -> OverlapParams
}

local GeneralWeapons = {}
GeneralWeapons.__index = GeneralWeapons

function GeneralWeapons.new(Player: Player, Tool: Tool): GeneralWeapons
	local self = setmetatable({}, GeneralWeapons)

	self.WeaponModel = Tool
	self.Owner = Player
	self.Character = Player.Character or Player.CharacterAdded:Wait()
	self.HumanoidAnimator = self.Character:WaitForChild("Humanoid"):WaitForChild("Animator")
	self.RepStorage = RepStorage
	self.WeaponAnimations = WeaponAnimations
	self.GeneralAnimations = RepStorage:WaitForChild("Animations"):WaitForChild("GeneralAnims")
	self.WeaponSFX = weaponSfxs:FindFirstChild(self.WeaponModel.Name) or weaponSfxs:FindFirstChild("General")
	self.Animations = {}
	self.HitboxClass = HitboxClass
	self.IsAttacking = false
	self.IsUsingAbility = false
	self.AttackDamage = Tool:GetAttribute("AttackDamage") or 0
	self.AttackCooldown = Tool:GetAttribute("AttackCooldown") or 0.4
	self.KnockBackAttackForce = Tool:GetAttribute("KnockBackAttackForce") or 0
	self.UpForceAttackKnockBack = script:GetAttribute("UpKnockback") or 0
	self.WeaponVFX = WeaponVFX
	self.HitSomeone = HitSomeoneEvent
	self.AttackDelay = Tool:GetAttribute("AttackDelay") or 1
	self.CanAbilityWhileM1 = Tool:GetAttribute("CanAbilityWhileM1") or false
	self.Helper = MiscHelper
	self.RagdollTime = 3
	self.Janitor = Janitor
	self.JanitorSwing = self.Janitor.new()

	for _, part in ipairs(Tool:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		part.CollisionGroup = "ToolCollider"
	end

	return self
end

function GeneralWeapons:WeaponEquiped()
	self.Owner.Character:WaitForChild("Humanoid")
	self.Animations["Idle"]:Play()
	self.Animations["Idle"].Looped = true
	if self.Animations["Idle2"] then self.Animations["Idle2"].Looped = true self.Animations["Idle2"]:Play() end
end

function GeneralWeapons:GiveAttackDelay()
	local Char = self.Owner.Character
	local Humanoid = Char:FindFirstChild("Humanoid")

	Humanoid:SetAttribute("WalkDisabled",true)
	Char:SetAttribute("CanAttack",false)

	task.delay(self.AttackDelay,function()
		Humanoid:SetAttribute("WalkDisabled",false)
		Char:SetAttribute("CanAttack",true)
	end)

end



function GeneralWeapons:BuildCombinedParams()


	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local combined = {}

	for _, v in ipairs(CollectionService:GetTagged("PlayerCharacter")) do
		if v ~= self.Owner.Character then 
			table.insert(combined, v)
		end
	end
	for _, v in ipairs(CollectionService:GetTagged("RigCharacter")) do
		table.insert(combined, v)
	end

	params.FilterDescendantsInstances = combined
	return params

end


function GeneralWeapons:WeaponUnequiped()
	for _,anim in self.Animations do
		if not anim.IsPlaying then continue end
		anim:Stop()
	end
end


function GeneralWeapons:GetAnimations()

	local AnimFolder = self.WeaponAnimations:FindFirstChild(self.WeaponModel.Name) or self.GeneralAnimations

	local AnimationsNameHumanoid = {
		"Ability1",
		"Ability2",
		"Hit",
		"Idle",
		'Idle2'
	}

	for _,AnimName in AnimationsNameHumanoid do
		if not AnimFolder:FindFirstChild(AnimName) then continue end
		local packet = {["Animation Name"] = AnimName, ["Weapon Name"] = self.WeaponModel.Name}
		LoadAnimations:FireClient(self.Owner, packet)
		self.Animations[AnimName] = self.HumanoidAnimator:LoadAnimation(AnimFolder[AnimName])
	end

end


return GeneralWeapons
