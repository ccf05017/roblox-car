local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)
local Course = require(ReplicatedStorage.Shared.Course)

local MIN_STARS = 3000
local ROAD_PROBE_EVERY = 10
local ROAD_REACH = 1
local GRID = 16
local MAX_PARTS = 8000

local function insideBox(part: BasePart, point: Vector3, margin: number): boolean
	local offset = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.one * margin
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

local function nearestOnTriangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3): Vector3
	local ab, ac, ap = b - a, c - a, p - a
	local d1, d2 = ab:Dot(ap), ac:Dot(ap)
	if d1 <= 0 and d2 <= 0 then
		return a
	end
	local bp = p - b
	local d3, d4 = ab:Dot(bp), ac:Dot(bp)
	if d3 >= 0 and d4 <= d3 then
		return b
	end
	local vc = d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0 then
		return a + ab * (d1 / (d1 - d3))
	end
	local cp = p - c
	local d5, d6 = ab:Dot(cp), ac:Dot(cp)
	if d6 >= 0 and d5 <= d6 then
		return c
	end
	local vb = d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0 then
		return a + ac * (d2 / (d2 - d6))
	end
	local va = d3 * d6 - d5 * d4
	if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0 then
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	end
	local denom = 1 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
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

	local world = waitFor(function()
		return workspace:FindFirstChild("World")
	end, 30)
	local cars = {}
	for _, name in { "player", "ai" } do
		local car = waitFor(function()
			return workspace:FindFirstChild(name)
		end, 10)
		check(name .. " car spawned", car ~= nil)
		table.insert(cars, car)
	end
	check("world built", world ~= nil)
	if not world then
		return table.concat(lines, "\n")
	end

	local sky = Lighting:FindFirstChildOfClass("Sky")
	check("night sky full of stars", sky ~= nil and sky.StarCount >= MIN_STARS and Lighting.ClockTime < 3, sky and string.format("%d stars at %.1f h", sky.StarCount, Lighting.ClockTime))
	check("bloom makes the neon glow", Lighting:FindFirstChildOfClass("BloomEffect") ~= nil)

	local function cell(point: Vector3): string
		return string.format("%d,%d,%d", point.X // GRID, point.Y // GRID, point.Z // GRID)
	end
	local blocks, triangles = {}, {}
	local neon = 0
	for _, part in world.Road:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Material == Enum.Material.Neon then
				neon += 1
			end
			local mesh = if part:IsA("MeshPart") then part.MeshContent.Object else nil
			if mesh and mesh:IsA("EditableMesh") then
				for _, face in mesh:GetFaces() do
					local corners = {}
					for k, vertex in mesh:GetFaceVertices(face) do
						corners[k] = part.CFrame * mesh:GetPosition(vertex)
					end
					local key = cell((corners[1] + corners[2] + corners[3]) / 3)
					triangles[key] = triangles[key] or {}
					table.insert(triangles[key], corners)
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
					for _, corners in triangles[cell(point + Vector3.new(dx, dy, dz) * GRID)] or {} do
						if (nearestOnTriangle(point, corners[1], corners[2], corners[3]) - point).Magnitude <= ROAD_REACH then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local track = Track.build(Course)
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
