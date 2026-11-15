local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)

local ROAD_COLOR = Color3.fromRGB(85, 70, 140)
local ROAD_THICKNESS = 1
local ROAD_OVERLAP = 4
local SKY_COLOR = Color3.fromRGB(20, 24, 70)
local STAR_COLOR = Color3.fromRGB(255, 230, 80)
local STAR_COUNT = 150
local STAR_SEED = 7
local PLANETS = {
	{ at = Vector3.new(0.78, -250, 0.78), size = 450, color = Color3.fromRGB(255, 160, 200) },
	{ at = Vector3.new(-0.35, 200, 0.4), size = 300, color = Color3.fromRGB(140, 225, 170) },
	{ at = Vector3.new(1.3, 300, 0.1), size = 220, color = Color3.fromRGB(255, 190, 110) },
}

local World = {}

local function flatPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function setupLighting()
	Lighting:ClearAllChildren()
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(70, 70, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 130)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local sky = Instance.new("Sky")
	sky.StarCount = 0
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0
	atmosphere.Color = SKY_COLOR
	atmosphere.Decay = SKY_COLOR
	atmosphere.Glare = 0
	atmosphere.Haze = 10
	atmosphere.Parent = Lighting
end

local function makeStarTemplate(): Part
	local anchor = Instance.new("Part")
	anchor.Name = "Star"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false

	local billboard = Instance.new("BillboardGui")
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "★"
	label.TextScaled = true
	label.TextColor3 = STAR_COLOR
	label.Parent = billboard

	return anchor
end

function World.build(track: Track.Track)
	setupLighting()

	local folder = Instance.new("Folder")
	folder.Name = "World"

	local points = track.points
	for i, a in points do
		local b = points[i % #points + 1]
		local length = (b - a).Magnitude
		flatPart(
			Enum.PartType.Block,
			Vector3.new(track.width, ROAD_THICKNESS, length + ROAD_OVERLAP),
			CFrame.lookAt((a + b) / 2, b) - Vector3.yAxis * ROAD_THICKNESS / 2,
			ROAD_COLOR,
			folder
		)
	end

	local start, tangent = Track.sample(track, 0)
	flatPart(Enum.PartType.Block, Vector3.new(track.width, 0.2, 4), CFrame.lookAt(start, start + tangent), Color3.new(1, 1, 1), folder)

	local rng = Random.new(STAR_SEED)
	local star = makeStarTemplate()
	for _ = 1, STAR_COUNT do
		local center, along = Track.sample(track, rng:NextNumber(0, track.length))
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local lateral = side * (track.width / 2 + rng:NextNumber(10, 250))
		local size = rng:NextNumber(8, 20)
		local stamp = star:Clone()
		stamp.Position = center + along:Cross(Vector3.yAxis) * lateral + Vector3.yAxis * rng:NextNumber(-150, 150)
		stamp.BillboardGui.Size = UDim2.fromScale(size, size)
		stamp.Parent = folder
	end

	local min, max = points[1], points[1]
	for _, p in points do
		min, max = min:Min(p), max:Max(p)
	end
	for _, planet in PLANETS do
		local at = Vector3.new(min.X + (max.X - min.X) * planet.at.X, planet.at.Y, min.Z + (max.Z - min.Z) * planet.at.Z)
		flatPart(Enum.PartType.Ball, Vector3.one * planet.size, CFrame.new(at), planet.color, folder)
	end

	folder.Parent = workspace
end

return World
