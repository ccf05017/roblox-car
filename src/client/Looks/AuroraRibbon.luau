local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)
local Scenery = require(script.Parent.Parent.Scenery)

local SEED = 23
local AURORA = {
	Color3.fromRGB(0, 225, 205),
	Color3.fromRGB(70, 255, 140),
	Color3.fromRGB(150, 95, 255),
	Color3.fromRGB(255, 95, 200),
}
local CYCLES_PER_LAP = 2
local DECK_DEPTH = 0.35
local DECK_EDGE = 0.7
local NIGHT = Color3.fromRGB(4, 10, 24)
local FIBERS = { -12, -6, 6, 12 }
local FIBER_WIDTH = 0.35
local EDGE_WIDTH = 1.5
local RAIL_HEIGHT = 1.4
local ARCH_EVERY = 150
local ARCH_SEGMENTS = 40
local ARCH_RADIUS = 27
local ARCH_RISE = 6
local ARCH_THICKNESS = 2.2
local BEACON_SPACING = 60
local TRIM_STEP = 6

local function aurora(track: Track.Track, s: number): Color3
	local t = (s / track.length * CYCLES_PER_LAP * #AURORA) % #AURORA
	local i = math.floor(t)
	return AURORA[i + 1]:Lerp(AURORA[(i + 1) % #AURORA + 1], t - i)
end

local function arches(track: Track.Track): { Scenery.Quad }
	local quads = {}
	for k = 1, math.floor(track.length / ARCH_EVERY) - 1 do
		local s = k * ARCH_EVERY
		local center = Track.frame(track, s) * CFrame.new(0, ARCH_RISE, 0)
		local color = aurora(track, s):Lerp(Color3.new(1, 1, 1), 0.25)
		for i = 0, ARCH_SEGMENTS - 1 do
			local a0, a1 = i / ARCH_SEGMENTS * 2 * math.pi, (i + 1) / ARCH_SEGMENTS * 2 * math.pi
			local function at(angle: number, radius: number): Vector3
				return center * Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
			end
			table.insert(quads, {
				corners = { at(a0, ARCH_RADIUS), at(a1, ARCH_RADIUS), at(a1, ARCH_RADIUS + ARCH_THICKNESS), at(a0, ARCH_RADIUS + ARCH_THICKNESS) },
				colors = { color, color, color, color },
			})
		end
	end
	return quads
end

local function build(track: Track.Track, road: Folder, decor: Folder)
	Scenery.night({
		ambient = Color3.fromRGB(95, 120, 140),
		brightness = 1.5,
		bloom = 1.4,
		tint = Color3.fromRGB(230, 250, 255),
		saturation = 0.3,
	})

	local half = track.width / 2
	Scenery.mesh(road, Scenery.sweep(track, {
		strips = { { Vector2.new(-half, 0), Vector2.new(0, 0), Vector2.new(half, 0) } },
		paint = function(s, x)
			return NIGHT:Lerp(aurora(track, s), DECK_DEPTH + (DECK_EDGE - DECK_DEPTH) * math.abs(x) / half)
		end,
	}), { name = "Deck", transparency = 0.2, essential = true })

	local fibers = {}
	for _, x in FIBERS do
		table.insert(fibers, { Vector2.new(x - FIBER_WIDTH, 0.05), Vector2.new(x + FIBER_WIDTH, 0.05) })
	end
	table.insert(fibers, { Vector2.new(-half, 0), Vector2.new(-half, RAIL_HEIGHT) })
	table.insert(fibers, { Vector2.new(half, 0), Vector2.new(half, RAIL_HEIGHT) })
	Scenery.mesh(road, Scenery.join(
		Scenery.sweep(track, {
			strips = fibers,
			step = TRIM_STEP,
			paint = function(s)
				return aurora(track, s):Lerp(Color3.new(1, 1, 1), 0.2)
			end,
		}),
		arches(track)
	), { name = "Trim", material = Enum.Material.Neon })

	Scenery.mesh(road, Scenery.sweep(track, {
		strips = {
			{ Vector2.new(-half - EDGE_WIDTH, RAIL_HEIGHT + 1), Vector2.new(-half, RAIL_HEIGHT) },
			{ Vector2.new(half, RAIL_HEIGHT), Vector2.new(half + EDGE_WIDTH, RAIL_HEIGHT + 1) },
		},
		step = TRIM_STEP,
		paint = function(s)
			return aurora(track, s + 400)
		end,
	}), { name = "Glow", material = Enum.Material.Neon, transparency = 0.7 })

	local beaconColors = {}
	for i = 1, 8 do
		beaconColors[i] = AURORA[(i - 1) % #AURORA + 1]
	end
	Scenery.beacons(track, decor, BEACON_SPACING, beaconColors)

	local rng = Random.new(SEED)
	Scenery.sky(decor, {
		planets = {
			{ direction = Vector3.new(-0.3, -0.35, 0.9), size = 170, light = Color3.fromRGB(175, 245, 255), dark = Color3.fromRGB(15, 55, 85), bands = 5 },
			{ direction = Vector3.new(0.8, 0.4, -0.3), size = 55, light = Color3.fromRGB(240, 185, 255), dark = Color3.fromRGB(60, 25, 90) },
		},
		stars = { Color3.fromRGB(235, 255, 250), Color3.fromRGB(180, 255, 225), Color3.fromRGB(215, 200, 255) },
		clouds = AURORA,
		bandTilt = 14,
		bandStars = 1200,
		looseStars = 2200,
		cloudCount = 80,
		cloudTransparency = 0.45,
		sparkles = 24,
	}, rng)
end

return {
	accent = AURORA[2],
	build = build,
}
