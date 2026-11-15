local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)
local Scenery = require(script.Parent.Scenery)

local SEED = 37
local TILE = 8
local TILE_GAP = 1
local LANE_GAP = 0.6
local LANES = 4
local CRYSTAL = {
	Color3.fromRGB(79, 107, 155),
	Color3.fromRGB(103, 91, 151),
	Color3.fromRGB(75, 123, 143),
	Color3.fromRGB(120, 96, 148),
}
-- Neon shines as bright as its colour, so this dims the road's own light without changing its hues.
local ROAD_GLOW = 0.8
local RAIL = Color3.fromRGB(135, 115, 80)
local RAIL_HEIGHT = 2.2
local POST_EVERY = 16
local POST_WIDTH = 0.5
local SHARDS = 100
local SHARD_SIDES = 6
local SHARD_COLORS = { Color3.fromRGB(50, 140, 220), Color3.fromRGB(210, 80, 170), Color3.fromRGB(120, 90, 220) }
local SHARD_TIP = Color3.fromRGB(190, 225, 255)
local PLANET_CENTER = Vector3.new(0, 180, 0)
local PLANET_RADIUS = 140
local PLANET_BANDS = {
	Color3.fromRGB(195, 120, 80),
	Color3.fromRGB(170, 85, 90),
	Color3.fromRGB(205, 150, 105),
	Color3.fromRGB(150, 75, 115),
}
local PLANET_SHADE = Color3.fromRGB(25, 10, 35)
local PLANET_LIGHT = Vector3.new(0.5, 0.6, -0.6).Unit
local RING_TILT = math.rad(9)
local RING_BANDS = {
	{ inner = 300, outer = 360, color = Color3.fromRGB(190, 145, 95) },
	{ inner = 372, outer = 430, color = Color3.fromRGB(165, 95, 135) },
	{ inner = 440, outer = 455, color = Color3.fromRGB(210, 180, 140) },
	{ inner = 468, outer = 530, color = Color3.fromRGB(105, 90, 185) },
}
local RING_SEGMENTS = 96
local START_LINE_COLOR = Color3.new(1, 1, 1)

local function tileColor(s: number, lane: number): Color3
	local rng = Random.new(math.floor(s / TILE) * LANES + lane)
	return CRYSTAL[rng:NextInteger(1, #CRYSTAL)]:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.15)):Lerp(Color3.new(), 1 - ROAD_GLOW)
end

local function lanes(half: number): { { Vector2 } }
	local strips = {}
	local width = (2 * half - (LANES - 1) * LANE_GAP) / LANES
	for lane = 0, LANES - 1 do
		local left = -half + lane * (width + LANE_GAP)
		table.insert(strips, { Vector2.new(left, 0), Vector2.new(left + width, 0) })
	end
	return strips
end

local function posts(track: Track.Track, half: number): { Scenery.Quad }
	local quads = {}
	for k = 0, math.floor(track.length / POST_EVERY) - 1 do
		local frame = Track.frame(track, k * POST_EVERY)
		for _, side in { -1, 1 } do
			local base = frame * CFrame.new(side * half, 0, 0)
			local a, b = base * Vector3.new(0, 0, -POST_WIDTH), base * Vector3.new(0, 0, POST_WIDTH)
			local up = frame.UpVector * RAIL_HEIGHT
			table.insert(quads, { corners = { a, b, b + up, a + up }, colors = { RAIL, RAIL, RAIL, RAIL } })
		end
	end
	return quads
end

local function ring(): { Scenery.Quad }
	local tilt = CFrame.new(PLANET_CENTER) * CFrame.Angles(RING_TILT, 0, RING_TILT / 2)
	local quads = {}
	for _, band in RING_BANDS do
		for i = 0, RING_SEGMENTS - 1 do
			local a0, a1 = i / RING_SEGMENTS * 2 * math.pi, (i + 1) / RING_SEGMENTS * 2 * math.pi
			local function at(angle: number, radius: number): Vector3
				return tilt * Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			end
			local c = band.color
			table.insert(quads, { corners = { at(a0, band.inner), at(a1, band.inner), at(a1, band.outer), at(a0, band.outer) }, colors = { c, c, c, c } })
		end
	end
	return quads
end

local function shards(track: Track.Track, rng: Random): { Scenery.Quad }
	local quads = {}
	for _ = 1, SHARDS do
		local frame = Track.frame(track, rng:NextNumber(0, track.length))
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local at = frame * CFrame.new(side * rng:NextNumber(track.width, 160), rng:NextNumber(-90, 60), 0)
		local pose = CFrame.new(at.Position) * CFrame.Angles(rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0, 2 * math.pi))
		local length = rng:NextNumber(6, 20)
		local girth = length * rng:NextNumber(0.15, 0.25)
		local color = SHARD_COLORS[rng:NextInteger(1, #SHARD_COLORS)]
		local top, bottom = pose * Vector3.new(0, length / 2, 0), pose * Vector3.new(0, -length / 2, 0)
		for i = 0, SHARD_SIDES - 1 do
			local function rim(k: number): Vector3
				local angle = k / SHARD_SIDES * 2 * math.pi
				return pose * Vector3.new(math.cos(angle) * girth, 0, math.sin(angle) * girth)
			end
			local a, b = rim(i), rim(i + 1)
			table.insert(quads, { corners = { a, b, top, top }, colors = { color, color, SHARD_TIP, SHARD_TIP } })
			table.insert(quads, { corners = { b, a, bottom, bottom }, colors = { color, color, SHARD_TIP, SHARD_TIP } })
		end
	end
	return quads
end

local function planet(): { Scenery.Quad }
	return Scenery.sphere(PLANET_CENTER, PLANET_RADIUS, function(normal)
		local band = PLANET_BANDS[math.floor((normal.Y + 1) * 5.5) % #PLANET_BANDS + 1]
		return PLANET_SHADE:Lerp(band, math.clamp(normal:Dot(PLANET_LIGHT) * 0.7 + 0.55, 0, 1))
	end)
end

local World = {}

function World.build(track: Track.Track)
	Lighting:ClearAllChildren()
	local folder = Instance.new("Folder")
	folder.Name = "World"
	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = folder
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	Scenery.night({
		ambient = Color3.fromRGB(175, 170, 200),
		brightness = 1.8,
		tint = Color3.fromRGB(250, 240, 255),
		saturation = 0.1,
	})

	local half = track.width / 2
	Scenery.mesh(road, Scenery.sweep(track, {
		strips = lanes(half),
		step = TILE,
		gap = TILE_GAP,
		paint = function(s, x)
			return tileColor(s, math.min(math.floor((x + half) / (2 * half) * LANES), LANES - 1))
		end,
	}), { name = "Tiles", material = Enum.Material.Neon, transparency = 0.3, essential = true })

	Scenery.mesh(road, Scenery.sweep(track, {
		strips = {
			{ Vector2.new(-half, RAIL_HEIGHT - 0.4), Vector2.new(-half, RAIL_HEIGHT) },
			{ Vector2.new(half, RAIL_HEIGHT - 0.4), Vector2.new(half, RAIL_HEIGHT) },
			{ Vector2.new(-half, 0), Vector2.new(-half, 0.5) },
			{ Vector2.new(half, 0), Vector2.new(half, 0.5) },
		},
		step = 6,
		paint = Scenery.solid(RAIL),
	}), { name = "Rails", material = Enum.Material.Neon })
	Scenery.mesh(road, posts(track, half), { name = "Posts", material = Enum.Material.Neon })

	local rng = Random.new(SEED)
	Scenery.mesh(decor, planet(), { name = "Planet", material = Enum.Material.Neon })
	Scenery.mesh(decor, ring(), { name = "Ring", material = Enum.Material.Neon, transparency = 0.55 })
	Scenery.mesh(decor, shards(track, rng), { name = "Shards", transparency = 0.3 })

	Scenery.sky(decor, {
		planets = {
			{ direction = Vector3.new(-0.7, 0.35, -0.5), size = 50, light = Color3.fromRGB(170, 210, 255), dark = Color3.fromRGB(25, 35, 90) },
		},
		stars = { Color3.fromRGB(255, 250, 235), Color3.fromRGB(200, 225, 255), Color3.fromRGB(255, 215, 240) },
		clouds = { Color3.fromRGB(90, 120, 255), Color3.fromRGB(230, 110, 220), Color3.fromRGB(120, 80, 220) },
		bandTilt = 35,
		bandStars = 2600,
		looseStars = 1000,
		cloudCount = 40,
		cloudTransparency = 0.6,
		sparkles = 40,
	}, rng)

	local start = Track.frame(track, 0)
	Scenery.part(folder, Vector3.new(track.width, 0.2, 4), start * CFrame.new(0, 0.15, 0), START_LINE_COLOR)

	folder.Parent = workspace
end

return World
