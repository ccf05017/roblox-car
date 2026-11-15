local Track = require(script.Parent.Track)
local CarPhysics = require(script.Parent.CarPhysics)

local LOOKAHEAD_BASE = 15
local LOOKAHEAD_PER_SPEED = 0.5
local STEER_GAIN = 2.5
local MAX_THROTTLE = 0.88
local CORNER_EASE = 1.2
local MIN_CORNER_THROTTLE = 0.4

local AiDriver = {}

-- Plans on the road unrolled flat, so a corkscrew roll or a hill never reads as a turn.
function AiDriver.input(state: CarPhysics.CarState, track: Track.Track): CarPhysics.Input
	local lookahead = LOOKAHEAD_BASE + state.speed * LOOKAHEAD_PER_SPEED
	local step = track.spacing
	local bend, forward, right = 0, 0, 0
	for travelled = 0, lookahead - step, step do
		bend += Track.curvature(track, state.distance + travelled + step / 2) * step
		forward += math.cos(bend) * step
		right += math.sin(bend) * step
	end
	local headingError = (math.atan2(right - state.lateral, forward) - state.yaw + math.pi) % (2 * math.pi) - math.pi
	return {
		throttle = MAX_THROTTLE * math.clamp(1 - math.abs(headingError) * CORNER_EASE, MIN_CORNER_THROTTLE, 1),
		steer = math.clamp(headingError * STEER_GAIN, -1, 1),
	}
end

return AiDriver
