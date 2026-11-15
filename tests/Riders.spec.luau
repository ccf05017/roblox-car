local Players = game:GetService("Players")

local SIT_ANIMATION = "2506281703"
local SEAT_REACH = 6

return function(): string
	local lines = {}
	local failed = 0
	local function check(name: string, ok: boolean, detail: any?)
		if not ok then
			failed += 1
		end
		table.insert(lines, (if ok then "PASS " else "FAIL ") .. name .. (if ok or detail == nil then "" else " :: " .. tostring(detail)))
	end
	local function waitFor(predicate: () -> any, timeout: number): any
		local deadline = os.clock() + timeout
		repeat
			local value = predicate()
			if value then
				return value
			end
			task.wait(0.1)
		until os.clock() > deadline
		return nil
	end

	local character = waitFor(function()
		local c = Players.LocalPlayer.Character
		return c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChild("Head") and c
	end, 30)
	local aiRider = waitFor(function()
		return workspace:FindFirstChild("AiRider")
	end, 10)
	check("player avatar spawned", character ~= nil)
	check("computer rider spawned", aiRider ~= nil)
	if not (character and aiRider) then
		return table.concat(lines, "\n")
	end
	waitFor(function()
		return character.HumanoidRootPart:FindFirstChildOfClass("Weld") and aiRider.HumanoidRootPart:FindFirstChildOfClass("Weld")
	end, 5)

	local riders = {
		{ name = "player", model = character, car = workspace:WaitForChild("player") :: Model },
		{ name = "ai", model = aiRider, car = workspace:WaitForChild("ai") :: Model },
	}
	local function inCar(rider, part: BasePart): Vector3
		return rider.car:GetPivot():PointToObjectSpace(part.Position)
	end

	for _, rider in riders do
		local root = rider.model.HumanoidRootPart
		local humanoid = rider.model.Humanoid
		local weld = root:FindFirstChildOfClass("Weld")
		check(rider.name .. " is attached to its car", weld ~= nil and weld.Part0 == rider.car.PrimaryPart, weld and weld.Part0)

		local tracks = humanoid.Animator:GetPlayingAnimationTracks()
		local sitting = #tracks == 1 and string.find(tracks[1].Animation.AnimationId, SIT_ANIMATION, 1, true) ~= nil
		check(rider.name .. " plays only the sit pose", sitting, #tracks .. " tracks")

		local boxCFrame, boxSize = rider.car:GetBoundingBox()
		local roof = rider.car:GetPivot():PointToObjectSpace(boxCFrame * Vector3.new(0, boxSize.Y / 2, 0)).Y
		local hips = inCar(rider, root)
		local head = inCar(rider, rider.model.Head)
		check(rider.name .. " sits over the car centre", math.abs(hips.X) < 3 and math.abs(hips.Z) < 3, hips)
		check(rider.name .. " hips are below the roof", hips.Y < roof, string.format("hips %.2f roof %.2f", hips.Y, roof))
		check(rider.name .. " head shows above the roof", head.Y > roof, string.format("head %.2f roof %.2f", head.Y, roof))
	end

	local ai = riders[2]
	local moved = waitFor(function()
		local start = ai.car:GetPivot().Position
		local before = inCar(ai, ai.model.HumanoidRootPart)
		task.wait(1)
		local distance = (ai.car:GetPivot().Position - start).Magnitude
		return distance > 20 and { drift = (inCar(ai, ai.model.HumanoidRootPart) - before).Magnitude }
	end, 12)
	check("ai car drives after the countdown", moved ~= nil)
	check("rider stays in the seat while the car drives (drift < 0.3 stud)", moved ~= nil and moved.drift < 0.3, moved and moved.drift)
	local reach = (character.HumanoidRootPart.Position - riders[1].car:GetPivot().Position).Magnitude
	check("player avatar rides with its car", reach < SEAT_REACH, string.format("%.1f studs from the car", reach))

	table.insert(lines, 1, string.format("%d checks, %d failed", #lines, failed))
	return table.concat(lines, "\n")
end
