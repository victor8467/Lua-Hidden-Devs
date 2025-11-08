local ObjectPool = require(script.Parent.ObjectPool)
local PhysicsService = game:GetService("PhysicsService")

PhysicsService:RegisterCollisionGroup('ToolCollider')
PhysicsService:RegisterCollisionGroup('ColliderPart')
PhysicsService:RegisterCollisionGroup('RigColliderRagdoll')

PhysicsService:CollisionGroupSetCollidable('ColliderPart','RigColliderRagdoll',false)
PhysicsService:CollisionGroupSetCollidable('ColliderPart','ColliderPart',false)
PhysicsService:CollisionGroupSetCollidable('ColliderPart','ToolCollider',false)

local Ragdoll = {}

local joints = {}
local MovingPowers = {}


function Ragdoll.GetPartsList(char : Model)
	local colliderList ={
		RArm = char:FindFirstChild("Right Arm"),
		LArm = char:FindFirstChild("Left Arm"),
		RLeg = char:FindFirstChild("Right Leg"),
		LLeg = char:FindFirstChild("Left Leg"),
		Head = char:FindFirstChild("Head"),
		Torso = char:FindFirstChild("Torso")
	}
	
	return colliderList
end


function Ragdoll.Init(Character : Model)

	joints[Character.Name] = {}
	
	local Parts = Ragdoll.GetPartsList(Character)
	local hrp = Character:WaitForChild("HumanoidRootPart")
	hrp.CollisionGroup = "RigColliderRagdoll"
	
	local hum = Character:WaitForChild("Humanoid")
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	
	MovingPowers[Character.Name] = {}
	
	for _,part in Parts do
		part.CollisionGroup = "RigPart"
		local collider = Instance.new("Part")
		collider.Name = "ColliderPart"
		collider.CollisionGroup = "RigColliderRagdoll"
		collider.Massless = true
		collider.CanQuery = false
		collider.CanTouch = false
		collider.CanCollide = false
		collider.Transparency = 1
		
	
		
		collider.Parent = part
		
		local weld = Instance.new("WeldConstraint")
		
		collider.Size = part.Size / 1.7
 		collider.CFrame = part.CFrame
		weld.Parent = part
		
		weld.Part0 = part
		weld.Part1 = collider
	end
	
	Character:SetAttribute("Ragdoll" , false)
	Character:SetAttribute("CanRagdoll", true)
	
	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if not Character:GetAttribute("CanRagdoll") then Character:SetAttribute("Ragdoll" , false) return end
		if Character:GetAttribute("Ragdoll") then
			
			Ragdoll.Ragdoll(Character)
		else
			Ragdoll.Unragdoll(Character)
		end
	end)
	
end

function Ragdoll.TurnColliders(char, turn)
	local colliderList = Ragdoll.GetPartsList(char)
	
	for _,part in colliderList do
		part.CanCollide = not turn
		if not part:FindFirstChild("ColliderPart") then warn("No collider on "..part.Name) continue end
		part:FindFirstChild("ColliderPart").CanCollide = turn
		part:FindFirstChild("ColliderPart").CanQuery = false
	end
end

function Ragdoll.TurnM6D(char,turn)

	local HRP = char:WaitForChild("HumanoidRootPart")
	local Torso = char:WaitForChild("Torso")

	HRP.RootJoint.Enabled = turn

	for _,M6d in ipairs(Torso:GetChildren()) do
		if not M6d:IsA("Motor6D") then continue end
		M6d.Enabled = turn
	end
end



function Ragdoll.StopPlayingAnimations(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop()
	end
end

function Ragdoll.Ragdoll(Character)
	if not Character then return end
	
	local hrp = Character:FindFirstChild("HumanoidRootPart")
	local Torso = Character:FindFirstChild("Torso")
	local Hum = Character:FindFirstChildWhichIsA("Humanoid")
	
	if hrp then hrp.Anchored = false end

	for _,child in ipairs(hrp:GetChildren()) do
		if (child:IsA("Attachment") and Character.Name ~= "RootAttachment") or child:IsA("Sound") then
			child:Destroy()
			continue
		end
	end

	for i,v in pairs(Character.Humanoid:GetPlayingAnimationTracks()) do
		v:Stop()
	end
	
	Hum:SetAttribute("InputDisabled", true)
	Hum.AutoRotate = false
	Hum.PlatformStand = true
	
	local weld = Instance.new("WeldConstraint")
	weld.Name = Character.Name
	weld.Part0 = Torso
	weld.Part1 = hrp
	weld.Parent = hrp
	weld.Enabled = true
	
	Ragdoll.TurnColliders(Character, true)
	Ragdoll.TurnM6D(Character,false)
	
	for _,m6d in ipairs(Character:GetDescendants()) do

		if not m6d:IsA("Motor6D") then continue end

		local att1 = Instance.new("Attachment")
		local att2 = Instance.new("Attachment")
		
		att1.CFrame = m6d.C0
		att2.CFrame = m6d.C1

		att1.Parent = m6d.Part0
		att2.Parent = m6d.Part1


		local socket = Instance.new("BallSocketConstraint")
		socket.Attachment0 = att1
		socket.Attachment1 = att2
		socket.LimitsEnabled = true
		socket.TwistLimitsEnabled = true
		socket.Parent = m6d.Parent

		table.insert(joints[Character.Name], att1)
		table.insert(joints[Character.Name], att2)
		table.insert(joints[Character.Name], socket)
	end
	
	
end

function Ragdoll.DestroyJoints(char)
	local playerJoints = joints[char.Name]
	
	for _ , joint in playerJoints do
		joint:Destroy()
	end
	
end



function Ragdoll.Unragdoll(char)
	local hum = char:FindFirstChild("Humanoid")


	local HRP = char:FindFirstChild("HumanoidRootPart")
	HRP.Massless = false


	game["Run Service"].Heartbeat:Wait()
	task.wait()


	local Restrictions = RaycastParams.new()
	Restrictions.FilterType = Enum.RaycastFilterType.Exclude

	HRP.Anchored = true
	local GetUpCFrame = CFrame.new(HRP.Position)
	Restrictions.FilterDescendantsInstances = {char}
	local GetUpRayEnd = HRP.Position + Vector3.new(0, -5, 0) - HRP.Position
	local GetUpRay = game.Workspace:Raycast(HRP.Position, GetUpRayEnd, Restrictions)
	if GetUpRay then
		GetUpCFrame = CFrame.new(GetUpRay.Position + Vector3.new(0, 5, 0))
	end

	Ragdoll.DestroyJoints(char)
	Ragdoll.TurnM6D(char,true)

	HRP.CFrame = GetUpCFrame
	hum.PlatformStand = false
	
	hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	game["Run Service"].Heartbeat:Wait()

	hum:SetAttribute("InputDisabled", false)
	hum.AutoRotate = true
	HRP.Anchored = false


	Ragdoll.TurnColliders(char, false)
	if HRP:FindFirstChild(char.Name) then HRP:FindFirstChild(char.Name):Destroy() end
end

function Ragdoll.ClearRagdollOnLeave(Player)
	joints[Player.Name] = nil
end





return Ragdoll
