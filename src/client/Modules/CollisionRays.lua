local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Phi = 0.5 * (1 + math.sqrt(5))
local AngleIncrement = 2 * math.pi * Phi
local ReplicatedConstants = require(ReplicatedStorage.Modules.Constants)
local ClientConstants = require(script.Parent.Constants)

local CollisionRays: { Vector3 } = {}

for i = 0, ClientConstants.NUM_COLLISION_RAYS - 1 do
	local t = i / ClientConstants.NUM_COLLISION_RAYS
	local Inclination = math.acos(1 - 2 * t)
	local Azimuth = AngleIncrement * i
	local x = math.sin(Inclination) * math.cos(Azimuth)
	local y = math.sin(Inclination) * math.sin(Azimuth)
	local z = math.cos(Inclination)
	CollisionRays[i + 1] = -Vector3.new(x, y, z)
end

local forwardVector = -Vector3.zAxis
for i = ClientConstants.NUM_COLLISION_RAYS, 1, -1 do
    local ray = CollisionRays[i]
    if forwardVector:Angle(ray) > ReplicatedConstants.VISION_RADIUS then
        table.remove(CollisionRays, i)
    else
        break
    end
end

return CollisionRays
