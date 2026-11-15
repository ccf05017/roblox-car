local Track = require(script.Parent.Track)

export type CarState = {
	distance: number,
	lateral: number,
	yaw: number,
	speed: number,
}

export type Input = {
	throttle: number,
	steer: number,
}

local MAX_SPEED = 120
local MAX_REVERSE = 25
local ACCEL = 45
local BRAKE = 120
local COAST = 20
local SLOPE_ACCEL = 25
local TURN_RATE = 2.2
local FULL_TURN_SPEED = 30
local CAR_HALF_WIDTH = 3
local SCRAPE_DRAG = 60
local MIN_STRETCH = 0.2

local CarPhysics = {}

local function moveToward(value: number, target: number, maxDelta: number): number
	if value < target then
		return math.min(value + maxDelta, target)
	end
	return math.max(value - maxDelta, target)
end

function CarPhysics.step(state: CarState, input: Input, dt: number, track: Track.Track): CarState
	local speed = state.speed
	local target = if input.throttle >= 0 then input.throttle * MAX_SPEED else input.throttle * MAX_REVERSE
	local rate = COAST
	if input.throttle ~= 0 and speed ~= 0 and math.sign(input.throttle) ~= math.sign(speed) then
		rate = BRAKE
	elseif math.abs(target) > math.abs(speed) then
		rate = ACCEL
	end
	local climb = Track.place(track, state.distance, state.lateral, state.yaw).LookVector.Y
	speed = moveToward(speed, target, rate * dt) - climb * SLOPE_ACCEL * dt

	local grip = math.clamp(speed / FULL_TURN_SPEED, -1, 1)
	local yaw = state.yaw + input.steer * TURN_RATE * grip * dt
	local curvature = Track.curvature(track, state.distance)
	local ds = speed * math.cos(yaw) * dt / math.max(1 - curvature * state.lateral, MIN_STRETCH)
	yaw -= curvature * ds
	local lateral = state.lateral + speed * math.sin(yaw) * dt

	local limit = track.width / 2 - CAR_HALF_WIDTH
	if math.abs(lateral) > limit then
		lateral = math.sign(lateral) * limit
		speed = moveToward(speed, 0, SCRAPE_DRAG * dt)
	end

	return { distance = state.distance + ds, lateral = lateral, yaw = yaw, speed = speed }
end

function CarPhysics.blend(previous: CarState, state: CarState, alpha: number): CarState
	local function lerp(from: number, to: number): number
		return from + (to - from) * alpha
	end
	return {
		distance = lerp(previous.distance, state.distance),
		lateral = lerp(previous.lateral, state.lateral),
		yaw = lerp(previous.yaw, state.yaw),
		speed = lerp(previous.speed, state.speed),
	}
end

function CarPhysics.pose(state: CarState, track: Track.Track): CFrame
	return Track.place(track, state.distance, state.lateral, state.yaw)
end

return CarPhysics
