local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayerScripts = script.Parent.Parent.Parent

local Initialize = PlayerScripts.Main.Initialize
local Settings = script.Parent.Settings
local ReadyToReceive = Settings.ReadyToReceive
local CollisionAvoidanceStrength = Settings.CollisionAvoidanceStrength
local ContainmentStrength = Settings.ContainmentStrength
local WanderStrength = Settings.WanderStrength
local FlockStrength = Settings.FlockStrength
local SeekStrength = Settings.SeekStrength

local ReplicatedConstants = require(ReplicatedStorage.Modules.Constants)
local ClientModules = PlayerScripts:WaitForChild("Modules")
local ClientConstants = require(ClientModules:WaitForChild("Constants"))
local EntityBase = require(ClientModules:WaitForChild("EntityBase"))
local seekers: { EntityBase.Entity } = table.create(ReplicatedConstants.NUM_SEEKERS)
local entityIndexLookup = table.create(ReplicatedConstants.NUM_FLEAS)

local START_INDEX = ReplicatedConstants.NUM_WANDERERS + 1

for i = 1, ReplicatedConstants.NUM_FLEAS do
	entityIndexLookup[i] = START_INDEX + (i - 1)
end

local function evaluateLocalCharacter(currentCFrame)
	local character = Players.LocalPlayer.Character
	if character == nil then
		return
	end

	local characterCFrame = character.HumanoidRootPart.CFrame
	local displacement = characterCFrame.Position - currentCFrame.Position
	local distance = displacement.Magnitude
	local angle = currentCFrame.LookVector:Angle(displacement.Unit)
	if distance > ReplicatedConstants.VISION_RADIUS or angle > ReplicatedConstants.VISION_ANGLE then
		return
	end

	return {entityType = "Player", cFrame = characterCFrame, velocity = character.LinearVelocity.VectorVelocity }, distance
end

local function getSteeringBehaviors(seeker, currentCFrame: CFrame, entityIndex: number, nearby: { BasePart })
	local seenEntities = table.create(#nearby)
	local closestEntity: { entityType: string, cFrame: CFrame, velocity: Vector3 }? = nil
	local closestEntityDistance = math.huge

	for _, otherEntityBody: BasePart in nearby do
		local otherEntityModel = otherEntityBody.Parent
		if otherEntityModel:GetAttribute("EntityId") == entityIndex then
			continue
		end

		local entityData = {
			entityType = otherEntityModel:GetAttribute("EntityType"),
			cFrame = otherEntityModel:GetAttribute("cFrame"),
			velocity = otherEntityModel:GetAttribute("Velocity"),
		}

		local displacement = entityData.cFrame.Position - currentCFrame.Position
		local angle = currentCFrame.LookVector:Angle(displacement.Unit)
		if angle > ReplicatedConstants.VISION_ANGLE then
			continue
		end

		local distance = displacement.Magnitude
		if entityData.entityType ~= "Seeker" and distance < closestEntityDistance then
			closestEntity = entityData
			closestEntityDistance = distance
		end

		table.insert(seenEntities, entityData)
	end

	local characterEntity, distance = evaluateLocalCharacter(currentCFrame)
	if characterEntity and distance < closestEntityDistance then
		closestEntity = characterEntity
	end

	local collisionAvoidance = seeker:collisionAvoidance(ReplicatedConstants.VISION_RADIUS)
	local containment = seeker:containment(ReplicatedConstants.WORLD_CENTER, ReplicatedConstants.WORLD_HALF_SIZE)
	local wanderSteering = seeker:wander() * ReplicatedConstants.LIMIT_Y_INFLUENCE
	local flockSteering = seeker:flock(seenEntities)
	local seekSteering = if closestEntity
		then seeker:pursue(closestEntity.cFrame.Position, closestEntity.velocity)
		else Vector3.zero

	return collisionAvoidance, containment, wanderSteering, flockSteering, seekSteering
end

local count = 0
local runningTime = 0
function updateSeekerData(dt)
	local start = os.clock()
	for seekerIndex, seeker in seekers do
		if not seeker.isAlive then
			continue
		end

		local currentCFrame = seeker.CFrame
		local collisionAvoidance, containment, wanderSteering, flockSteering, seekSteering = getSteeringBehaviors(
			seeker,
			currentCFrame,
			entityIndexLookup[seekerIndex],
			workspace:GetPartBoundsInRadius(
				currentCFrame.Position,
				ReplicatedConstants.VISION_RADIUS,
				ReplicatedConstants.ENTITY_OVERLAP_PARAMS
			)
		)

		seeker.acceleration = collisionAvoidance * CollisionAvoidanceStrength.Value
			+ containment * ContainmentStrength.Value
			+ wanderSteering * WanderStrength.Value
			+ flockSteering * FlockStrength.Value
			+ seekSteering * SeekStrength.Value

		seeker:update(dt)
	end

	runningTime += os.clock() - start
	count += 1
end

Initialize.Event:Once(function(entities)
	for i = 1, ReplicatedConstants.NUM_SEEKERS do
		local entity = setmetatable(entities[entityIndexLookup[i]], EntityBase)
		seekers[i] = entity
	end

	RunService.Heartbeat:ConnectParallel(updateSeekerData)

	RunService.Heartbeat:Connect(function(_dt)
		for _, seeker in seekers do
			seeker:reconcileInstance()
		end
	end)

	task.defer(function()
		while task.wait(ClientConstants.PERFORMANCE_REPORT_DELAY) do
			print(`[Seekers Job] Average Clock time: {runningTime / count}`)
		end
	end)
end)

ReadyToReceive.Value = true
