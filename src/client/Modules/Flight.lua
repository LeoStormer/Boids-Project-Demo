local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(script.Parent.Constants)
local ReplicatedConstants = require(ReplicatedStorage.Modules.Constants)
local Spring = require(ReplicatedStorage.Packages.Spring)

local player = Players.LocalPlayer
local ControlModule = require(
	player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule") :: ModuleScript
)
local spawnCFrame =
	CFrame.new((ReplicatedConstants.WORLD_CENTER - Vector3.new(0, ReplicatedConstants.WORLD_HALF_SIZE.Y, 0)) / 2)

local FlightAnimation = Instance.new("Animation")
FlightAnimation.AnimationId = "http://www.roblox.com/asset/?id=10174626650"
local FlightIdleAnimation = Instance.new("Animation")
FlightIdleAnimation.AnimationId = "http://www.roblox.com/asset/?id=12888302224"

local Flight = {}
Flight._alive = false
Flight._spring = Spring.new(Constants.MAX_FLIGHT_SPEED)
Flight._spring.Speed = 0.7
Flight._spring.Damper = 1

Flight._linearVelocity = Instance.new("LinearVelocity")
Flight._linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
Flight._linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
Flight._linearVelocity.MaxForce = math.huge
Flight._linearVelocity.Enabled = true

Flight._alignOrientaion = Instance.new("AlignOrientation")
Flight._alignOrientaion.Mode = Enum.OrientationAlignmentMode.OneAttachment
Flight._alignOrientaion.MaxAngularVelocity = math.huge
Flight._alignOrientaion.MaxTorque = math.huge
Flight._alignOrientaion.Responsiveness = 20
Flight._alignOrientaion.Enabled = true

local function onCharacterAdded(character)
	local rootRigAttachment = character:WaitForChild("HumanoidRootPart"):WaitForChild("RootRigAttachment")
    local humanoid: Humanoid = character:WaitForChild("Humanoid")
    local animator: Animator = humanoid:WaitForChild("Animator") :: Animator
    
	Flight._linearVelocity.Parent = character
	Flight._linearVelocity.Attachment0 = rootRigAttachment
	Flight._linearVelocity.VectorVelocity = Vector3.zero

	Flight._alignOrientaion.Parent = character
	Flight._alignOrientaion.Attachment0 = rootRigAttachment
	Flight._alignOrientaion.CFrame = spawnCFrame

    Flight._flightAnimTrack = animator:LoadAnimation(FlightAnimation)
    Flight._flightAnimTrack.Looped = true
    Flight._flightAnimTrack.Priority = Enum.AnimationPriority.Movement

    Flight._flightIdleTrack = animator:LoadAnimation(FlightIdleAnimation)
    Flight._flightIdleTrack:Play()

	humanoid.Died:Once(function()
		Flight._alive = false
	end)

    Flight._alive = true
    Flight._spring.Position = Constants.MIN_FLIGHT_SPEED
    character:PivotTo(spawnCFrame)
end

function Flight:update(_dt)
	if not self._alive then
		return
	end

	local inputVector = ControlModule:GetMoveVector()
	if inputVector == Vector3.zero then
        if self._flightAnimTrack.IsPlaying then
            self._flightAnimTrack:Stop()
        end
		self._spring.Position = Constants.MIN_FLIGHT_SPEED
		self._linearVelocity.VectorVelocity = inputVector
	else
        if not self._flightAnimTrack.IsPlaying then
            self._flightAnimTrack:Play(1)
        end
		local camCFrame = workspace.CurrentCamera.CFrame
		local speed = self._spring.Position
		local moveDirection = ((inputVector.X * camCFrame.RightVector) - (inputVector.Z * camCFrame.LookVector)).Unit
		self._linearVelocity.VectorVelocity = moveDirection * speed
		self._alignOrientaion.CFrame =
			CFrame.fromMatrix(Vector3.zero, moveDirection:Cross(camCFrame.UpVector), camCFrame.UpVector, -moveDirection)
	end
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

return Flight
