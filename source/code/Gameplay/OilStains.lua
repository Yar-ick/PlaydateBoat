local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local tuning = nil
local interactableObjectGroups = nil
local cleanSoundPlayers = {}
local cleanSoundPlayerCursor = 1
local cleanedCallback = nil
local circleImages = {}
local stains = {}
local spawnRemainingMilliseconds = 0
local running = false
local pendingScoreValue = 0
local pendingScoreDelayMilliseconds = 0
local pendingScoreX = 0
local pendingScoreY = 0

-- A dense horizontal core with a few short tapered offshoots. Positions are
-- fractions of the configured spread so the stain bounds remain tunable.
local stainCircleLayout <const> = {
    { x = 0, y = 0, radius = 1 },
    { x = -0.35, y = -0.05, radius = 0.9 },
    { x = 0.35, y = 0.05, radius = 0.9 },
    { x = -0.65, y = 0.08, radius = 0.78 },
    { x = 0.65, y = -0.08, radius = 0.78 },
    { x = -0.18, y = -0.58, radius = 0.75 },
    { x = 0.2, y = 0.58, radius = 0.75 },
    { x = -0.82, y = -0.5, radius = 0.55 },
    { x = -1, y = -1, radius = 0 },
    { x = 0.82, y = 0.5, radius = 0.55 },
    { x = 1, y = 0.95, radius = 0 },
    { x = 0.3, y = -1, radius = 0.45 },
    { x = -0.48, y = 0.48, radius = 0.58 },
    { x = 0.48, y = -0.48, radius = 0.58 },
    { x = -0.08, y = 0.92, radius = 0.48 },
    { x = -0.55, y = -0.82, radius = 0.4 },
    { x = 0.62, y = 0.82, radius = 0.4 },
    { x = -0.88, y = 0.55, radius = 0.32 }
}

OilStains = {}

local function smoothstep(progress)
    progress = math.max(0, math.min(1, progress))
    return progress * progress * (3 - 2 * progress)
end

local function makeCircleImage(radius)
    local size = radius * 2 + 2
    local image = pdg.image.new(size, size)

    pdg.pushContext(image)
    pdg.setColor(pdg.kColorBlack)
    pdg.fillCircleAtPoint(radius + 1, radius + 1, radius)
    pdg.popContext()

    return image, size
end

local function resetSpawnCountdown()
    spawnRemainingMilliseconds = math.random(
        tuning.OTHER_SIDE_OIL_MINIMUM_SPAWN_INTERVAL_MS,
        tuning.OTHER_SIDE_OIL_MAXIMUM_SPAWN_INTERVAL_MS
    )
end

local function deactivate(stain)
    stain.active = false
    stain.isAppearing = false
    stain.appearElapsedMilliseconds = 0

    for index = 1, #stain.circles do
        local circle = stain.circles[index]
        circle.active = false
        circle.isCleaning = false
        circle.cleanElapsedMilliseconds = 0
        circle:setScale(1)
        circle:setVisible(false)

        if circle.oilAdded then
            circle:remove()
            circle.oilAdded = false
        end
    end
end

local function moveStain(stain, displacement)
    stain.x += displacement

    for index = 1, #stain.circles do
        local circle = stain.circles[index]

        if circle.active then
            circle:moveBy(displacement, 0)
        end
    end
end

local function playCleanSound()
    local soundPlayer = cleanSoundPlayers[cleanSoundPlayerCursor]
    cleanSoundPlayerCursor = cleanSoundPlayerCursor % #cleanSoundPlayers + 1

    if soundPlayer:isPlaying() then
        soundPlayer:stop()
    end

    soundPlayer:setOffset(0)
    soundPlayer:play()
end

local function queueCleanScore(x, y)
    pendingScoreValue += tuning.OTHER_SIDE_OIL_SCORE
    pendingScoreDelayMilliseconds = tuning.OTHER_SIDE_OIL_SCORE_DELAY_MS
    pendingScoreX = x
    pendingScoreY = y
end

local function updatePendingScore(elapsedMilliseconds)
    if pendingScoreValue <= 0 then
        return
    end

    pendingScoreDelayMilliseconds = math.max(
        0,
        pendingScoreDelayMilliseconds - elapsedMilliseconds
    )

    if pendingScoreDelayMilliseconds == 0 then
        if cleanedCallback ~= nil then
            cleanedCallback(pendingScoreX, pendingScoreY, pendingScoreValue)
        end

        pendingScoreValue = 0
    end
end

local function findInactiveStain()
    for index = 1, #stains do
        if stains[index].active == false then
            return stains[index]
        end
    end

    return nil
end

local function activateStain(stain, x, y, shouldAnimateAppearance)
    local activeCircleCount = math.random(
        tuning.OTHER_SIDE_OIL_MINIMUM_CIRCLES_PER_STAIN,
        tuning.OTHER_SIDE_OIL_MAXIMUM_CIRCLES_PER_STAIN
    )
    local flipX = math.random(0, 1) == 0 and -1 or 1
    local flipY = math.random(0, 1) == 0 and -1 or 1
    stain.x = x
    stain.y = y
    stain.active = true
    stain.isAppearing = shouldAnimateAppearance == true
    stain.appearElapsedMilliseconds = 0

    for index = 1, activeCircleCount do
        local circle = stain.circles[index]

        local layout = stainCircleLayout[index]
            or stainCircleLayout[(index - 1) % #stainCircleLayout + 1]
        local radiusRange = tuning.OTHER_SIDE_OIL_MAXIMUM_RADIUS
            - tuning.OTHER_SIDE_OIL_MINIMUM_RADIUS
        local radius = math.floor(
            tuning.OTHER_SIDE_OIL_MINIMUM_RADIUS
                + radiusRange * layout.radius
                + 0.5
        )
        local offsetX = layout.x * tuning.OTHER_SIDE_OIL_SPREAD_X * flipX
        local offsetY = layout.y * tuning.OTHER_SIDE_OIL_SPREAD_Y * flipY

        -- Tiny variations keep repeated stains organic without breaking the
        -- overlapping silhouette of the core and branches.
        if index > 1 then
            offsetX += math.random(-2, 2)
            offsetY += math.random(-2, 2)
            radius = math.max(
                tuning.OTHER_SIDE_OIL_MINIMUM_RADIUS,
                math.min(tuning.OTHER_SIDE_OIL_MAXIMUM_RADIUS,
                    radius + math.random(-1, 1))
            )
        end

        local imageData = circleImages[radius]
        circle.radius = radius
        circle.stainOffsetX = offsetX
        circle.stainOffsetY = offsetY
        circle.imageWidth = imageData.size
        circle.imageHeight = imageData.size
        circle.active = true
        circle.isCleaning = false
        circle.cleanElapsedMilliseconds = 0
        circle:setImage(imageData.image)
        circle:setScale(stain.isAppearing and 0 or 1)
        circle:setCollideRect(0, 0, imageData.size, imageData.size)
        circle:moveTo(
            stain.isAppearing and x or x + offsetX,
            stain.isAppearing and y or y + offsetY
        )
        if circle.oilAdded == false then
            circle:add()
            circle.oilAdded = true
        end
        circle:setVisible(true)
    end
end

local function spawnAtAvailableStain(x, y, shouldAnimateAppearance)
    local stain = findInactiveStain()

    if stain == nil then
        return false
    end

    activateStain(stain, x, y, shouldAnimateAppearance)
    return true
end

local function spawnWorldStain()
    local stain = findInactiveStain()

    if stain == nil then
        return false
    end

    local x, y = InteractiveSpawn.findPosition(
        interactableObjectGroups,
        stain,
        stain.imageWidth,
        stain.imageHeight,
        tuning.OTHER_SIDE_OIL_SPAWN_MINIMUM_X,
        -stain.imageWidth / 2,
        tuning.WORLD_SPAWN_MINIMUM_Y + stain.imageHeight / 2,
        tuning.WORLD_SPAWN_MAXIMUM_Y - stain.imageHeight / 2,
        tuning.INTERACTIVE_SPAWN_PADDING,
        tuning.INTERACTIVE_SPAWN_ATTEMPTS
    )

    if x == nil then
        return false
    end

    activateStain(stain, x, y, false)
    return true
end

function OilStains.initialize(
    gameplayTuning,
    sfxChannel,
    objectGroups,
    onCleaned
)
    tuning = gameplayTuning
    interactableObjectGroups = objectGroups
    cleanedCallback = onCleaned
    for index = 1, tuning.OTHER_SIDE_OIL_CLEAN_SOUND_POOL_SIZE do
        local soundPlayer = pds.sampleplayer.new("sounds/OilClean")
        soundPlayer:setVolume(tuning.OTHER_SIDE_OIL_CLEAN_SOUND_VOLUME)
        sfxChannel:addSource(soundPlayer)
        cleanSoundPlayers[index] = soundPlayer
    end

    for radius = tuning.OTHER_SIDE_OIL_MINIMUM_RADIUS,
        tuning.OTHER_SIDE_OIL_MAXIMUM_RADIUS
    do
        local image, size = makeCircleImage(radius)
        circleImages[radius] = { image = image, size = size }
    end

    local initialRadius = tuning.OTHER_SIDE_OIL_MINIMUM_RADIUS
    local initialImage = circleImages[initialRadius]
    local stainWidth = tuning.OTHER_SIDE_OIL_MAXIMUM_RADIUS * 2
        + tuning.OTHER_SIDE_OIL_SPREAD_X * 2 + 2
    local stainHeight = tuning.OTHER_SIDE_OIL_MAXIMUM_RADIUS * 2
        + tuning.OTHER_SIDE_OIL_SPREAD_Y * 2 + 2

    for stainIndex = 1, tuning.OTHER_SIDE_OIL_STAIN_POOL_SIZE do
        local stain = {
            active = false,
            isAppearing = false,
            appearElapsedMilliseconds = 0,
            x = 0,
            y = 0,
            imageWidth = stainWidth,
            imageHeight = stainHeight,
            circles = {}
        }

        for circleIndex = 1,
            tuning.OTHER_SIDE_OIL_MAXIMUM_CIRCLES_PER_STAIN
        do
            local circle = pdg.sprite.new(initialImage.image)
            circle.objectType = "otherSideOil"
            circle.collisionResponse = pdg.sprite.kCollisionTypeOverlap
            circle.active = false
            circle.oilAdded = false
            circle.isCleaning = false
            circle.cleanElapsedMilliseconds = 0
            circle.stain = stain
            circle.radius = initialRadius
            circle.stainOffsetX = 0
            circle.stainOffsetY = 0
            circle.imageWidth = initialImage.size
            circle.imageHeight = initialImage.size
            circle:setCollideRect(0, 0, initialImage.size, initialImage.size)
            circle:setZIndex(tuning.OTHER_SIDE_OIL_Z_INDEX)
            circle:setVisible(false)
            stain.circles[circleIndex] = circle
        end

        stains[stainIndex] = stain
    end

    interactableObjectGroups[#interactableObjectGroups + 1] = stains
end

function OilStains.beginRun()
    running = true
    resetSpawnCountdown()
end

function OilStains.spawn(x, y)
    return spawnAtAvailableStain(x, y, true)
end

function OilStains.startCleaning(circle)
    local stain = circle and circle.stain

    if stain == nil
        or stain.active == false
        or stain.isAppearing
        or circle.active == false
        or circle.isCleaning
    then
        return false
    end

    circle.isCleaning = true
    circle.cleanElapsedMilliseconds = 0
    playCleanSound()
    return true
end

function OilStains.update(elapsedMilliseconds, worldDisplacement)
    for index = 1, #stains do
        local stain = stains[index]

        if stain.active then
            moveStain(stain, worldDisplacement)

            if stain.isAppearing then
                stain.appearElapsedMilliseconds += elapsedMilliseconds
                local progress = math.min(
                    stain.appearElapsedMilliseconds
                        / tuning.OTHER_SIDE_OIL_APPEAR_DURATION_MS,
                    1
                )
                local scale = smoothstep(progress)

                for circleIndex = 1, #stain.circles do
                    local circle = stain.circles[circleIndex]
                    circle:setScale(scale)
                    circle:moveTo(
                        stain.x + circle.stainOffsetX * scale,
                        stain.y + circle.stainOffsetY * scale
                    )
                end

                if progress >= 1 then
                    stain.isAppearing = false
                end
            else
                local activeCircleCount = 0

                for circleIndex = 1, #stain.circles do
                    local circle = stain.circles[circleIndex]

                    if circle.active then
                        if circle.isCleaning then
                            circle.cleanElapsedMilliseconds += elapsedMilliseconds
                            local progress = math.min(
                                circle.cleanElapsedMilliseconds
                                    / tuning.OTHER_SIDE_OIL_CLEAN_DURATION_MS,
                                1
                            )
                            circle:setScale(1 - smoothstep(progress))

                            if progress >= 1 then
                                local scoreX, scoreY = circle.x, circle.y
                                circle.active = false
                                circle.isCleaning = false
                                circle.cleanElapsedMilliseconds = 0
                                circle:setScale(1)
                                circle:setVisible(false)
                                circle:remove()
                                circle.oilAdded = false

                                queueCleanScore(scoreX, scoreY)
                            else
                                activeCircleCount += 1
                            end
                        else
                            activeCircleCount += 1
                        end
                    end
                end

                if activeCircleCount == 0 then
                    deactivate(stain)
                end
            end

            if stain.active and stain.x - stain.imageWidth / 2 > 400 then
                deactivate(stain)
            end
        end
    end

    updatePendingScore(elapsedMilliseconds)

    if running == false then
        return
    end

    spawnRemainingMilliseconds -= elapsedMilliseconds

    if spawnRemainingMilliseconds <= 0 then
        resetSpawnCountdown()

        if math.random(100) <= tuning.OTHER_SIDE_OIL_SPAWN_CHANCE_PERCENT then
            spawnWorldStain()
        end
    end
end

function OilStains.rewind(displacement)
    for index = 1, #stains do
        local stain = stains[index]

        if stain.active then
            moveStain(stain, displacement)

            if stain.x + stain.imageWidth / 2 < 0 then
                deactivate(stain)
            end
        end
    end
end

function OilStains.stopSounds()
    for index = 1, #cleanSoundPlayers do
        if cleanSoundPlayers[index]:isPlaying() then
            cleanSoundPlayers[index]:stop()
        end
    end
end

function OilStains.reset()
    running = false
    spawnRemainingMilliseconds = 0
    cleanSoundPlayerCursor = 1
    pendingScoreValue = 0
    pendingScoreDelayMilliseconds = 0
    pendingScoreX = 0
    pendingScoreY = 0
    OilStains.stopSounds()

    for index = 1, #stains do
        deactivate(stains[index])
    end
end
