local Track = require(script.Parent.Track)

local function node(x: number, y: number, z: number, bank: number?): Track.Node
	return { at = Vector3.new(x, y, z), bank = bank }
end

local function spiral(center: Vector3, radius: number, fromY: number, rise: number, steps: number, bank: number): { Track.Node }
	local nodes = {}
	for k = 0, steps do
		local angle = k * math.pi / 4
		local at = center + Vector3.new(radius * math.cos(angle), fromY + rise * k, radius * math.sin(angle))
		table.insert(nodes, { at = at, bank = bank })
	end
	return nodes
end

local function concat(...: { Track.Node }): { Track.Node }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

local Course: Track.Spec = {
	width = 40,
	nodes = concat(
		{ node(240, 60, -450), node(240, 60, -220) },
		spiral(Vector3.zero, 240, 70, 22, 10, 12),
		{
			node(-250, 290, 240),
			node(-450, 290, 240),
			node(-650, 290, 240),
			node(-850, 280, 300, -20),
			node(-950, 250, 550, -30),
			node(-800, 200, 760, -20),
			node(-450, 120, 800),
			node(-100, 70, 800),
			node(300, 60, 780, -15),
			node(600, 80, 600, -30),
			node(650, 70, 100),
			node(600, 60, -500, -30),
			node(420, 60, -700, -30),
		}
	),
	twists = { { node = 15, length = 420, turns = 1, radius = 28 } },
}

return Course
