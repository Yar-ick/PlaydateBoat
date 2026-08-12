-- Central gameplay and presentation tuning. Keeping these values in one table
-- avoids consuming a separate local-variable slot for every setting in main.lua.
GameplayTuning = {
    MAIN_MENU_BOAT_X = 225,
    MAIN_MENU_BOAT_Y = 175,
    MAIN_MENU_BOAT_FRAME_INDEX = 25,
    MAIN_MENU_BACKGROUND_CENTER_Y = 120,
    MAIN_MENU_BACKGROUND_OFFSCREEN_Y = -120,
    MAIN_MENU_WATER_CENTER_Y = 270,
    MAIN_MENU_START_TEXT_X = 337,
    MAIN_MENU_START_TEXT_Y = 192,
    MAIN_MENU_UPGRADE_TEXT_X = 337,
    MAIN_MENU_UPGRADE_TEXT_Y = 218,
    UPGRADE_MENU_SLIDE_DURATION_MS = 500,
    UPGRADE_MENU_MESSAGE_DURATION_MS = 1500,
    UPGRADE_LEVEL_BLINK_INTERVAL_MS = 450,
    GAMEPLAY_ENTRY_BOAT_X = 150,
    GAMEPLAY_ENTRY_BOAT_Y = 120,
    GAMEPLAY_ENTRY_BOAT_ANGLE = 275,
    MENU_LAUNCH_CURVE = {
        SPLIT = 0.55,
        FIRST_CONTROL_X = 225,
        FIRST_CONTROL_Y = 180,
        TURN_CONTROL_X = 225,
        TURN_CONTROL_Y = 180,
        TURN_X = 215,
        TURN_Y = 185,
        SECOND_CONTROL_X = 200,
        SECOND_CONTROL_Y = 190,
        FINAL_CONTROL_X = 150,
        FINAL_CONTROL_Y = 195,
        FINAL_ROTATION_START = 0.72
    },
    MENU_BOAT_ROTATION_RESPONSE_PER_SECOND = 10,
    MENU_LAUNCH_DURATION_MS = 1800,
    MENU_RETURN_DURATION_MS = 1800,
    CRASH_REWIND_SPEED_PIXELS_PER_SECOND = 180,
    CRASH_REWIND_ACCELERATION_MS = 450,
    CRASH_RETURN_DELAY_MS = 2000,
    START_CRANK_MOVEMENT_DEGREES = 5,
    START_ROTATION_DURATION_MS = 700,

    INITIAL_WORLD_VELOCITY = 1,
    MAX_WORLD_VELOCITY = 8,
    WORLD_VELOCITY_GROWTH_MULTIPLIER = 1.18,
    VELOCITY_INCREASE_INTERVAL_MS = 5000,
    MIN_WORLD_VELOCITY = 0.4,
    -- Catch up after an uneven frame, but never apply a large pause/resume jump.
    MAX_GAMEPLAY_FRAME_DURATION_MS = 1000 / 15,
    -- Playdate renders on whole pixels. Snapping the shared displacement prevents
    -- fractional speeds from alternating between short and long visual steps.
    MINIMUM_WORLD_PIXEL_DISPLACEMENT = 1,

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
    WATER_BACKGROUND_Y_OFFSET = 120,

    MUSIC_NORMAL_RATE = 1.00,
    MUSIC_MAX_RATE = 1.10,
    MUSIC_VOLUME = 0.75,
    MUSIC_RATE_INTERPOLATION_SPEED = 0.04,

    HUD_HEIGHT = 5,
    HUD_NUMBER_BACKGROUND_PADDING = 1,
    HUD_SLIDE_DURATION_MS = 600,
    HUD_LEFT_HIDDEN_OFFSET_X = -240,
    HUD_RIGHT_HIDDEN_OFFSET_X = 140,

    TOP_UI_DASH_FRAME_X = 40,
    TOP_UI_SHRINK_FRAME_X = 74,
    TOP_UI_ABILITY_FRAME_Y = 2,
    TOP_UI_SHIELD_FIRST_X = 122,
    TOP_UI_SHIELD_FULL_FIRST_X = 124,
    TOP_UI_SHIELD_CENTER_Y = 18,
    TOP_UI_SHIELD_ICON_SCALE = 0.60,
    -- 25px shield * 0.88 / 2 + 2px gap + 3px ring spacing = 16px radius.
    TOP_UI_SHIELD_FULL_FIRST_ICON_SCALE = 0.88,
    TOP_UI_SHIELD_DOUBLE_RING_SPACING = 30,
    TOP_UI_SHIELD_FULL_FIRST_GAP = 32,

    SPEEDOMETER_MIN_ANGLE = -120,
    SPEEDOMETER_MAX_ANGLE = 120,
    SPEEDOMETER_WORLD_SPEED_WEIGHT = 0.70,
    SPEEDOMETER_FAST_MODE_BOOST = 0.15,
    SPEEDOMETER_DASH_BOOST = 0.30,
    SPEEDOMETER_NEEDLE_INTERPOLATION_SPEED = 0.18,

    DIEGETIC_DASH_CHEVRON_COUNT = 3,
    DIEGETIC_DASH_FRONT_DISTANCE = 35,
    DIEGETIC_DASH_CHEVRON_SPACING = 6,
    DIEGETIC_DASH_CHEVRON_HALF_WIDTH = 4,
    DIEGETIC_DASH_LINE_WIDTH = 2,
    DIEGETIC_DASH_BACKGROUND_HALF_LENGTH = 5,
    DIEGETIC_DASH_BACKGROUND_HALF_WIDTH = 5,
    DIEGETIC_SHRINK_ARC_SEGMENT_COUNT = 16,
    DIEGETIC_SHRINK_ARC_MAJOR_RADIUS = 30,
    DIEGETIC_SHRINK_ARC_MINOR_RADIUS = 20,
    DIEGETIC_SHRINK_ARC_END_INSET_DEGREES = 40,
    DIEGETIC_SHRINK_ARC_BACKGROUND_LINE_WIDTH = 5,
    DIEGETIC_SHRINK_ARC_LINE_WIDTH = 3,
    DIEGETIC_SHIELD_STARBOARD_DISTANCE = 35,
    DIEGETIC_SHIELD_ICON_SPACING = 25,
    DIEGETIC_SHIELD_FULL_ICON_SPACING = 28,
    DIEGETIC_SHIELD_ICON_SCALE = 0.55,
    DIEGETIC_SHIELD_FULL_CENTER_ICON_SCALE = 0.75,
    DIEGETIC_SHIELD_IMAGE_Y_OFFSET = 1,
    DIEGETIC_SHIELD_RING_GAP = 2,
    DIEGETIC_SHIELD_RING_SPACING = 3,

    MAX_ROCKS = 10,
    INTERACTIVE_SPAWN_PADDING = 4,
    INTERACTIVE_SPAWN_ATTEMPTS = 200,
    ROCK_SPAWN_MINIMUM_X = -600,
    COLLECTABLE_SPAWN_MINIMUM_X = -160,
    DECORATION_SPAWN_MINIMUM_X = -300,
    -- Once this speed is reached, decoration spawning stays disabled until restart.
    DECORATION_STOP_SPAWN_WORLD_VELOCITY = 4,
    WORLD_SPAWN_MAXIMUM_Y = 240,
    WORLD_SPAWN_MINIMUM_Y = 35,

    ROCK_Z_INDEX = 0,
    DECORATION_Z_INDEX = -10,
    ROCK_EXPLOSION_Z_INDEX = 10,
    COLLECTABLE_Z_INDEX = 20,
    PLAYER_Z_INDEX = 30,
    MAIN_MENU_Z_INDEX = -900,

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
    MAX_SHIELD_HITS = 10,
    SHRINK_DURATION_MS_BY_LEVEL = { 5000, 7000, 10000, 15000 },
    SHRINK_UI_FILL_DURATION_MS = 250,
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
