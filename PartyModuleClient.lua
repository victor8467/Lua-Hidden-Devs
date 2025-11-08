local DisbandEvent = RepStorage.Events.Remote.Party.DisbandParty
local LeaveEvent = RepStorage.Events.Remote.Party.LeaveParty
local KickPlayerEvent = RepStorage.Events.Remote.Party.KickPlayer

local Party = {}
Party.__index = Party


function Party.new(player , gui , party) --this is  a party manager for the client
	local self = setmetatable({}, Party)
	self.Player = player
	self.GUI = gui
	self.InstName = "Party"
	self.PartyHub = gui.PartyHub
	self.Party = party
	self.Exit = self.PartyHub.PartyTopBar.Exit
	
	self.PartyList = self.PartyHub.PlayerList.PartyList
	self.LeaderSample = self.PartyList.Leader
	self.MemberSample = self.PartyList.Member
	self.OpenSample = self.PartyList.Open
	
	self.PartyInfo = self.PartyHub.PartyInfo
	self.DisbandButton = self.PartyInfo.DisbandButton
	self.LeaveButton = self.PartyInfo.LeaveButton
	
	self.PartyInviteList = gui.PartyInviteList
	self.PlayerSample = self.PartyInviteList.PlayerList.PartyList.PlayerSample
	
	self.Connections = {}
	
	
	self:Init()
	return self
end

function Party:DestroyInst()
	self.PartyHub.Visible = false
	self.PartyInviteList.Visible = false
	
	for _,con in ipairs(self.Connections) do
		if con then con:Disconnect() end
	end
	
	setmetatable(self, nil)
	for key in pairs(self) do
		self[key] = nil
	end
	
end

function Party:UpdateWindow() --Updates the window whenever a new player joins or leaves 
	if not self.Party then return end
	
	for _,frame in ipairs(self.PartyList:GetChildren()) do
		if not frame:IsA("Frame") or frame.Visible == false then continue end
		frame:Destroy()
	end
	local count = 0
	local maxParty = 6
	
	local Owner = false
	if self.Party[self.Player.Name] == "Leader" then Owner = true end
	
	for player,status in self.Party do
		count += 1
		if status == "Leader" then 
			local frame = self.LeaderSample:Clone()
			frame.Parent = self.LeaderSample.Parent
			frame.TextLabel.Text = player
			frame.Name = "Leader"
			frame.Visible = true
		elseif status == "Member" then
			local frame = self.MemberSample:Clone()
			frame.Parent = self.MemberSample.Parent
			frame.TextLabel.Text = player
			frame.Name = "Member"
			frame.Visible = true
			if not Owner then continue end
			self:ConnectKickButtons(frame)
		end
	end
	
	if count == maxParty then return end
	
	
	while count < maxParty do
		count += 1
		local frame = self.OpenSample:Clone()
		frame.Parent = self.OpenSample.Parent
		frame.TextLabel.Text = "Open Slot"
		frame.Name = "Open"
		frame.Visible = true
		if not Owner then continue end
		self:ConnectInviteButtons(frame)
	end
	
	local tempCon 
	tempCon = self.PartyInviteList.PartyTopBar.Exit.Activated:Connect(function()
		self.PartyInviteList.Visible = false
	end)
	table.insert(self.Connections, tempCon)
end

function Party:ConnectKickButtons(frame)
	frame.ImageButton.Activated:Connect(function()
		local PlayerName = frame.TextLabel.Text
		KickPlayerEvent:FireServer(PlayerName)
	end)
end

function Party:ConnectInviteButtons(frame)
	
	for _,frame in ipairs(self.PlayerSample.Parent:GetChildren()) do
		if not frame:IsA("Frame") or frame.Visible == false then continue end
		frame:Destroy()
	end
	
	frame.ImageButton.Activated:Connect(function()
		if self.PartyInviteList.Visible then return end
		self.PartyInviteList.Visible = true
		local players = Players:GetPlayers()
		for _,player in players do
			if self.Party[player.Name] then continue end
			local frameClone = self.PlayerSample:Clone()
			frameClone.TextLabel.Text = player.Name
			frameClone.Parent = self.PlayerSample.Parent
			frameClone.Visible = true
			self:ConnectPlayerInvites(player,frameClone)
		end
	end)
end


function Party:ConnectPlayerInvites(player,frame)
	local Button = frame:FindFirstChild("ImageButton")
	Button.Activated:Connect(function()
		InvitePlayer:FireServer(player)
	end)
end

function Party:FindPlayerChar(playerName)
	local players = Players:GetPlayers()
	for _,player in players do
		if player.Name ~= playerName then continue end
		local char = player.Character 
		return char
	end
end

function Party:ShowPlayerLocations()
	local players = Players:GetPlayers()
	for _,player in players do
		if self.Party[player.Name] then continue end
		local char = player.Character 
		if not char then continue end
		local HRP = char:FindFirstChild("HumanoidRootPart")
		if not HRP then return end
		local billboard = HRP:FindFirstChild("PartyVisual")
		if not billboard then continue end
		billboard.Enabled = false
	end
	
	for player,status in self.Party do
		if player == self.Player.Name then continue end
		print(player.Name, self.Player.Name)
		local char = self:FindPlayerChar(player)
		if not char then continue end
		
		local HRP = char:WaitForChild("HumanoidRootPart")
		local billboard = HRP:WaitForChild("PartyVisual")
		if not billboard then continue end
		billboard.Enabled = true
	end
end

function Party:ConnectLeaveDisband()
	local con 
	if self.Party[self.Player.Name] == "Leader" then 
		con = self.DisbandButton.Activated:Connect(function()
			DisbandEvent:FireServer(self.Player)
		end)
		self.LeaveButton.Visible = false
		self.DisbandButton.Visible = true
	elseif self.Party[self.Player.Name] == "Member" then
		con = self.LeaveButton.Activated:Connect(function()
			local LeaderName = self:GetPartyLeader()
			LeaveEvent:FireServer(LeaderName)
		end)
		self.LeaveButton.Visible = true
		self.DisbandButton.Visible = false
	end
	if con then table.insert(self.Connections, con) end
	
end


function Party:GetPartyLeader()
	if not self.Party then return end
	
	for playerName,status in self.Party do
		if status ~= "Leader" then continue end
		return playerName
	end
end


function Party:Init()
	self.LeaderSample.Visible = false
	self.MemberSample.Visible = false
	self.OpenSample.Visible = false
	self:UpdateWindow()
	self:ConnectLeaveDisband()
	
	self.PartyHub.Visible = true
	
	local tempCon 
	tempCon = ListenToDataParty.OnClientEvent:Connect(function(party)
		if not party then return end
		self.Party = party
		self:UpdateWindow()
	end)
	table.insert(self.Connections , tempCon)
	
	self.Exit.Activated:Once(function()
		self.Exit.closeWindow:Fire()
		self:DestroyInst()
	end)
	
	task.spawn(function()
		while true do
			task.wait(.5)
			if not self or not self.ShowPlayerLocations then return end
			self:ShowPlayerLocations()
		end
	end)
	
end

return Party
