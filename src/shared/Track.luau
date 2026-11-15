export type Node = {
	at: Vector3,
	-- Degrees of roll about the direction of travel. Positive lowers the right edge, which banks a right-hand turn.
	bank: number?,
}

export type Twist = {
	node: number,
	length: number,
	turns: number,
	radius: number,
}

export type Spec = {
	nodes: { Node },
	width: number,
	twists: { Twist },
}

export type Track = {
	frames: { CFrame },
	curvature: { number },
	spacing: number,
	length: number,
	width: number,
}

local SPACING = 3
local DENSE_STEP = 0.5

local Track = {}

local function knot(a: Vector3, b: Vector3): number
	return math.max((b - a).Magnitude ^ 0.5, 1e-6)
end

local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: number): Vector3
	local t1 = knot(p0, p1)
	local t2 = t1 + knot(p1, p2)
	local t3 = t2 + knot(p2, p3)
	local t = t1 + (t2 - t1) * u
	local a1 = p0:Lerp(p1, t / t1)
	local a2 = p1:Lerp(p2, (t - t1) / (t2 - t1))
	local a3 = p2:Lerp(p3, (t - t2) / (t3 - t2))
	local b1 = a1:Lerp(a2, t / t2)
	local b2 = a2:Lerp(a3, (t - t1) / (t3 - t1))
	return b1:Lerp(b2, u)
end

local function smoothstep(u: number): number
	return u * u * (3 - 2 * u)
end

local function wrap(i: number, n: number): number
	return (i - 1) % n + 1
end

type Dense = { points: { Vector3 }, banks: { number }, nodeIndex: { number } }

local function sampleNodes(nodes: { Node }): Dense
	local n = #nodes
	local points, banks, nodeIndex = {}, {}, {}
	for i = 1, n do
		local p0, p1 = nodes[wrap(i - 1, n)].at, nodes[i].at
		local p2, p3 = nodes[wrap(i + 1, n)].at, nodes[wrap(i + 2, n)].at
		local bankFrom, bankTo = nodes[i].bank or 0, nodes[wrap(i + 1, n)].bank or 0
		local steps = math.max(math.ceil((p2 - p1).Magnitude / DENSE_STEP), 2)
		nodeIndex[i] = #points + 1
		for k = 0, steps - 1 do
			local u = k / steps
			table.insert(points, catmullRom(p0, p1, p2, p3, u))
			table.insert(banks, bankFrom + (bankTo - bankFrom) * smoothstep(u))
		end
	end
	return { points = points, banks = banks, nodeIndex = nodeIndex }
end

local function arcLengths(points: { Vector3 }): ({ number }, number)
	local along = { 0 }
	for i = 2, #points do
		along[i] = along[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return along, along[#points] + (points[1] - points[#points]).Magnitude
end

local function tangentAt(points: { Vector3 }, i: number): Vector3
	local n = #points
	return (points[wrap(i + 1, n)] - points[wrap(i - 1, n)]).Unit
end

local function surface(spec: Spec): ({ Vector3 }, { Vector3 })
	local dense = sampleNodes(spec.nodes)
	local points = dense.points
	local along, baseLength = arcLengths(points)
	local positions, ups = {}, {}
	for i, p in points do
		local look = tangentAt(points, i)
		local up = (Vector3.yAxis - look * look.Y).Unit
		local right = look:Cross(up)
		local bank = math.rad(dense.banks[i])
		up, right = up * math.cos(bank) + right * math.sin(bank), right * math.cos(bank) - up * math.sin(bank)

		for _, twist in spec.twists do
			local from = along[dense.nodeIndex[twist.node]] - twist.length / 2
			local u = ((along[i] - from) % baseLength) / twist.length
			if u < 1 then
				local angle = 2 * math.pi * twist.turns * (u - math.sin(2 * math.pi * u) / (2 * math.pi))
				local rolled = up * math.cos(angle) + right * math.sin(angle)
				right = right * math.cos(angle) - up * math.sin(angle)
				p += (up - rolled) * twist.radius
				up = rolled
			end
		end
		positions[i], ups[i] = p, up
	end
	return positions, ups
end

function Track.build(spec: Spec): Track
	local points, ups = surface(spec)
	local along, length = arcLengths(points)
	local n = #points
	local count = math.max(math.round(length / SPACING), 3)
	local spacing = length / count

	local positions, normals = {}, {}
	local j = 1
	for k = 1, count do
		local s = (k - 1) * spacing
		while j < n and along[j + 1] <= s do
			j += 1
		end
		local segmentEnd = if j == n then length else along[j + 1]
		local w = (s - along[j]) / (segmentEnd - along[j])
		positions[k] = points[j]:Lerp(points[wrap(j + 1, n)], w)
		normals[k] = ups[j]:Lerp(ups[wrap(j + 1, n)], w)
	end

	local frames, looks, rights = {}, {}, {}
	for k = 1, count do
		local look = tangentAt(positions, k)
		local up = (normals[k] - look * look:Dot(normals[k])).Unit
		local right = look:Cross(up)
		frames[k] = CFrame.fromMatrix(positions[k], right, up, -look)
		looks[k], rights[k] = look, right
	end

	local curvature = {}
	for k = 1, count do
		curvature[k] = (looks[wrap(k + 1, count)] - looks[wrap(k - 1, count)]):Dot(rights[k]) / (2 * spacing)
	end

	return { frames = frames, curvature = curvature, spacing = spacing, length = length, width = spec.width }
end

local function locate(track: Track, s: number): (number, number, number)
	local count = #track.frames
	local x = (s % track.length) / track.spacing
	local i = math.min(math.floor(x), count - 1)
	return i + 1, (i + 1) % count + 1, x - i
end

function Track.frame(track: Track, s: number): CFrame
	local a, b, w = locate(track, s)
	return track.frames[a]:Lerp(track.frames[b], w)
end

-- Positive curvature turns right, in radians per stud of centerline.
function Track.curvature(track: Track, s: number): number
	local a, b, w = locate(track, s)
	return track.curvature[a] + (track.curvature[b] - track.curvature[a]) * w
end

function Track.place(track: Track, s: number, lateral: number, yaw: number): CFrame
	return Track.frame(track, s) * CFrame.new(lateral, 0, 0) * CFrame.Angles(0, -yaw, 0)
end

return Track
