local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SAMPLE_SECONDS = 2
local CAMERA_BACK = 28
-- The eye sits CAMERA_BACK along the curved road, so on a bend the straight-line gap is a little shorter.
local CURVE_SLACK = 0.9

return function(): string
	local lines = {}
	local failed = 0
	local function check(name: string, ok: boolean, detail: any?)
		if not ok then
			failed += 1
		end
		table.insert(lines, (if ok then "PASS " else "FAIL ") .. name .. (if ok or detail == nil then "" else " :: " .. tostring(detail)))
	end

	local deadline = os.clock() + 30
	repeat
		task.wait(0.1)
	until (workspace:FindFirstChild("player") and Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) or os.clock() > deadline
	check("player car spawned", workspace:FindFirstChild("player") ~= nil)
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
		local pivot = car:GetPivot()
		minGap = math.min(minGap, (camera.CFrame.Position - pivot.Position):Dot(-pivot.LookVector))
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
		"camera stays about CAMERA_BACK behind the player car",
		minGap >= CAMERA_BACK * CURVE_SLACK,
		string.format("closest gap behind the car %.1f studs", minGap)
	)

	table.insert(lines, 1, string.format("%d checks, %d failed", #lines, failed))
	return table.concat(lines, "\n")
end
