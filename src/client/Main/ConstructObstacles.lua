local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(script.Parent.Parent.Modules.Constants)
local ObstacleTemplates = ReplicatedStorage.ObstacleTemplates

local obstacles = {
	ObstacleTemplates.SmallRing,
	ObstacleTemplates.SmallTube,
	ObstacleTemplates.MediumRing,
	ObstacleTemplates.MediumTube,
	ObstacleTemplates.LargeRing,
	ObstacleTemplates.LargeTube,
}

local function randomCFrame(worldCenter: Vector3, worldSize: Vector3, objectSize: Vector3, rng: Random)
	local largestAxis = math.max(objectSize.X, objectSize.Y, objectSize.Z)
	local effectiveWorldSize = worldSize - Vector3.one * largestAxis
	local halfSize = 0.5 * effectiveWorldSize
	
	local position = worldCenter
		+ Vector3.new(
			rng:NextNumber(-halfSize.X, halfSize.X),
			rng:NextNumber(-halfSize.Y, halfSize.Y),
			rng:NextNumber(-halfSize.Z, halfSize.Z)
		)

	local rightVector = rng:NextUnitVector()
	local lookVector = rng:NextUnitVector()
	local upVector = rightVector:Cross(lookVector)
	lookVector = rightVector:Cross(upVector)
	return CFrame.fromMatrix(position, rightVector, upVector, lookVector):Orthonormalize()
end

return function(worldCenter: Vector3, worldSize: Vector3, rng: Random)
	local function scatterObstaclesAround(numObstacles: number, startIndex: number, endIndex: number)
		for _ = 1, numObstacles do
			local obstacle = obstacles[rng:NextInteger(startIndex, endIndex)]:Clone()
			local size = obstacle:GetExtentsSize()
			local obstaclePlaced = false
			local tries = 0
			local cframe = nil

			repeat
				cframe = randomCFrame(worldCenter, worldSize, size, rng)
				tries += 1
				obstaclePlaced = #workspace:GetPartBoundsInBox(cframe, size) == 0
			until obstaclePlaced or tries >= 10

			if obstaclePlaced then
				obstacle:PivotTo(cframe)
				obstacle.Parent = workspace.Obstacles
			else
				obstacle:Destroy()
				return
			end
		end
	end

	scatterObstaclesAround(Constants.NUM_SMALL_OBSTACLES, 1, 2)
	scatterObstaclesAround(Constants.NUM_MEDIUM_OBSTACLES, 3, 4)
	scatterObstaclesAround(Constants.NUM_LARGE_OBSTACLES, 5, 6)
end
