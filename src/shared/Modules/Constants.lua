local Constants = {
    LIMIT_Y_INFLUENCE = Vector3.new(1, 0.25, 1),
    WORLD_CENTER = Vector3.new(0,512,0),
    WORLD_SIZE = Vector3.new(2048,512,2048),
    ENTITY_SIZE = Vector3.new(4, 4, 4),
    NUM_WANDERERS = 250,
    NUM_SEEKERS = 250,
    NUM_FLEAS = 250,
    SEEKER_MAX_SPEED = 100,
    SEEKER_MAX_ACCELERATION = 50,
    WANDERER_MAX_SPEED = 70,
    WANDERER_MAX_ACCELERATION = 50,
    FLEA_MAX_SPEED = 90,
    FLEA_MAX_ACCELERATION = 70,
    VISION_RADIUS = 70,
    VISION_ANGLE = 3 * math.pi / 4,
    ENTITY_OVERLAP_PARAMS = OverlapParams.new(),
    ENTITY_RAYCAST_PARAMS = RaycastParams.new(),
}
Constants.WORLD_HALF_SIZE = 0.5 * Constants.WORLD_SIZE
Constants.NUM_ENTITIES = Constants.NUM_WANDERERS + Constants.NUM_SEEKERS + Constants.NUM_FLEAS
Constants.ENTITY_OVERLAP_PARAMS.CollisionGroup = "EntityOverlaps"
Constants.ENTITY_RAYCAST_PARAMS.CollisionGroup = "EntityCollisionRays"

return Constants