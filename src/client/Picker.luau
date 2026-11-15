local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Courses = require(game:GetService("ReplicatedStorage").Shared.Courses)
local World = require(script.Parent.World)

local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadThree] = 3,
}
local BACKDROP = Color3.fromRGB(8, 6, 28)
local TEXT = Color3.new(1, 1, 1)
local STROKE = Color3.fromRGB(20, 24, 70)

local Picker = {}

local function label(parent: Instance, text: string, font: Enum.Font, position: UDim2, size: UDim2): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Font = font
	item.Text = text
	item.TextScaled = true
	item.TextWrapped = true
	item.TextColor3 = TEXT
	item.TextStrokeColor3 = STROKE
	item.TextStrokeTransparency = 0.3
	item.Parent = parent
	return item
end

function Picker.choose(courses: { Courses.Course }): Courses.Course
	local gui = Instance.new("ScreenGui")
	gui.Name = "CoursePicker"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = BACKDROP
	backdrop.Parent = gui

	label(backdrop, "코스를 고르세요", Enum.Font.FredokaOne, UDim2.fromScale(0.1, 0.08), UDim2.fromScale(0.8, 0.12))

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0.05, 0.28)
	row.Size = UDim2.fromScale(0.9, 0.5)
	row.Parent = backdrop
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = row

	local waiting = coroutine.running()
	local connection: RBXScriptConnection
	local function pick(course: Courses.Course)
		connection:Disconnect()
		gui:Destroy()
		task.spawn(waiting, course)
	end

	for index, course in courses do
		local accent = World.look(course.id).accent
		local button = Instance.new("TextButton")
		button.Name = course.id
		button.LayoutOrder = index
		button.Text = ""
		button.AutoButtonColor = true
		button.Size = UDim2.fromScale(0.3, 1)
		button.BackgroundColor3 = accent:Lerp(BACKDROP, 0.65)
		button.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.06, 0)
		corner.Parent = button
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Color = accent
		outline.Thickness = 4
		outline.Parent = button

		label(button, tostring(index), Enum.Font.FredokaOne, UDim2.fromScale(0.1, 0.06), UDim2.fromScale(0.8, 0.28)).TextColor3 = accent
		label(button, course.title, Enum.Font.GothamBold, UDim2.fromScale(0.08, 0.38), UDim2.fromScale(0.84, 0.2))
		label(button, course.blurb, Enum.Font.Gotham, UDim2.fromScale(0.1, 0.64), UDim2.fromScale(0.8, 0.24))

		button.Activated:Connect(function()
			pick(course)
		end)
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	connection = UserInputService.InputBegan:Connect(function(input)
		local index = KEYS[input.KeyCode]
		if index and courses[index] then
			pick(courses[index])
		end
	end)
	return coroutine.yield()
end

return Picker
