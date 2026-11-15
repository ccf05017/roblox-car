local Track = require(script.Parent.Track)

export type Course = {
	id: string,
	title: string,
	blurb: string,
	spec: Track.Spec,
}

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

local Courses: { Course } = {
	{
		id = "MilkyWay",
		title = "은하수",
		blurb = "별이 강처럼 흐르는 언덕길과 뒤집히는 코르크스크루",
		spec = {
			width = 40,
			nodes = {
				node(0, 80, 0),
				node(300, 80, 0),
				node(600, 130, 0),
				node(850, 200, 0),
				node(1100, 140, 50, 10),
				node(1350, 70, 200, 25),
				node(1450, 90, 450, 25),
				node(1350, 140, 700, 25),
				node(1100, 180, 800),
				node(850, 180, 800),
				node(600, 180, 800),
				node(350, 180, 800),
				node(100, 160, 820, 10),
				node(-150, 100, 750, 20),
				node(-300, 60, 550, 15),
				node(-200, 130, 330),
				node(-250, 70, 130, -10),
				node(-120, 80, 10, 10),
			},
			twists = { { node = 11, length = 420, turns = 1, radius = 28 } },
		},
	},
	{
		id = "AuroraRibbon",
		title = "오로라 리본",
		blurb = "하늘 꼭대기에서 떨어지는 급강하와 기울어진 급커브",
		spec = {
			width = 40,
			nodes = {
				node(0, 300, 0),
				node(300, 300, 0),
				node(550, 260, 0),
				node(800, 160, 0),
				node(1000, 90, 0),
				node(1250, 100, 100, 40),
				node(1300, 110, 300, 40),
				node(1150, 120, 450, 30),
				node(900, 150, 450),
				node(650, 190, 470, -10),
				node(400, 200, 600, -30),
				node(300, 200, 850, 0),
				node(100, 220, 950, 30),
				node(-200, 230, 950),
				node(-500, 230, 950),
				node(-800, 230, 950),
				node(-1000, 240, 850, 35),
				node(-1050, 270, 550, 35),
				node(-900, 300, 250, 30),
				node(-600, 300, 50, 10),
				node(-300, 300, 0),
			},
			twists = { { node = 15, length = 420, turns = 1, radius = 28 } },
		},
	},
	{
		id = "StarlightBridge",
		title = "별빛 다리",
		blurb = "고리 행성을 감아 오르는 나선 다리와 별빛 낙하",
		spec = {
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
		},
	},
}

return Courses
