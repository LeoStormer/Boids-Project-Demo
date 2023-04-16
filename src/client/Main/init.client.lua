local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ReplicatedConstants = require(ReplicatedStorage.Modules.Constants)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ClientConstants = require(script.Parent:WaitForChild("Modules"):WaitForChild("Constants"))
local Flight = require(script.Parent.Modules.Flight)
local rng = Random.new()

local Start = Signal.new()
local EntityHelper = require(script.Parent.Modules.EntityHelper)
require(script.ConstructObstacles)(ReplicatedConstants.WORLD_CENTER, ReplicatedConstants.WORLD_SIZE, rng)

local wandererIndex = { startIndex = 1, endIndex = ReplicatedConstants.NUM_WANDERERS }
local seekerIndex =
	{ startIndex = wandererIndex.endIndex + 1, endIndex = wandererIndex.endIndex + ReplicatedConstants.NUM_SEEKERS }
local fleaIndex =
	{ startIndex = seekerIndex.endIndex + 1, endIndex = seekerIndex.endIndex + ReplicatedConstants.NUM_FLEAS }

local Entities = table.create(ReplicatedConstants.NUM_ENTITIES)

function spawnEntities(
	entityType: string,
	startIndex: number,
	endIndex: number,
	entityTemplate: PVInstance,
	maxSpeed: number,
	maxAcceleration: number
)
	for i = startIndex, endIndex do
		local entity = EntityHelper.spawnEntity(
			entityType,
			maxSpeed,
			maxAcceleration,
			EntityHelper.randomCFrame(rng, ReplicatedConstants.WORLD_CENTER, ReplicatedConstants.WORLD_SIZE),
			i,
			rng,
			entityTemplate,
			workspace.Entities
		)

		Entities[i] = entity
	end
end

spawnEntities(
	"Wanderer",
	wandererIndex.startIndex,
	wandererIndex.endIndex,
	ReplicatedStorage.EntityTemplates.Wanderer,
	ReplicatedConstants.WANDERER_MAX_SPEED,
	ReplicatedConstants.WANDERER_MAX_ACCELERATION
)

spawnEntities(
	"Seeker",
	seekerIndex.startIndex,
	seekerIndex.endIndex,
	ReplicatedStorage.EntityTemplates.Seeker,
	ReplicatedConstants.SEEKER_MAX_SPEED,
	ReplicatedConstants.SEEKER_MAX_ACCELERATION
)

spawnEntities(
	"Flea",
	fleaIndex.startIndex,
	fleaIndex.endIndex,
	ReplicatedStorage.EntityTemplates.Flea,
	ReplicatedConstants.FLEA_MAX_SPEED,
	ReplicatedConstants.FLEA_MAX_ACCELERATION
)

Start:Once(function()
	script.Initialize:Fire(Entities)
	local count = 0
	local runningTime = 0
	RunService.Heartbeat:Connect(function(dt)
		count += 1
		runningTime += dt
		Flight:update(dt)
	end)

	task.spawn(function()
		while true do
			task.wait(ClientConstants.PERFORMANCE_REPORT_DELAY)
			print("-------------------------------------------------------------")
			print(`[Main] Average Frame time: {runningTime / count}`)
		end
	end)
end)

local workers = script.Parent.Actors:GetChildren()
local numWorkers = #workers
local numWorkersReady = 0
for _, worker in workers do
	local readyToReceive: BoolValue = worker.Settings.ReadyToReceive
	if readyToReceive.Value == true then
		numWorkersReady += 1
	else
		readyToReceive.Changed:Once(function()
			numWorkersReady += 1
			if numWorkersReady == numWorkers then
				Start:Fire()
			end
		end)
	end

	if numWorkersReady == numWorkers then
		Start:Fire()
	end
end