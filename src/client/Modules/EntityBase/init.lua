local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeparationStrength = script.Settings.SeparationStrength --Determines how much strength is used to keep an entity away from flock mates
local CohesionStrength = script.Settings.CohesionStrength --Determines how much strength is used to keep an entity close to flock mates
local AlignmentStrength = script.Settings.AlignmentStrength --Determines how much strength is used to keep an entity moving in the same direction as flock mates
local WanderSphereRadius = script.Settings.WanderSphereRadius --Determines how erratic an entity's wandering is
local Constants = require(ReplicatedStorage.Modules.Constants)

local CollisionRays = require(script.Parent.CollisionRays)

local TWO_PI = math.pi * 2

local EntityBase = {}
EntityBase.__index = EntityBase
EntityBase.separationStrength = SeparationStrength.Value
EntityBase.cohesionStrength = CohesionStrength.Value
EntityBase.alignmentStrength = AlignmentStrength.Value
EntityBase.wanderSphereRadius = WanderSphereRadius.Value
EntityBase.rng = Random.new()

SeparationStrength.Changed:Connect(function(strength)
	EntityBase.separationStrength = strength
end)

CohesionStrength.Changed:Connect(function(strength)
	EntityBase.cohesionStrength = strength
end)

AlignmentStrength.Changed:Connect(function(strength)
	EntityBase.alignmentStrength = strength
end)

WanderSphereRadius.Changed:Connect(function(strength)
	EntityBase.separationStrength = strength
end)

function EntityBase.__tostring(entity)
	return `Entity({entity.entityType})`
end

function EntityBase.clampVector(vector: Vector3, maxMagnitude: number): Vector3
	return if vector.Magnitude < maxMagnitude then vector else vector.Unit * maxMagnitude
end

function EntityBase.new(
	maxSpeed: number,
	maxAcceleration: number,
	entityType: string,
	startCFrame: CFrame?,
	velocity: Vector3?,
	acceleration: Vector3?,
	instance: PVInstance?
)
	local self = setmetatable({
		_theta = EntityBase.rng:NextNumber(0, TWO_PI),
		_phi = EntityBase.rng:NextNumber(0, math.pi),
		instance = instance,
		isAlive = true,
		maxSpeed = maxSpeed,
		maxAcceleration = maxAcceleration,
		entityType = entityType,
		CFrame = if startCFrame then startCFrame else CFrame.identity,
		velocity = if velocity then velocity else Vector3.zero,
		acceleration = if acceleration then acceleration else Vector3.zero,
	}, EntityBase)
	
	if instance then 
		instance:SetAttribute("EntityType", entityType)
		instance:SetAttribute("MaxSpeed", maxSpeed)
		instance:SetAttribute("MaxAcceleration", maxAcceleration)
		instance:SetAttribute("Velocity", velocity)
		instance:SetAttribute("cFrame", self.CFrame)
	end

	return self
end

function EntityBase:update(dt: number)
	self.velocity = EntityBase.clampVector(
		self.velocity + EntityBase.clampVector(self.acceleration, self.maxAcceleration) * dt,
		self.maxSpeed
	)
	local Position = self.CFrame.Position + self.velocity * dt
	local lookVector = if self.velocity.Magnitude == 0 then self.CFrame.LookVector else self.velocity.Unit
	local rightVector = lookVector:Cross(Vector3.yAxis)
	local upVector = rightVector:Cross(lookVector)
	self.CFrame = CFrame.fromMatrix(Position, rightVector, upVector, -lookVector):Orthonormalize()
end

function EntityBase:reconcileInstance()
	if self.instance then
		local inst: PVInstance = self.instance
		inst:SetAttribute("Velocity", self.velocity)
		inst:SetAttribute("cFrame", self.CFrame)
		inst:PivotTo(self.CFrame)
	end
end

function EntityBase:getInstance()
	return self.instance
end

function EntityBase:getCFrame(): CFrame
	return self.CFrame
end

function EntityBase:getAcceleration(): Vector3
	return self.acceleration
end

function EntityBase:getVelocity(): Vector3
	return self.velocity
end

function EntityBase:getMaxSpeed(): number
	return self.maxSpeed
end

function EntityBase:getMaxAcceleration(): number
	return self.maxAcceleration
end

function EntityBase:setInstance(inst: PVInstance)
	self.instance = inst
end

function EntityBase:setCFrame(CFrame: CFrame)
	self.CFrame = CFrame
end

function EntityBase:setMaxAcceleration(acceleration: Vector3)
	self.maxAcceleration = acceleration
end

function EntityBase:setAcceleration(acceleration: Vector3)
	self.acceleration = acceleration
end

function EntityBase:setVelocity(velocity: Vector3)
	self.velocity = velocity
end

function EntityBase:containment(worldCenter: Vector3, worldHalfSize: Vector3)
	local displacementFromCenter = self.CFrame.Position - worldCenter

	local min = Vector3.new(
		math.abs(displacementFromCenter.X),
		math.abs(displacementFromCenter.Y),
		math.abs(displacementFromCenter.Z)
	)
	min = min:Min(worldHalfSize)

	return EntityBase.clampVector(
		Vector3.new(
			if min.X == worldHalfSize.X then -displacementFromCenter.X else 0,
			if min.Y == worldHalfSize.Y then -displacementFromCenter.Y else 0,
			if min.Z == worldHalfSize.Z then -displacementFromCenter.Z else 0
		),
		self.maxAcceleration
	)
end

function EntityBase:collisionAvoidance(visionRadius: number)
	for _, collisionRay in CollisionRays do
		local direction = self.CFrame:VectorToWorldSpace(collisionRay)
		local result = workspace:Raycast(self.CFrame.Position, direction * visionRadius, Constants.ENTITY_RAYCAST_PARAMS)
		if result == nil then
			local desiredVelocity = direction * self.velocity.Magnitude
			return EntityBase.clampVector(desiredVelocity - self.velocity, self.maxAcceleration)
		end
	end
	
	return self.CFrame:VectorToWorldSpace(Vector3.zAxis) * self.maxAcceleration
end

function EntityBase:seek(targetPosition: Vector3): Vector3
	local desiredVelocity = (targetPosition - self.CFrame.Position).Unit * self.maxSpeed
	return EntityBase.clampVector(desiredVelocity - self.velocity, self.maxAcceleration)
end

function EntityBase:flee(targetPosition: Vector3): Vector3
	return -self:seek(targetPosition)
end

function EntityBase:arrive(targetPosition: Vector3): Vector3
	local displacemant = targetPosition - self.CFrame.Position
	local distance = displacemant.Magnitude
	local desiredVelocity = displacemant.Unit * self.maxSpeed
	if distance < self.maxSpeed then
		desiredVelocity *= distance / self.maxSpeed
	end

	return EntityBase.clampVector(desiredVelocity - self.velocity, self.maxAcceleration)
end

local frameLookAhead = 10
local frameStep = frameLookAhead / 60
function EntityBase:pursue(targetPosition: Vector3, targetVelocity: Vector3): Vector3
	local pursuerPosition = self.CFrame.Position

	local distance = (pursuerPosition - targetPosition).Magnitude
	local timeStep = frameStep * math.min(1, distance / self.maxSpeed)
	local futurePosition = targetPosition + targetVelocity * timeStep

	local desiredVelocity = (futurePosition - pursuerPosition).Unit * self.maxSpeed
	return EntityBase.clampVector(desiredVelocity - self.velocity, self.maxAcceleration)
end

function EntityBase:evade(targetPosition: Vector3, targetVelocity: Vector3): Vector3
	return -self:pursue(targetPosition, targetVelocity)
end

function EntityBase:wander(): Vector3
	local heading = if self.velocity.Magnitude == 0 then EntityBase.rng:NextUnitVector() else self.velocity.Unit
	local currentPosition = self.CFrame.Position
	local sphereCenter = currentPosition + heading * 5
	local sinPhi = math.sin(self._phi)
	local cosPhi = math.cos(self._phi)
	local sinTheta = math.sin(self._theta)
	local cosTheta = math.cos(self._theta)

	local radialVector = Vector3.new(
		self.wanderSphereRadius * sinPhi * cosTheta,
		self.wanderSphereRadius * sinPhi * sinTheta,
		self.wanderSphereRadius * cosPhi
	)

	radialVector += EntityBase.rng:NextUnitVector() * 3
	radialVector = radialVector.Unit * self.wanderSphereRadius
	self._theta = (Vector3.xAxis):Angle(radialVector, Vector3.zAxis)
	self._phi = (Vector3.yAxis):Angle(radialVector)
	local pointOnSurface = sphereCenter + radialVector

	return EntityBase.clampVector(pointOnSurface - currentPosition, self.maxAcceleration)
end

function EntityBase:flock(nearby: { {entityType: string, cFrame: CFrame, velocity: Vector3} }): Vector3
	local separationSteering = Vector3.zero
	local cohesionSteering = Vector3.zero
	local alignmentSteering = Vector3.zero
	local currentPosition = self.CFrame.Position
	local flockSteering = Vector3.zero
	local count = 0

	for _, otherEntity: Entity in nearby do
		if otherEntity == self or otherEntity.entityType ~= self.entityType then
			continue
		end

		local otherPosition = otherEntity.cFrame.Position
		cohesionSteering += otherPosition
		separationSteering += currentPosition - otherPosition
		alignmentSteering += otherEntity.velocity
		count += 1
	end

	if count > 0 then
		cohesionSteering = EntityBase.clampVector((cohesionSteering / count) - currentPosition, self.maxAcceleration)
		separationSteering = EntityBase.clampVector(separationSteering / count, self.maxAcceleration)
		alignmentSteering = EntityBase.clampVector(alignmentSteering / count, self.maxAcceleration)
		flockSteering = EntityBase.clampVector(
			separationSteering * self.separationStrength
				+ cohesionSteering * self.cohesionStrength
				+ alignmentSteering * self.alignmentStrength,
			self.maxAcceleration
		)
	end

	return flockSteering
end

function EntityBase:destroy()
	self.instance:Destroy()
end
EntityBase.Destroy = EntityBase.destroy

export type Entity = typeof(EntityBase.new(10, 5, "EntityBase"))

return EntityBase
