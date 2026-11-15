export type Spec = {
	corners: { Vector2 },
	scale: number,
	cornerRadius: number,
	width: number,
	y: number,
}

export type Track = {
	points: { Vector3 },
	cumulative: { number },
	length: number,
	width: number,
}

local ARC_STEPS_PER_RADIAN = 10

local Track = {}

Track.SPEC = {
	corners = {
		Vector2.new(0, 0),
		Vector2.new(8, 0),
		Vector2.new(8, 4),
		Vector2.new(4, 4),
		Vector2.new(4, 8),
		Vector2.new(0, 8),
	},
	scale = 200,
	cornerRadius = 60,
	width = 40,
	y = 0,
} :: Spec

local function fillet(prev: Vector2, corner: Vector2, nextCorner: Vector2, radius: number): { Vector2 }
	local inDir = (corner - prev).Unit
	local outDir = (nextCorner - corner).Unit
	local side = math.sign(inDir.X * outDir.Y - inDir.Y * outDir.X)
	local turn = math.acos(math.clamp(inDir:Dot(outDir), -1, 1))
	local entry = corner - inDir * radius * math.tan(turn / 2)
	local center = entry + Vector2.new(-inDir.Y, inDir.X) * side * radius
	local arm = entry - center
	local steps = math.ceil(turn * ARC_STEPS_PER_RADIAN)
	local arc = {}
	for i = 0, steps do
		local angle = side * turn * i / steps
		local c, s = math.cos(angle), math.sin(angle)
		table.insert(arc, center + Vector2.new(arm.X * c - arm.Y * s, arm.X * s + arm.Y * c))
	end
	return arc
end

function Track.build(spec: Spec): Track
	local corners = spec.corners
	local n = #corners
	local flat = { (corners[1] + corners[2]) / 2 * spec.scale }
	for k = 2, n + 1 do
		local i = (k - 1) % n + 1
		local prev = corners[(i - 2) % n + 1]
		local nextCorner = corners[i % n + 1]
		for _, p in fillet(prev * spec.scale, corners[i] * spec.scale, nextCorner * spec.scale, spec.cornerRadius) do
			table.insert(flat, p)
		end
	end

	local points = {}
	local cumulative = {}
	local total = 0
	for i, p in flat do
		points[i] = Vector3.new(p.X, spec.y, p.Y)
		if i > 1 then
			total += (points[i] - points[i - 1]).Magnitude
		end
		cumulative[i] = total
	end
	total += (points[1] - points[#points]).Magnitude

	return { points = points, cumulative = cumulative, length = total, width = spec.width }
end

function Track.project(track: Track, position: Vector3): (number, number)
	local points = track.points
	local n = #points
	local bestDistance, bestS, bestLateral = math.huge, 0, 0
	for i = 1, n do
		local a = points[i]
		local b = points[i % n + 1]
		local segment = b - a
		local segmentLength = segment.Magnitude
		local dir = segment / segmentLength
		local offset = position - a
		local t = math.clamp(offset:Dot(dir), 0, segmentLength)
		local distance = (offset - dir * t).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestS = track.cumulative[i] + t
			bestLateral = offset:Dot(dir:Cross(Vector3.yAxis))
		end
	end
	return bestS, bestLateral
end

function Track.sample(track: Track, s: number): (Vector3, Vector3)
	s %= track.length
	local points, cumulative = track.points, track.cumulative
	local n = #points
	local i = n
	for j = 2, n do
		if cumulative[j] > s then
			i = j - 1
			break
		end
	end
	local a, b = points[i], points[i % n + 1]
	local segmentEnd = if i == n then track.length else cumulative[i + 1]
	return a:Lerp(b, (s - cumulative[i]) / (segmentEnd - cumulative[i])), (b - a).Unit
end

return Track
