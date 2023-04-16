local EntityBase = require(script.Parent.EntityBase)
local EntityHelper = {}

function EntityHelper.randomCFrame(rng: Random, worldCenter: Vector3, worldSize: Vector3): CFrame
	local halfSize = 0.5 * worldSize
	local offset = Vector3.new(
		rng:NextNumber(-halfSize.X, halfSize.X),
		rng:NextNumber(-halfSize.Y, halfSize.Y),
		rng:NextNumber(-halfSize.Z, halfSize.Z)
	)
	local position = worldCenter + offset

	return CFrame.new(position)
end

function EntityHelper.spawnEntity(
	entityType: string,
	maxSpeed: number,
	maxAcceleration: number,
    startCFrame: CFrame,
	entityId: number,
	rng: Random,
	entityTemplate: PVInstance?,
	entityParent: Instance?
)
	local velocity = rng:NextUnitVector() * rng:NextNumber(0, maxSpeed)
	local entityBody
	if entityTemplate then
		entityBody = entityTemplate:Clone()
		entityBody.Parent = if entityParent then entityParent else workspace
		entityBody:PivotTo(startCFrame)
		entityBody:SetAttribute("EntityId", entityId)
	end
	
	local entity =
		EntityBase.new(maxSpeed, maxAcceleration, entityType, startCFrame, velocity, Vector3.zero, entityBody)

	return entity
end

return EntityHelper