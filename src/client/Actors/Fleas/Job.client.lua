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
local FleeStrength = Settings.FleeStrength

local ReplicatedConstants = require(ReplicatedStorage.Modules.Constants)
local ClientModules = PlayerScripts:WaitForChild("Modules")
local ClientConstants = require(ClientModules:WaitForChild("Constants"))
local EntityBase = require(ClientModules:WaitForChild("EntityBase"))
local fleas: { EntityBase.Entity } = table.create(ReplicatedConstants.NUM_FLEAS)
local entityIndexLookup = table.create(ReplicatedConstants.NUM_FLEAS)

local START_INDEX = ReplicatedConstants.NUM_WANDERERS + ReplicatedConstants.NUM_SEEKERS + 1

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
	
	if distance > ReplicatedConstants.VISION_RADIUS then
		return
	end

	return {entityType = "Player", cFrame = characterCFrame, velocity = character.LinearVelocity.VectorVelocity }, distance
end

local function getSteeringBehaviors(flea, entityIndex: number, nearby: { BasePart })
	local seenEntities = table.create(#nearby)
	local fleeSteering = Vector3.zero

	for _, otherEntityBody in nearby do
		local otherEntityModel = otherEntityBody.Parent
		if otherEntityModel:GetAttribute("EntityId") == entityIndex then
			continue
		end

		local entityData = {
			entityType = otherEntityModel:GetAttribute("EntityType"),
			cFrame = otherEntityModel:GetAttribute("cFrame"),
			velocity = otherEntityModel:GetAttribute("Velocity"),
		}

		if entityData.entityType ~= "Flea" then
			fleeSteering += flea:flee(entityData.cFrame.Position)
		end

		table.insert(seenEntities, entityData)
	end

	local characterEntity = evaluateLocalCharacter(flea.CFrame)
	if characterEntity then
		fleeSteering += flea:flee(characterEntity.cFrame.Position)
	end

	local collisionAvoidance = flea:collisionAvoidance(ReplicatedConstants.VISION_RADIUS)
	local containment = flea:containment(ReplicatedConstants.WORLD_CENTER, ReplicatedConstants.WORLD_HALF_SIZE)
	local wanderSteering = flea:wander() * ReplicatedConstants.LIMIT_Y_INFLUENCE
	local flockSteering = flea:flock(seenEntities)

	return collisionAvoidance,
		containment,
		wanderSteering,
		flockSteering,
		EntityBase.clampVector(fleeSteering, flea.maxAcceleration)
end

local count = 0
local runningTime = 0
function updateFleaData(dt)
	local start = os.clock()
	for fleaIndex, flea in fleas do
		if not flea.isAlive then
			continue
		end

		local collisionAvoidance, containment, wanderSteering, flockSteering, fleeSteering = getSteeringBehaviors(
			flea,
			entityIndexLookup[fleaIndex],
			workspace:GetPartBoundsInRadius(
				flea.CFrame.Position,
				ReplicatedConstants.VISION_RADIUS,
				ReplicatedConstants.ENTITY_OVERLAP_PARAMS
			)
		)

		flea.acceleration = collisionAvoidance * CollisionAvoidanceStrength.Value
			+ containment * ContainmentStrength.Value
			+ wanderSteering * WanderStrength.Value
			+ flockSteering * FlockStrength.Value
			+ fleeSteering * FleeStrength.Value

		flea:update(dt)
	end

	runningTime += os.clock() - start
	count += 1
end

Initialize.Event:Once(function(entities)
	for i = 1, ReplicatedConstants.NUM_FLEAS do
		local entity = setmetatable(entities[entityIndexLookup[i]], EntityBase)
		fleas[i] = entity
	end

	RunService.Heartbeat:ConnectParallel(updateFleaData)
	RunService.Heartbeat:Connect(function(_dt)
		for _, flea in fleas do
			flea:reconcileInstance()
		end
	end)

	task.defer(function()
		while task.wait(ClientConstants.PERFORMANCE_REPORT_DELAY) do
			print(`[Fleas Job] Average Clock time: {runningTime / count}`)
		end
	end)
end)

ReadyToReceive.Value = true
