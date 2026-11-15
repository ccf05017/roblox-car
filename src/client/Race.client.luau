local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Track = require(Shared.Track)
local CarPhysics = require(Shared.CarPhysics)
local AiDriver = require(Shared.AiDriver)
local World = require(script.Parent.World)
local Rider = require(script.Parent.Rider)

local LAPS = 3
local COUNTDOWN_SECONDS = 3
local GO_SHOW_SECONDS = 1
local SIM_STEP = 1 / 60
local START_BEHIND = 15
local GRID_OFFSET = 9
local HOVER = 1.5
local BOB_HEIGHT = 0.4
local BOB_SPEED = 3
local CAMERA_BACK = 28
local CAMERA_UP = 12
local CAMERA_LOOK_AHEAD = 25
local CAMERA_SMOOTHING = 6
local PLACE_NAMES = { "1st", "2nd" }
local AI_TEXTURE = "rbxassetid://86832693528956"
local IDLE: CarPhysics.Input = { throttle = 0, steer = 0 }

type Phase = "Countdown" | "Racing" | "Finished"

type Car = {
	name: string,
	drive: (CarPhysics.CarState, Track.Track) -> CarPhysics.Input,
	state: CarPhysics.CarState,
	model: Model,
	pivotHeight: number,
	bobPhase: number,
	laps: number,
	lapStartedAt: number,
	place: number?,
}

local track = Track.build(Track.SPEC)
World.build(track)

local carTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Car") :: Model

local function held(a: Enum.KeyCode, b: Enum.KeyCode): number
	return if UserInputService:IsKeyDown(a) or UserInputService:IsKeyDown(b) then 1 else 0
end

local function keyboardInput(): CarPhysics.Input
	return {
		throttle = held(Enum.KeyCode.W, Enum.KeyCode.Up) - held(Enum.KeyCode.S, Enum.KeyCode.Down),
		steer = held(Enum.KeyCode.D, Enum.KeyCode.Right) - held(Enum.KeyCode.A, Enum.KeyCode.Left),
	}
end

local function spawnCar(name: string, lateral: number, drive): Car
	local model = carTemplate:Clone()
	model.Name = name
	local boxCFrame, boxSize = model:GetBoundingBox()
	model.Parent = workspace

	local start, tangent = Track.sample(track, -START_BEHIND)
	return {
		name = name,
		drive = drive,
		state = {
			position = start + tangent:Cross(Vector3.yAxis) * lateral,
			heading = math.atan2(tangent.X, tangent.Z),
			speed = 0,
			distance = -START_BEHIND,
		},
		model = model,
		pivotHeight = model:GetPivot().Y - (boxCFrame.Y - boxSize.Y / 2),
		bobPhase = lateral,
		laps = 0,
		lapStartedAt = 0,
		place = nil,
	}
end

local player = spawnCar("player", -GRID_OFFSET, keyboardInput)
local ai = spawnCar("ai", GRID_OFFSET, AiDriver.input)
local aiBody = ai.model.PrimaryPart :: MeshPart
aiBody.TextureID = AI_TEXTURE
local cars = { player, ai }

local function seatAvatar(character: Model)
	Rider.seat(character, player.model)
end
Players.LocalPlayer.CharacterAdded:Connect(seatAvatar)
if Players.LocalPlayer.Character then
	task.spawn(seatAvatar, Players.LocalPlayer.Character)
end

task.spawn(function()
	local aiRider = ReplicatedStorage:WaitForChild("AiRider"):Clone()
	aiRider.Parent = workspace
	Rider.seat(aiRider, ai.model)
end)

local race = { phase = "Countdown" :: Phase, phaseStartedAt = os.clock(), finishers = 0, clock = 0, unsimulated = 0 }

local function setPhase(phase: Phase)
	race.phase = phase
	race.phaseStartedAt = os.clock()
	print("[Race] state " .. phase)
end

local function updateCar(car: Car)
	local input = if car.place then IDLE else car.drive(car.state, track)
	car.state = CarPhysics.step(car.state, input, SIM_STEP, track)
	if car.place then
		return
	end

	local laps = math.floor(car.state.distance / track.length)
	if laps <= car.laps then
		return
	end
	car.laps = laps
	local lapTime = race.clock - car.lapStartedAt
	car.lapStartedAt = race.clock
	if laps < LAPS then
		print(string.format("[Race] %s lap %d/%d (last lap %.1fs)", car.name, laps + 1, LAPS, lapTime))
		return
	end
	race.finishers += 1
	car.place = race.finishers
	print(string.format("[Race] %s finished place %d (last lap %.1fs)", car.name, race.finishers, lapTime))
	if car == player then
		setPhase("Finished")
	end
end

local function playerPlace(): number
	if player.place then
		return player.place
	end
	return if ai.place or ai.state.distance > player.state.distance then 2 else 1
end

local function bigText(now: number): string
	local elapsed = now - race.phaseStartedAt
	if race.phase == "Countdown" then
		return tostring(math.ceil(COUNTDOWN_SECONDS - elapsed))
	elseif race.phase == "Racing" then
		return if elapsed < GO_SHOW_SECONDS then "GO!" else ""
	end
	return if player.place == 1 then "1등!" else "2등"
end

local function makeLabel(parent: Instance, anchor: Vector2, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(20, 24, 70)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = parent
	return label
end

local hud = Instance.new("ScreenGui")
hud.Name = "RaceHud"
hud.ResetOnSpawn = false
hud.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local lapLabel = makeLabel(hud, Vector2.new(0, 0), UDim2.new(0, 24, 0, 16), UDim2.fromOffset(220, 60))
local placeLabel = makeLabel(hud, Vector2.new(1, 0), UDim2.new(1, -24, 0, 16), UDim2.fromOffset(160, 60))
local bigLabel = makeLabel(hud, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.28), UDim2.fromScale(0.5, 0.25))

local camera = workspace.CurrentCamera

local function cameraGoal(car: Car): CFrame
	local forward = CarPhysics.forward(car.state.heading)
	local position = car.state.position
	return CFrame.lookAt(position - forward * CAMERA_BACK + Vector3.yAxis * CAMERA_UP, position + forward * CAMERA_LOOK_AHEAD)
end

camera.CFrame = cameraGoal(player)
print("[Race] state Countdown")

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	if race.phase == "Countdown" and now - race.phaseStartedAt >= COUNTDOWN_SECONDS then
		setPhase("Racing")
	end
	if race.phase ~= "Countdown" then
		race.unsimulated += dt
		while race.unsimulated >= SIM_STEP do
			race.unsimulated -= SIM_STEP
			race.clock += SIM_STEP
			for _, car in cars do
				updateCar(car)
			end
		end
	end

	for _, car in cars do
		local state = car.state
		local lift = car.pivotHeight + HOVER + math.sin(now * BOB_SPEED + car.bobPhase) * BOB_HEIGHT
		car.model:PivotTo(CFrame.lookAt(state.position, state.position + CarPhysics.forward(state.heading)) + Vector3.yAxis * lift)
	end
	-- Spawning the avatar resets CameraType to Custom, and the default camera then fights this one.
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camera.CFrame:Lerp(cameraGoal(player), 1 - math.exp(-CAMERA_SMOOTHING * dt))

	local text = bigText(now)
	if text ~= bigLabel.Text and race.phase == "Countdown" then
		print("[Race] countdown " .. text)
	end
	bigLabel.Text = text
	lapLabel.Text = string.format("LAP %d/%d", math.min(player.laps + 1, LAPS), LAPS)
	placeLabel.Text = PLACE_NAMES[playerPlace()]
end)
