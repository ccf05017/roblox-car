local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)
local Scenery = require(script.Parent.Scenery)

export type Look = {
	accent: Color3,
	build: (track: Track.Track, road: Folder, decor: Folder) -> (),
}

local START_LINE_COLOR = Color3.new(1, 1, 1)

local World = {}

function World.look(courseId: string): Look
	return require(script.Parent.Looks:FindFirstChild(courseId)) :: any
end

function World.build(track: Track.Track, courseId: string)
	Lighting:ClearAllChildren()
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder:SetAttribute("Course", courseId)

	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	World.look(courseId).build(track, road, decor)

	local start = Track.frame(track, 0)
	Scenery.part(folder, Enum.PartType.Block, Vector3.new(track.width, 0.2, 4), start * CFrame.new(0, 0.15, 0), START_LINE_COLOR, Enum.Material.Neon)

	folder.Parent = workspace
end

return World
