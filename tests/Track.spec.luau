local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Track = require(Shared.Track)
local CarPhysics = require(Shared.CarPhysics)
local AiDriver = require(Shared.AiDriver)
local Course = require(Shared.Course)

local STEP = 1 / 60
local SPACING_TOLERANCE = 0.03
local MAX_TURN_PER_FRAME = math.rad(8)
local MIN_ROAD_HEIGHT = 20
local CLEARANCE = 30
local CLEARANCE_ALONG = 100
local LAP_MIN, LAP_MAX = 40, 80
local NEAR_WALL = 4
local MAX_PINNED_SECONDS = 1
local CORKSCREW_LANE = 8

local function aiLap(track: Track.Track): (number, number, number)
	local state: CarPhysics.CarState = { distance = 0, lateral = 0, yaw = 0, speed = 0 }
	local elapsed, pinned, longestPinned, widestUpsideDown = 0, 0, 0, 0
	while state.distance < track.length and elapsed < LAP_MAX * 2 do
		state = CarPhysics.step(state, AiDriver.input(state, track), STEP, track)
		elapsed += STEP
		pinned = if math.abs(state.lateral) > track.width / 2 - NEAR_WALL then pinned + STEP else 0
		longestPinned = math.max(longestPinned, pinned)
		if Track.frame(track, state.distance).UpVector.Y < 0 then
			widestUpsideDown = math.max(widestUpsideDown, math.abs(state.lateral))
		end
	end
	return elapsed, longestPinned, widestUpsideDown
end

return function(): string
	local lines = {}
	local checks, failed = 0, 0
	local function check(name: string, ok: boolean, detail: any?)
		checks += 1
		if not ok then
			failed += 1
		end
		table.insert(lines, (if ok then "PASS " else "FAIL ") .. name .. (if ok or detail == nil then "" else " :: " .. tostring(detail)))
	end

	local track = Track.build(Course)
	local frames = track.frames
	local n = #frames

	local worstSpacing, worstTurn, lowest, downRuns = 0, 0, math.huge, 0
	local wasDown = frames[n].UpVector.Y < -0.9
	for i, frame in frames do
		local nextFrame = frames[i % n + 1]
		local gap = (nextFrame.Position - frame.Position).Magnitude
		worstSpacing = math.max(worstSpacing, math.abs(gap - track.spacing) / track.spacing)
		local _, turn = frame:ToObjectSpace(nextFrame):ToAxisAngle()
		worstTurn = math.max(worstTurn, turn)
		lowest = math.min(lowest, frame.Position.Y)
		local down = frame.UpVector.Y < -0.9
		if down and not wasDown then
			downRuns += 1
		end
		wasDown = down
	end
	check("frames are evenly spaced", worstSpacing < SPACING_TOLERANCE, string.format("worst %.1f%% off %.2f studs", worstSpacing * 100, track.spacing))
	check("road never turns sharply between frames", worstTurn < MAX_TURN_PER_FRAME, string.format("worst %.1f degrees", math.deg(worstTurn)))
	check("corkscrew turns the road upside down exactly once", downRuns == 1, downRuns .. " upside-down stretches")
	check("road stays above y = " .. MIN_ROAD_HEIGHT, lowest > MIN_ROAD_HEIGHT, string.format("lowest %.1f", lowest))

	local closest = math.huge
	for i = 1, n do
		for j = i + 1, n do
			local along = math.min(j - i, n - (j - i)) * track.spacing
			if along > CLEARANCE_ALONG then
				closest = math.min(closest, (frames[j].Position - frames[i].Position).Magnitude)
			end
		end
	end
	check("road never passes through itself", closest > CLEARANCE, string.format("closest %.1f studs", closest))

	local seconds, longestPinned, widestUpsideDown = aiLap(track)
	check(
		"computer car laps in " .. LAP_MIN .. "-" .. LAP_MAX .. " s",
		seconds >= LAP_MIN and seconds <= LAP_MAX,
		string.format("%.1f s for %.0f studs", seconds, track.length)
	)
	check(
		"computer car never rides the wall for over " .. MAX_PINNED_SECONDS .. " s",
		longestPinned <= MAX_PINNED_SECONDS,
		string.format("%.2f s", longestPinned)
	)
	check(
		"computer car holds the middle while upside down",
		widestUpsideDown < CORKSCREW_LANE,
		string.format("%.1f studs off centre", widestUpsideDown)
	)
	table.insert(lines, string.format("INFO %.0f studs, AI lap %.1f s", track.length, seconds))

	table.insert(lines, 1, string.format("%d checks, %d failed", checks, failed))
	return table.concat(lines, "\n")
end
