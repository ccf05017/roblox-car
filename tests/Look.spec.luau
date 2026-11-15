local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)
local Courses = require(ReplicatedStorage.Shared.Courses)

local MIN_STARS = 3000
local ROAD_PROBE_EVERY = 10
local ROAD_REACH = 2
local GRID = 8
local MAX_PARTS = 8000

local function insideBox(part: BasePart, point: Vector3, margin: number): boolean
	local offset = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.one * margin
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

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

	local chosen = waitFor(function()
		return workspace:GetAttribute("Course")
	end, 30)
	local course = nil
	for _, candidate in Courses do
		if candidate.id == chosen then
			course = candidate
		end
	end
	check("a course from Courses is chosen", course ~= nil, chosen)
	if not course then
		return table.concat(lines, "\n")
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
	check("world built for " .. course.id, world ~= nil and world:GetAttribute("Course") == course.id, world and world:GetAttribute("Course"))
	if not world then
		return table.concat(lines, "\n")
	end

	local sky = Lighting:FindFirstChildOfClass("Sky")
	check("night sky full of stars", sky ~= nil and sky.StarCount >= MIN_STARS and Lighting.ClockTime < 3, sky and string.format("%d stars at %.1f h", sky.StarCount, Lighting.ClockTime))
	check("bloom makes the neon glow", Lighting:FindFirstChildOfClass("BloomEffect") ~= nil)

	local function cell(point: Vector3): string
		return string.format("%d,%d,%d", point.X // GRID, point.Y // GRID, point.Z // GRID)
	end
	local blocks, vertices = {}, {}
	local neon = 0
	for _, part in world.Road:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Material == Enum.Material.Neon then
				neon += 1
			end
			local mesh = if part:IsA("MeshPart") then part.MeshContent.Object else nil
			if mesh and mesh:IsA("EditableMesh") then
				for _, vertex in mesh:GetVertices() do
					local point = part.CFrame * mesh:GetPosition(vertex)
					local key = cell(point)
					vertices[key] = vertices[key] or {}
					table.insert(vertices[key], point)
				end
			else
				table.insert(blocks, part)
			end
		end
	end
	check("road has glowing neon trim", neon > 0)

	local function covered(point: Vector3): boolean
		for _, part in blocks do
			if insideBox(part, point, ROAD_REACH) then
				return true
			end
		end
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					for _, vertex in vertices[cell(point + Vector3.new(dx, dy, dz) * GRID)] or {} do
						if (vertex - point).Magnitude <= ROAD_REACH then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local track = Track.build(course.spec)
	local probes, missing, firstMissing = 0, 0, nil
	for s = 0, track.length - 1, ROAD_PROBE_EVERY do
		probes += 1
		if not covered(Track.frame(track, s).Position) then
			missing += 1
			firstMissing = firstMissing or s
		end
	end
	check("road runs under the whole lap", missing == 0, string.format("%d of %d spots bare, first at s=%s", missing, probes, tostring(firstMissing)))

	local parts = 0
	for _, item in workspace:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
		end
	end
	check("workspace stays under " .. MAX_PARTS .. " parts", parts < MAX_PARTS, parts)
	local loose = nil
	for _, item in world:GetDescendants() do
		if item:IsA("BasePart") and (item.CanCollide or not item.Anchored) then
			loose = item
			break
		end
	end
	check("every world part is anchored and never collides", loose == nil, loose and loose:GetFullName())

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
