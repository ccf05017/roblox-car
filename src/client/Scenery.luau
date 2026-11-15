local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Track = require(ReplicatedStorage.Shared.Track)

export type Quad = { corners: { Vector3 }, colors: { Color3 } }

export type Surface = {
	name: string,
	material: Enum.Material?,
	transparency: number?,
	essential: boolean?,
}

export type Sweep = {
	strips: { { Vector2 } },
	step: number?,
	gap: number?,
	paint: (s: number, x: number) -> Color3,
}

export type Planet = {
	direction: Vector3,
	size: number,
	light: Color3,
	dark: Color3,
	bands: number?,
}

export type Sky = {
	planets: { Planet },
	stars: { Color3 },
	clouds: { Color3 },
	bandTilt: number,
	bandStars: number,
	looseStars: number,
	cloudCount: number,
	cloudTransparency: number,
	sparkles: number,
}

export type Night = {
	ambient: Color3,
	brightness: number,
	bloom: number,
	tint: Color3,
	saturation: number,
}

-- An EditableMesh holds at most 20000 triangles, and each quad is four (both windings).
local QUADS_PER_MESH = 4900
local MAX_MESH_EXTENT = 2000
local FALLBACK_THICKNESS = 0.3
local FALLBACK_OVERLAP = 0.4
local WHITE = Color3.new(1, 1, 1)
local SKY_RADIUS = 950
local PLANET_DISTANCE = 820
local SUN = Vector3.new(0.6, 0.5, -0.6).Unit
local SPHERE_RINGS = 16
local SPHERE_SEGMENTS = 32
local BAND_SPREAD = 0.33
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local Scenery = {}

function Scenery.part(parent: Instance, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function finish(part: BasePart, surface: Surface, parent: Instance)
	part.Name = surface.name
	part.Material = surface.material or Enum.Material.SmoothPlastic
	part.Transparency = surface.transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
end

local function meshPart(mesh: EditableMesh, quads: { Quad }, center: Vector3, surface: Surface, parent: Instance)
	for _, quad in quads do
		local paint = {}
		for k, color in quad.colors do
			paint[k] = mesh:AddColor(color, 1)
		end
		-- Both windings, so every surface shows from above, from below and from inside the corkscrew.
		for _, order in { { 1, 2, 3, 4 }, { 4, 3, 2, 1 } } do
			local vertices, colors = {}, {}
			for k, corner in order do
				vertices[k] = mesh:AddVertex(quad.corners[corner] - center)
				colors[k] = paint[corner]
			end
			local a = mesh:AddTriangle(vertices[1], vertices[2], vertices[3])
			mesh:SetFaceColors(a, { colors[1], colors[2], colors[3] })
			local b = mesh:AddTriangle(vertices[1], vertices[3], vertices[4])
			mesh:SetFaceColors(b, { colors[1], colors[3], colors[4] })
		end
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
	part.CFrame = CFrame.new(center)
	part.Color = WHITE
	finish(part, surface, parent)
end

local function quadParts(quads: { Quad }, surface: Surface, parent: Instance)
	for _, quad in quads do
		local c = quad.corners
		local across, along = c[2] - c[1], c[4] - c[1]
		local x = across.Unit
		local z = (along - x * x:Dot(along)).Unit
		local part = Instance.new("Part")
		part.Size = Vector3.new(across.Magnitude, FALLBACK_THICKNESS, along.Magnitude + FALLBACK_OVERLAP)
		part.CFrame = CFrame.fromMatrix((c[1] + c[2] + c[3] + c[4]) / 4, x, z:Cross(x), z)
		part.Color = quad.colors[1]
		finish(part, surface, parent)
	end
end

-- The client only grants a handful of EditableMeshes, so pack each surface into as few as the size limits allow.
function Scenery.mesh(parent: Instance, quads: { Quad }, surface: Surface)
	local first = 1
	while first <= #quads do
		local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
		local last = first - 1
		while last < #quads and last - first + 1 < QUADS_PER_MESH do
			local grownLow, grownHigh = low, high
			for _, corner in quads[last + 1].corners do
				grownLow, grownHigh = grownLow:Min(corner), grownHigh:Max(corner)
			end
			local extent = grownHigh - grownLow
			if math.max(extent.X, extent.Y, extent.Z) > MAX_MESH_EXTENT then
				break
			end
			low, high, last = grownLow, grownHigh, last + 1
		end

		local chunk = table.move(quads, first, last, 1, {})
		local mesh = AssetService:CreateEditableMesh()
		if mesh then
			meshPart(mesh, chunk, (low + high) / 2, surface, parent)
		elseif surface.essential then
			warn("[World] out of EditableMesh budget, building " .. surface.name .. " from parts")
			quadParts(chunk, surface, parent)
		else
			warn("[World] out of EditableMesh budget, skipping " .. surface.name)
			return
		end
		first = last + 1
	end
end

function Scenery.solid(color: Color3): (number, number) -> Color3
	return function()
		return color
	end
end

function Scenery.facing(at: Vector3, toward: Vector3, size: number, color: Color3): Quad
	local frame = CFrame.lookAt(at, toward)
	local r, u = frame.RightVector * size / 2, frame.UpVector * size / 2
	return { corners = { at - r - u, at + r - u, at + r + u, at - r + u }, colors = { color, color, color, color } }
end

function Scenery.billboard(parent: Instance, at: Vector3, size: number, image: string, color: Color3, transparency: number): Part
	local anchor = Scenery.part(parent, Enum.PartType.Block, Vector3.one, CFrame.new(at), color, nil, 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size, size)
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("ImageLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Image = image
	label.ImageColor3 = color
	label.ImageTransparency = transparency
	label.Parent = gui
	return anchor
end

-- The sky rides along with the camera so it can sit inside the mesh size limit and still never get closer.
function Scenery.sky(decor: Instance, sky: Sky, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Sky"
	local band = CFrame.fromAxisAngle(Vector3.new(1, 0, 0.4).Unit, math.rad(sky.bandTilt))
	local function inBand(spread: number): Vector3
		local around = rng:NextNumber(0, 2 * math.pi)
		local off = rng:NextNumber(-1, 1) ^ 3 * spread
		return band:VectorToWorldSpace(Vector3.new(math.cos(around) * math.cos(off), math.sin(off), math.sin(around) * math.cos(off)))
	end

	local stars = {}
	for i = 1, sky.bandStars + sky.looseStars do
		local direction = if i <= sky.bandStars then inBand(BAND_SPREAD) else rng:NextUnitVector()
		local size = SKY_RADIUS * rng:NextNumber(0.0012, 0.0035)
		table.insert(stars, Scenery.facing(direction * SKY_RADIUS, Vector3.zero, size, sky.stars[rng:NextInteger(1, #sky.stars)]))
	end
	for _, planet in sky.planets do
		local center = planet.direction.Unit * PLANET_DISTANCE
		local stripes = planet.bands or 0
		local sphere = Scenery.sphere(center, planet.size, function(normal)
			local lit = planet.dark:Lerp(planet.light, math.clamp(normal:Dot(SUN) * 0.8 + 0.4, 0, 1))
			return if stripes > 0 and math.floor((normal.Y + 1) * stripes) % 2 == 1 then lit:Lerp(planet.dark, 0.25) else lit
		end)
		table.move(sphere, 1, #sphere, #stars + 1, stars)
	end
	Scenery.mesh(model, stars, { name = "Stars", material = Enum.Material.Neon })

	for i = 1, sky.cloudCount do
		local color = sky.clouds[i % #sky.clouds + 1]
		local size = SKY_RADIUS * rng:NextNumber(0.15, 0.4)
		Scenery.billboard(model, inBand(BAND_SPREAD * 0.6) * SKY_RADIUS * 0.92, size, SMOKE, color, sky.cloudTransparency + rng:NextNumber(-0.1, 0.1))
	end
	for _ = 1, sky.sparkles do
		local color = sky.stars[rng:NextInteger(1, #sky.stars)]
		Scenery.billboard(model, rng:NextUnitVector() * SKY_RADIUS * 0.9, SKY_RADIUS * rng:NextNumber(0.02, 0.045), SPARKLE, color, 0)
	end

	model.WorldPivot = CFrame.new()
	model.Parent = decor
	RunService.RenderStepped:Connect(function()
		model:PivotTo(CFrame.new(workspace.CurrentCamera.CFrame.Position))
	end)
end

function Scenery.sphere(center: Vector3, radius: number, paint: (normal: Vector3) -> Color3): { Quad }
	local function normal(ring: number, segment: number): Vector3
		local lat = math.pi * (ring / SPHERE_RINGS - 0.5)
		local lon = 2 * math.pi * segment / SPHERE_SEGMENTS
		return Vector3.new(math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon))
	end
	local quads = {}
	for ring = 0, SPHERE_RINGS - 1 do
		for segment = 0, SPHERE_SEGMENTS - 1 do
			local corners, colors = {}, {}
			for k, at in { { ring, segment }, { ring, segment + 1 }, { ring + 1, segment + 1 }, { ring + 1, segment } } do
				local n = normal(at[1], at[2])
				corners[k], colors[k] = center + n * radius, paint(n)
			end
			table.insert(quads, { corners = corners, colors = colors })
		end
	end
	return quads
end

function Scenery.beacons(track: Track.Track, parent: Instance, spacing: number, colors: { Color3 })
	local offset = track.width / 2 + 5
	for k = 0, math.floor(track.length / spacing) - 1 do
		local frame = Track.frame(track, k * spacing)
		local color = colors[k % #colors + 1]
		for _, side in { -1, 1 } do
			Scenery.part(parent, Enum.PartType.Ball, Vector3.one * 1.8, frame * CFrame.new(side * offset, 2.5, 0), color, Enum.Material.Neon)
		end
	end
end

function Scenery.join(...: { Quad }): { Quad }
	local all = {}
	for _, quads in { ... } do
		table.move(quads, 1, #quads, #all + 1, all)
	end
	return all
end

function Scenery.sweep(track: Track.Track, sweep: Sweep): { Quad }
	local step = sweep.step or track.spacing
	local gap = sweep.gap or 0
	local quads = {}
	for k = 0, math.floor(track.length / step) - 1 do
		local s0 = k * step
		local s1 = if gap == 0 and k == math.floor(track.length / step) - 1 then track.length else s0 + step - gap
		local f0, f1 = Track.frame(track, s0), Track.frame(track, s1)
		for _, strip in sweep.strips do
			for i = 1, #strip - 1 do
				local a, b = strip[i], strip[i + 1]
				table.insert(quads, {
					corners = {
						f0 * Vector3.new(a.X, a.Y, 0),
						f0 * Vector3.new(b.X, b.Y, 0),
						f1 * Vector3.new(b.X, b.Y, 0),
						f1 * Vector3.new(a.X, a.Y, 0),
					},
					colors = { sweep.paint(s0, a.X), sweep.paint(s0, b.X), sweep.paint(s1, b.X), sweep.paint(s1, a.X) },
				})
			end
		end
	end
	return quads
end

function Scenery.night(night: Night)
	Lighting.ClockTime = 0
	Lighting.Brightness = night.brightness
	Lighting.GlobalShadows = false
	Lighting.Ambient = night.ambient
	Lighting.OutdoorAmbient = night.ambient
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 1

	local sky = Instance.new("Sky")
	sky.StarCount = 5000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = night.bloom
	bloom.Size = 40
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.TintColor = night.tint
	grade.Saturation = night.saturation
	grade.Contrast = 0.1
	grade.Parent = Lighting
end

return Scenery
