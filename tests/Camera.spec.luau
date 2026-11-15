local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SAMPLE_SECONDS = 2
local CAMERA_BACK = 28
local STEADY_SECONDS = 4
local JERK_RATIO = 0.5

return function(): string
	local lines = {}
	local failed = 0
	local function check(name: string, ok: boolean, detail: any?)
		if not ok then
			failed += 1
		end
		table.insert(lines, (if ok then "PASS " else "FAIL ") .. name .. (if ok or detail == nil then "" else " :: " .. tostring(detail)))
	end

	local deadline = os.clock() + 10
	repeat
		task.wait(0.1)
	until (Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) or os.clock() > deadline
	check("player avatar spawned", Players.LocalPlayer.Character ~= nil)
	task.wait(1)

	local car = workspace:WaitForChild("player") :: Model
	local camera = workspace.CurrentCamera
	local frames, writes, maxWrites, minGap = 0, 0, 0, math.huge
	local thisFrame = 0
	local changed = camera:GetPropertyChangedSignal("CFrame"):Connect(function()
		thisFrame += 1
	end)
	local heartbeat = RunService.Heartbeat:Connect(function()
		frames += 1
		writes += thisFrame
		maxWrites = math.max(maxWrites, thisFrame)
		thisFrame = 0
		local offset = car:GetPivot().Position - camera.CFrame.Position
		minGap = math.min(minGap, Vector3.new(offset.X, 0, offset.Z).Magnitude)
	end)
	task.wait(SAMPLE_SECONDS)
	changed:Disconnect()
	heartbeat:Disconnect()

	check(
		"only the race moves the camera, at most once a frame",
		maxWrites <= 1,
		string.format("%d camera writes in %d frames, up to %d in one frame", writes, frames, maxWrites)
	)
	check(
		"camera stays at least CAMERA_BACK behind the player car",
		minGap >= CAMERA_BACK - 0.5,
		string.format("closest horizontal gap %.1f studs", minGap)
	)

	local ai = workspace:WaitForChild("ai") :: Model
	local start = ai:GetPivot().Position
	deadline = os.clock() + 10
	repeat
		task.wait(0.1)
	until (ai:GetPivot().Position - start).Magnitude > 50 or os.clock() > deadline
	local steps = {}
	local last = ai:GetPivot().Position
	local sampler = RunService.Heartbeat:Connect(function(dt)
		local p = ai:GetPivot().Position
		table.insert(steps, Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude / dt)
		last = p
	end)
	task.wait(STEADY_SECONDS)
	sampler:Disconnect()
	local jerks = 0
	for i = 3, #steps - 1 do
		local around = (steps[i - 1] + steps[i + 1]) / 2
		if around > 20 and math.abs(steps[i] - around) > JERK_RATIO * around then
			jerks += 1
		end
	end
	check(
		"ai car moves at a steady on-screen speed every rendered frame",
		jerks == 0,
		string.format("%d of %d frames ran slower or faster than their neighbours by over %d%%", jerks, #steps, JERK_RATIO * 100)
	)

	table.insert(lines, 1, string.format("%d checks, %d failed", #lines, failed))
	return table.concat(lines, "\n")
end
