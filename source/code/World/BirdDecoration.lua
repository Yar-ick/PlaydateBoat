local pdg <const> = playdate.graphics

local birdImagetable <const> = pdg.imagetable.new("images/Bird")
local tuning = nil
local birds = {}
local spawnRemainingMilliseconds = 0
local running = false

BirdDecoration = {}

local function resetSpawnCountdown()
    spawnRemainingMilliseconds = math.random(
        tuning.BIRD_SPAWN_MINIMUM_INTERVAL_MS,
        tuning.BIRD_SPAWN_MAXIMUM_INTERVAL_MS
    )
end

local function deactivate(bird)
    bird.active = false
    bird:setVisible(false)
end

local function spawn()
    local bird = nil

    for index = 1, #birds do
        if birds[index].active == false then
            bird = birds[index]
            break
        end
    end

    if bird == nil then
        return false
    end

    bird.active = true
    bird.animationElapsedMilliseconds = 0
    bird.frameIndex = 1
    bird:setImage(birdImagetable:getImage(1))
    bird:moveTo(
        -bird.displayWidth / 2,
        math.random(tuning.BIRD_SPAWN_MINIMUM_Y, tuning.BIRD_SPAWN_MAXIMUM_Y)
    )
    bird:setVisible(true)
    return true
end

function BirdDecoration.initialize(gameplayTuning)
    tuning = gameplayTuning
    local imageWidth, imageHeight = birdImagetable:getImage(1):getSize()

    for index = 1, tuning.BIRD_POOL_SIZE do
        local bird = pdg.sprite.new(birdImagetable:getImage(1))
        bird.active = false
        bird.imageWidth = imageWidth
        bird.imageHeight = imageHeight
        bird.displayWidth = imageWidth * tuning.BIRD_SCALE
        bird.frameIndex = 1
        bird.animationElapsedMilliseconds = 0
        bird:setScale(tuning.BIRD_SCALE)
        bird:setZIndex(tuning.BIRD_Z_INDEX)
        bird:setVisible(false)
        bird:add()
        birds[index] = bird
    end

    resetSpawnCountdown()
end

function BirdDecoration.beginRun()
    BirdDecoration.reset()
    running = true
end

function BirdDecoration.update(
    elapsedMilliseconds,
    currentWorldVelocity,
    maximumWorldVelocity
)
    local speedProgress = math.max(
        0,
        math.min(
            1,
            (currentWorldVelocity - tuning.INITIAL_WORLD_VELOCITY)
                / math.max(
                    0.001,
                    maximumWorldVelocity - tuning.INITIAL_WORLD_VELOCITY
                )
        )
    )
    local speed = tuning.BIRD_MINIMUM_SPEED_PIXELS_PER_SECOND
        + (tuning.BIRD_MAXIMUM_SPEED_PIXELS_PER_SECOND
            - tuning.BIRD_MINIMUM_SPEED_PIXELS_PER_SECOND) * speedProgress
    local displacement = speed * elapsedMilliseconds / 1000

    for index = 1, #birds do
        local bird = birds[index]

        if bird.active then
            bird:moveBy(displacement, 0)
            bird.animationElapsedMilliseconds += elapsedMilliseconds
            local frameIndex = math.floor(
                bird.animationElapsedMilliseconds
                    / tuning.BIRD_ANIMATION_FRAME_DURATION_MS
            ) % birdImagetable:getLength() + 1

            if frameIndex ~= bird.frameIndex then
                bird.frameIndex = frameIndex
                bird:setImage(birdImagetable:getImage(frameIndex))
            end

            if bird.x - bird.displayWidth / 2 > 400 then
                deactivate(bird)
            end
        end
    end

    if running == false then
        return
    end

    spawnRemainingMilliseconds -= elapsedMilliseconds

    if spawnRemainingMilliseconds <= 0 then
        resetSpawnCountdown()
        spawn()
    end
end

function BirdDecoration.stopSpawning()
    running = false
end

function BirdDecoration.reset()
    running = false
    resetSpawnCountdown()

    for index = 1, #birds do
        deactivate(birds[index])
    end
end
