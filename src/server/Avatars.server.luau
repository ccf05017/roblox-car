local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function spawnAvatar(player: Player)
	player:LoadCharacter()
end
Players.PlayerAdded:Connect(spawnAvatar)
for _, player in Players:GetPlayers() do
	task.spawn(spawnAvatar, player)
end

local orange = Color3.fromRGB(255, 140, 0)
local navy = Color3.fromRGB(60, 60, 80)
local description = Instance.new("HumanoidDescription")
description.HeadColor = Color3.fromRGB(255, 220, 170)
description.TorsoColor = orange
description.LeftArmColor = orange
description.RightArmColor = orange
description.LeftLegColor = navy
description.RightLegColor = navy
local aiRider = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
aiRider.Name = "AiRider"
aiRider.Parent = ReplicatedStorage
