local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Track = require(ReplicatedStorage.Shared.Track)
local Scenery = require(script.Parent.Parent.Scenery)

local SEED = 11
local DECK_CORE = Color3.fromRGB(16, 10, 52)
local DECK_EDGE = Color3.fromRGB(70, 36, 150)
local DECK_STRIPE = Color3.fromRGB(34, 22, 96)
local STRIPE_EVERY = 24
local LEFT_RAIL = Color3.fromRGB(60, 230, 255)
local RIGHT_RAIL = Color3.fromRGB(255, 70, 200)
local DASH = Color3.fromRGB(200, 220, 255)
local DUST = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 210, 255), Color3.fromRGB(255, 175, 235) }
local ROAD_DUST = 1400
local RAIL_HEIGHT = 1.2
local WING = 5
local BEACON_SPACING = 45
local PLANETS = {
	{ at = Vector3.new(2300, 250, -900), size = 900, color = Color3.fromRGB(110, 150, 255), glow = Color3.fromRGB(120, 180, 255) },
	{ at = Vector3.new(-1100, 520, 1300), size = 380, color = Color3.fromRGB(255, 160, 215), glow = Color3.fromRGB(255, 120, 220) },
	{ at = Vector3.new(700, -500, 300), size = 600, color = Color3.fromRGB(150, 110, 230), glow = Color3.fromRGB(170, 110, 255) },
}

local function roadDust(track: Track.Track, rng: Random): { Scenery.Quad }
	local quads = {}
	local half = track.width / 2 - 1.5
	for i = 1, ROAD_DUST do
		local s = i / ROAD_DUST * track.length
		local frame = Track.frame(track, s) * CFrame.new(rng:NextNumber(-half, half), 0.06, 0)
		local size = rng:NextNumber(0.25, 0.6)
		local r, f = frame.RightVector * size / 2, frame.LookVector * size / 2
		local at = frame.Position
		local color = DUST[rng:NextInteger(1, #DUST)]
		table.insert(quads, { corners = { at - r - f, at + r - f, at + r + f, at - r + f }, colors = { color, color, color, color } })
	end
	return quads
end

local function build(track: Track.Track, road: Folder, decor: Folder)
	Scenery.night({
		ambient = Color3.fromRGB(110, 100, 160),
		brightness = 1.5,
		bloom = 1.3,
		tint = Color3.fromRGB(240, 235, 255),
		saturation = 0.2,
	})

	local half = track.width / 2
	Scenery.mesh(road, Scenery.sweep(track, {
		strips = { { Vector2.new(-half, 0), Vector2.new(0, 0), Vector2.new(half, 0) } },
		paint = function(s, x)
			local core = if math.floor(s / STRIPE_EVERY) % 2 == 0 then DECK_CORE else DECK_STRIPE
			return core:Lerp(DECK_EDGE, math.abs(x) / half)
		end,
	}), { name = "Deck", transparency = 0.12, essential = true })

	local rng = Random.new(SEED)
	Scenery.mesh(road, Scenery.join(
		Scenery.sweep(track, {
			strips = { { Vector2.new(-half, 0), Vector2.new(-half, RAIL_HEIGHT) }, { Vector2.new(half, 0), Vector2.new(half, RAIL_HEIGHT) } },
			paint = function(_, x)
				return if x < 0 then LEFT_RAIL else RIGHT_RAIL
			end,
		}),
		Scenery.sweep(track, {
			strips = { { Vector2.new(-0.3, 0.05), Vector2.new(0.3, 0.05) } },
			step = 12,
			gap = 6,
			paint = Scenery.solid(DASH),
		}),
		roadDust(track, rng)
	), { name = "Trim", material = Enum.Material.Neon })

	Scenery.mesh(road, Scenery.sweep(track, {
		strips = {
			{ Vector2.new(-half, RAIL_HEIGHT), Vector2.new(-half - WING, -0.6) },
			{ Vector2.new(half, RAIL_HEIGHT), Vector2.new(half + WING, -0.6) },
		},
		paint = function(_, x)
			return if x < 0 then LEFT_RAIL else RIGHT_RAIL
		end,
	}), { name = "Glow", material = Enum.Material.Neon, transparency = 0.78 })

	Scenery.beacons(track, decor, BEACON_SPACING, { LEFT_RAIL, RIGHT_RAIL })

	Scenery.sky(decor, {
		stars = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 215, 255), Color3.fromRGB(255, 200, 240), Color3.fromRGB(255, 240, 210) },
		clouds = { Color3.fromRGB(150, 70, 255), Color3.fromRGB(255, 80, 190), Color3.fromRGB(60, 140, 255) },
		bandTilt = 62,
		bandStars = 4200,
		looseStars = 700,
		cloudCount = 46,
		cloudTransparency = 0.55,
		sparkles = 30,
	}, rng)

	for _, planet in PLANETS do
		Scenery.part(decor, Enum.PartType.Ball, Vector3.one * planet.size, CFrame.new(planet.at), planet.color)
		Scenery.part(decor, Enum.PartType.Ball, Vector3.one * planet.size * 1.06, CFrame.new(planet.at), planet.glow, Enum.Material.Neon, 0.85)
	end
end

return {
	accent = LEFT_RAIL,
	build = build,
}
