export type FrameClock = {
	step: number,
	unsimulated: number,
}

local FrameClock = {}

function FrameClock.new(step: number): FrameClock
	return { step = step, unsimulated = 0 }
end

function FrameClock.advance(clock: FrameClock, dt: number): number
	clock.unsimulated += dt
	local steps = 0
	while clock.unsimulated >= clock.step do
		clock.unsimulated -= clock.step
		steps += 1
	end
	return steps
end

function FrameClock.alpha(clock: FrameClock): number
	return clock.unsimulated / clock.step
end

return FrameClock
