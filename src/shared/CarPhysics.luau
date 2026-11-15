local Track = require(script.Parent.Track)

export type CarState = {
	position: Vector3,
	heading: number,
	speed: number,
	distance: number,
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
local TURN_RATE = 2.2
local FULL_TURN_SPEED = 30
local CAR_HALF_WIDTH = 3
local SCRAPE_DRAG = 60

local CarPhysics = {}

function CarPhysics.forward(heading: number): Vector3
	return Vector3.new(math.sin(heading), 0, math.cos(heading))
end

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
	speed = moveToward(speed, target, rate * dt)

	local grip = math.clamp(speed / FULL_TURN_SPEED, -1, 1)
	local heading = state.heading - input.steer * TURN_RATE * grip * dt
	local position = state.position + CarPhysics.forward(heading) * speed * dt

	local s, lateral = Track.project(track, position)
	local limit = track.width / 2 - CAR_HALF_WIDTH
	if math.abs(lateral) > limit then
		local center, tangent = Track.sample(track, s)
		position = center + tangent:Cross(Vector3.yAxis) * math.sign(lateral) * limit
		speed = moveToward(speed, 0, SCRAPE_DRAG * dt)
	end

	local length = track.length
	local ds = s - state.distance % length
	if ds < -length / 2 then
		ds += length
	elseif ds > length / 2 then
		ds -= length
	end

	return { position = position, heading = heading, speed = speed, distance = state.distance + ds }
end

return CarPhysics
