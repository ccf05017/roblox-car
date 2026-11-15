local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Track = require(Shared.Track)
local CarPhysics = require(Shared.CarPhysics)
local AiDriver = require(Shared.AiDriver)
local FrameClock = require(Shared.FrameClock)
local Courses = require(Shared.Courses)

local STEP = 1 / 60
local WARMUP_FRAMES = 240
local SPEED_TOLERANCE = 0.1
local LAP_FRAMES = 80 * 60

type Case = { name: string, dts: { number } }

local function repeated(dt: number, frames: number): { number }
	return table.create(frames, dt)
end

local function jittered(seed: number, frames: number, spread: number): { number }
	local rng = Random.new(seed)
	local dts = {}
	for i = 1, frames do
		dts[i] = STEP + rng:NextNumber(-spread, spread)
	end
	return dts
end

local function withHitch(): { number }
	local dts = repeated(STEP, 300)
	dts[150] = 0.25
	return dts
end

local CASES: { Case } = {
	{ name = "60 Hz", dts = repeated(STEP, 600) },
	{ name = "60 Hz with 1 ms jitter", dts = jittered(42, 600, 0.001) },
	{ name = "90 Hz", dts = repeated(1 / 90, 600) },
	{ name = "120 Hz", dts = repeated(1 / 120, 600) },
	{ name = "144 Hz", dts = repeated(1 / 144, 600) },
	{ name = "30 Hz", dts = repeated(1 / 30, 300) },
	{ name = "one 250 ms hitch", dts = withHitch() },
	{ name = "60 Hz for a whole lap", dts = repeated(STEP, LAP_FRAMES) },
}

local function race(track: Track.Track, dts: { number }): (number, number, number, number)
	local state: CarPhysics.CarState = { distance = 0, lateral = 0, yaw = 0, speed = 0 }
	local previous = state
	local clock = FrameClock.new(STEP)
	local steps = 0
	local function frame(dt: number): Vector3
		for _ = 1, FrameClock.advance(clock, dt) do
			previous = state
			state = CarPhysics.step(state, AiDriver.input(state, track), STEP, track)
			steps += 1
		end
		return CarPhysics.pose(CarPhysics.blend(previous, state, FrameClock.alpha(clock)), track).Position
	end

	for _ = 1, WARMUP_FRAMES do
		frame(STEP)
	end
	local last = frame(STEP)
	local stepsBefore, leftoverBefore = steps, clock.unsimulated
	local off, worst, elapsed = 0, 0, 0
	for _, dt in dts do
		local position = frame(dt)
		local shown = (position - last).Magnitude / dt
		local miss = math.abs(shown - state.speed) / state.speed
		worst = math.max(worst, miss)
		if miss > SPEED_TOLERANCE then
			off += 1
		end
		last = position
		elapsed += dt
	end
	local simulated = (steps - stepsBefore) * STEP + clock.unsimulated - leftoverBefore
	return off, worst, simulated, elapsed
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

	for _, course in Courses do
		local track = Track.build(course.spec)
		for _, case in CASES do
			local off, worst, simulated, elapsed = race(track, case.dts)
			check(
				course.id .. " car moves on screen at its real speed every frame at " .. case.name,
				off == 0,
				string.format("%d of %d frames off by over %d%%, worst %.0f%%", off, #case.dts, SPEED_TOLERANCE * 100, worst * 100)
			)
			check(
				course.id .. " simulation keeps pace with elapsed time at " .. case.name,
				math.abs(simulated - elapsed) < 1e-6,
				string.format("%.6f s simulated for %.6f s elapsed", simulated, elapsed)
			)
		end
	end

	local clock = FrameClock.new(STEP)
	local alphas = {}
	for _, dt in jittered(7, 600, 0.004) do
		FrameClock.advance(clock, dt)
		table.insert(alphas, FrameClock.alpha(clock))
	end
	local lowest, highest = math.min(table.unpack(alphas)), math.max(table.unpack(alphas))
	check("blend factor stays within one step", lowest >= 0 and highest < 1, string.format("%.4f..%.4f", lowest, highest))

	table.insert(lines, 1, string.format("%d checks, %d failed", #lines, failed))
	return table.concat(lines, "\n")
end
