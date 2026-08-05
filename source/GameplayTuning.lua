-- Central gameplay and presentation tuning. Keeping these values in one table
-- avoids consuming a separate local-variable slot for every setting in main.lua.
GameplayTuning = {
    INITIAL_WORLD_VELOCITY = 1,
    MAX_WORLD_VELOCITY = 8,
    WORLD_VELOCITY_GROWTH_MULTIPLIER = 1.18,
    VELOCITY_INCREASE_INTERVAL_MS = 5000,
    MIN_WORLD_VELOCITY = 0.4,
    REFERENCE_FRAME_DURATION_MS = 1000 / 30,
    -- Catch up after an uneven frame, but never apply a large pause/resume jump.
    MAX_GAMEPLAY_FRAME_DURATION_MS = 1000 / 15,

    DASH_HOLD_THRESHOLD_MS = 200,
    DASH_INITIAL_VELOCITY = 9,
    DASH_INERTIA_RETENTION_PER_FRAME = 0.86,
    DASH_STOP_VELOCITY = 0.1,
    DASH_WAKE_MINIMUM_VELOCITY = 0.5,
    DASH_UI_DRAIN_DURATION_MS = 180,

    ENGINE_MIN_WORLD_RATE = 0.88,
    ENGINE_MAX_WORLD_RATE = 1.18,
    ENGINE_FAST_RATE_MULTIPLIER = 1.12,
    ENGINE_SHRINK_RATE_MULTIPLIER = 1.22,
    ENGINE_MAX_RATE = 1.65,
    ENGINE_NORMAL_VOLUME = 0.24,
    ENGINE_FAST_VOLUME = 0.36,
    ENGINE_SOUND_INTERPOLATION_SPEED = 0.12,

    WATER_FLOW_MIN_RATE = 0.75,
    WATER_FLOW_MAX_RATE = 1.35,
    WATER_FLOW_VOLUME = 0.50,
    WATER_FLOW_RATE_INTERPOLATION_SPEED = 0.08,
    WATER_BACKGROUND_Y_OFFSET = 125,

    MUSIC_NORMAL_RATE = 1.00,
    MUSIC_MAX_RATE = 1.10,
    MUSIC_VOLUME = 0.75,
    MUSIC_RATE_INTERPOLATION_SPEED = 0.04,

    SPEEDOMETER_MIN_ANGLE = -120,
    SPEEDOMETER_MAX_ANGLE = 120,
    SPEEDOMETER_WORLD_SPEED_WEIGHT = 0.70,
    SPEEDOMETER_FAST_MODE_BOOST = 0.15,
    SPEEDOMETER_DASH_BOOST = 0.30,
    SPEEDOMETER_NEEDLE_INTERPOLATION_SPEED = 0.18,

    MAX_ROCKS = 10,
    INTERACTIVE_SPAWN_PADDING = 4,
    INTERACTIVE_SPAWN_ATTEMPTS = 200,
    ROCK_SPAWN_MINIMUM_X = -600,
    COLLECTABLE_SPAWN_MINIMUM_X = -160,
    DECORATION_SPAWN_MINIMUM_X = -300,
    -- Once this speed is reached, decoration spawning stays disabled until restart.
    DECORATION_STOP_SPAWN_WORLD_VELOCITY = 4,
    WORLD_SPAWN_MAXIMUM_Y = 240,
    WORLD_SPAWN_MINIMUM_Y = 40,

    ROCK_Z_INDEX = 0,
    DECORATION_Z_INDEX = -10,
    ROCK_EXPLOSION_Z_INDEX = 10,
    COLLECTABLE_Z_INDEX = 20,
    PLAYER_Z_INDEX = 30,

    -- Each inactive collectable waits for its interval and then rolls its chance.
    COLLECTABLE_SPAWN_CONFIG = {
        coin = {
            spawnChancePercent = 60,
            minimumIntervalMs = 3000,
            maximumIntervalMs = 8000
        },
        shield = {
            spawnChancePercent = 35,
            minimumIntervalMs = 5000,
            maximumIntervalMs = 8000
        },
        shrink = {
            spawnChancePercent = 100,
            minimumIntervalMs = 10000,
            maximumIntervalMs = 18000
        },
        speedReduction = {
            spawnChancePercent = 20,
            minimumIntervalMs = 12000,
            maximumIntervalMs = 20000
        }
    },

    -- Spawn frequency, chance, and pool size can be tuned independently per type.
    DECORATION_SPAWN_CONFIG = {
        {
            name = "bottle",
            imagePath = "images/BottleDecoration",
            spawnChancePercent = 30,
            minimumIntervalMs = 1800,
            maximumIntervalMs = 4000,
            maximumActive = 3
        },
        {
            name = "cattail",
            imagePath = "images/CattailDecoration",
            spawnChancePercent = 90,
            minimumIntervalMs = 2000,
            maximumIntervalMs = 4000,
            maximumActive = 5
        }
    },

    -- Level 3 is the third and final purchased upgrade (levels start at 0).
    SHIELD_HITS_BY_LEVEL = { 1, 2, 3, 5 },
    SHRINK_DURATION_MS_BY_LEVEL = { 5000, 7000, 10000, 15000 },
    SPEED_REDUCTION_BY_LEVEL = { 0.50, 0.75, 1.00, 1.50 },
    DASH_COOLDOWN_MS_BY_LEVEL = { 8000, 7500, 5000, 2500 },

    ABILITY_UPGRADE_COSTS = {
        shield = { 5, 15, 30 },
        shrink = { 5, 15, 30 },
        speedReduction = { 5, 15, 30 },
        dash = { 5, 15, 30 }
    },

    MAX_ABILITY_UPGRADE_LEVEL = 3,
    SHRUNK_PLAYER_SCALE = 0.5,
    PLAYER_SCALE_INTERPOLATION_SPEED = 0.12,
    SAVE_FILE_NAME = "boat-save"
}
