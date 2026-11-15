local SIT_ANIMATION = "rbxassetid://2506281703"
local COCKPIT = CFrame.new(0, 2.6, 0.6)

local Rider = {}

local function silenceDefaultAnimate(character: Model, animator: Animator)
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end
end

function Rider.seat(character: Model, car: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = humanoid:WaitForChild("Animator") :: Animator
	silenceDefaultAnimate(character, animator)

	local body = car.PrimaryPart :: BasePart
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = root
	weld.C0 = body.CFrame:ToObjectSpace(car:GetPivot() * COCKPIT)
	weld.Parent = root

	local sit = Instance.new("Animation")
	sit.AnimationId = SIT_ANIMATION
	animator:LoadAnimation(sit):Play()
end

return Rider
