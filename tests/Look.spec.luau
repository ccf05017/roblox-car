local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)

local AMBIENT = Color3.fromRGB(70, 70, 90):ToHex()
local ROAD = Color3.fromRGB(85, 70, 140):ToHex()
local OLD_ROAD = Color3.fromRGB(190, 175, 250):ToHex()

return function(): string
	local lines = {}
	local failed = 0
	local function check(name: string, ok: boolean, detail: any?)
		if not ok then
			failed += 1
		end
		table.insert(lines, (if ok then "PASS " else "FAIL ") .. name .. (if ok or detail == nil then "" else " :: " .. tostring(detail)))
	end
	local function waitFor(predicate: () -> any, timeout: number): any
		local deadline = os.clock() + timeout
		repeat
			local value = predicate()
			if value then
				return value
			end
			task.wait(0.1)
		until os.clock() > deadline
		return nil
	end

	local world = waitFor(function()
		return workspace:FindFirstChild("World")
	end, 10)
	local cars = {}
	for _, name in { "player", "ai" } do
		local car = waitFor(function()
			return workspace:FindFirstChild(name)
		end, 10)
		check(name .. " car spawned", car ~= nil)
		table.insert(cars, car)
	end
	check("world built", world ~= nil)

	check("lighting brightness is 3", Lighting.Brightness == 3, Lighting.Brightness)
	check("global shadows are on", Lighting.GlobalShadows)
	check("ambient is 70,70,90", Lighting.Ambient:ToHex() == AMBIENT, Lighting.Ambient:ToHex())

	local worldParts = if world then world:GetDescendants() else {}
	local roads, offColour, oldColour = 0, 0, 0
	for _, part in worldParts do
		if part:IsA("BasePart") then
			local hex = part.Color:ToHex()
			if hex == OLD_ROAD then
				oldColour += 1
			end
			local isRoad = part:IsA("Part") and part.Shape == Enum.PartType.Block and part.Size.X == Track.SPEC.width and part.Size.Y >= 1
			if isRoad then
				roads += 1
				if hex ~= ROAD then
					offColour += 1
				end
			end
		end
	end
	check("world has road parts", roads > 0)
	check("every road part is dark purple 85,70,140", roads > 0 and offColour == 0, offColour .. " of " .. roads .. " off colour")
	check("no world part keeps the old road colour", oldColour == 0, oldColour)

	local highlight = workspace:FindFirstChildWhichIsA("Highlight", true)
	check("no Highlight outline in workspace", highlight == nil, highlight and highlight:GetFullName())

	local textures = {}
	for _, car in cars do
		local textured = nil
		for _, part in car:GetDescendants() do
			if part:IsA("MeshPart") and part.TextureID ~= "" and part.Transparency == 0 then
				textured = part
				break
			end
		end
		check(car.Name .. " car shows an opaque textured MeshPart", textured ~= nil)
		textures[car.Name] = if textured then textured.TextureID else nil
	end
	check("player and ai cars show different textures", textures.player ~= nil and textures.ai ~= nil and textures.player ~= textures.ai, tostring(textures.player) .. " vs " .. tostring(textures.ai))

	table.insert(lines, 1, string.format("%d checks, %d failed", #lines, failed))
	return table.concat(lines, "\n")
end
