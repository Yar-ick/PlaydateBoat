local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local steamboatImagetable = pdg.imagetable.new("images/Steamboat")
local explosionImagetable = nil
local steamboatSprite = nil
local hornSoundPlayer = nil
local engineSoundPlayer = nil
local tuning = nil
local destroyRockCallback = nil
local spawnConfig = nil
local state = "disabled"
local spawnRemainingMilliseconds = 0
local activeElapsedMilliseconds = 0
local baseY = 0
local yAmplitude = 0
local yPeriodMilliseconds = 1
local yPhase = 0
local movementAngle = 90
local wakeLines = {}
local wakeLineCursor = 1
local wakeSpawnCounter = 0
local explosion = nil

Steamboat = {}

local function stopSound(soundPlayer)
    if soundPlayer ~= nil and soundPlayer:isPlaying() then
        soundPlayer:stop()
    end
end

local function playHorn()
    stopSound(hornSoundPlayer)
    hornSoundPlayer:setOffset(0)
    hornSoundPlayer:setVolume(tuning.STEAMBOAT_HORN_VOLUME)
    hornSoundPlayer:play()
end

local function startEngine()
    if engineSoundPlayer:isPlaying() == false then
        engineSoundPlayer:setOffset(0)
        engineSoundPlayer:setRate(tuning.STEAMBOAT_ENGINE_RATE)
        engineSoundPlayer:setVolume(tuning.STEAMBOAT_ENGINE_VOLUME)
        engineSoundPlayer:play(0)
    end
end

local function clearWakeLines()
    for index = 1, #wakeLines do
        wakeLines[index].active = false
    end

    wakeSpawnCounter = 0
    WakeLayer.markDirty()
end

local function resetSpawnCountdown()
    if spawnConfig == nil then
        spawnRemainingMilliseconds = 0
        return
    end

    spawnRemainingMilliseconds = math.random(
        spawnConfig.MINIMUM_INTERVAL_MS,
        spawnConfig.MAXIMUM_INTERVAL_MS
    )
end

local function removeExplosion()
    if explosion ~= nil then
        explosion.sprite:remove()
        explosion = nil
    end
end

local function updateExplosion(elapsedMilliseconds, worldDisplacement)
    if explosion == nil then
        return
    end

    explosion.sprite:moveBy(worldDisplacement, 0)
    explosion.elapsedMilliseconds += elapsedMilliseconds

    local frame = math.floor(
        explosion.elapsedMilliseconds / tuning.STEAMBOAT_EXPLOSION_FRAME_DELAY_MS
    ) + 1

    if frame > explosionImagetable:getLength() then
        removeExplosion()
    elseif frame ~= explosion.frame then
        explosion.frame = frame
        explosion.sprite:setImage(explosionImagetable:getImage(frame))
    end
end

local function startExplosion(x, y)
    removeExplosion()

    local sprite = pdg.sprite.new(explosionImagetable:getImage(1))
    sprite:setZIndex(tuning.STEAMBOAT_EXPLOSION_Z_INDEX)
    sprite:moveTo(x, y)
    sprite:add()

    explosion = {
        sprite = sprite,
        frame = 1,
        elapsedMilliseconds = 0
    }
end

local function spawnWakeLine(engineX, engineY, wakeAngle)
    local line = wakeLines[wakeLineCursor]
    wakeLineCursor = wakeLineCursor % #wakeLines + 1

    local angle = wakeAngle + math.random(
        -tuning.STEAMBOAT_WAKE_ANGLE_SPREAD_DEGREES,
        tuning.STEAMBOAT_WAKE_ANGLE_SPREAD_DEGREES
    )
    local perpendicularAngle = angle + 90
    local sideOffset = math.random(
        -tuning.STEAMBOAT_WAKE_SIDE_OFFSET,
        tuning.STEAMBOAT_WAKE_SIDE_OFFSET
    )

    line.active = true
    line.x = engineX + math.sin(math.rad(perpendicularAngle)) * sideOffset
    line.y = engineY - math.cos(math.rad(perpendicularAngle)) * sideOffset
    line.dx = math.sin(math.rad(angle))
    line.dy = -math.cos(math.rad(angle))
    line.speed = math.random(
        tuning.STEAMBOAT_WAKE_MINIMUM_SPEED_TENTHS,
        tuning.STEAMBOAT_WAKE_MAXIMUM_SPEED_TENTHS
    ) / 10
    line.length = math.random(
        tuning.STEAMBOAT_WAKE_MINIMUM_LENGTH,
        tuning.STEAMBOAT_WAKE_MAXIMUM_LENGTH
    )
    line.width = math.random(
        tuning.STEAMBOAT_WAKE_MINIMUM_WIDTH,
        tuning.STEAMBOAT_WAKE_MAXIMUM_WIDTH
    )
    line.age = 0
    line.lifetime = math.random(
        tuning.STEAMBOAT_WAKE_MINIMUM_LIFETIME_FRAMES,
        tuning.STEAMBOAT_WAKE_MAXIMUM_LIFETIME_FRAMES
    )
end

local function updateWakeLines(worldDisplacement, applyWakeVelocity)
    for index = 1, #wakeLines do
        local line = wakeLines[index]

        if line.active then
            line.x += worldDisplacement

            if applyWakeVelocity then
                line.x += line.dx * line.speed
                line.y += line.dy * line.speed
            end

            line.age += 1
            if line.age >= line.lifetime then
                line.active = false
            end
        end
    end

    WakeLayer.markDirty()
end

local function emitWake()
    wakeSpawnCounter += 1
    if wakeSpawnCounter < tuning.STEAMBOAT_WAKE_SPAWN_INTERVAL_FRAMES then
        return
    end

    local wakeAngle = math.normalizeAngle(movementAngle + 180)
    local engineX = steamboatSprite.x
        + math.sin(math.rad(wakeAngle)) * tuning.STEAMBOAT_WAKE_ENGINE_DISTANCE
    local engineY = steamboatSprite.y
        - math.cos(math.rad(wakeAngle)) * tuning.STEAMBOAT_WAKE_ENGINE_DISTANCE

    for _ = 1, tuning.STEAMBOAT_WAKE_SPAWN_COUNT do
        spawnWakeLine(engineX, engineY, wakeAngle)
    end

    wakeSpawnCounter = 0
end

local function makeInactive(shouldScheduleNext)
    steamboatSprite.active = false
    steamboatSprite:setVisible(false)
    stopSound(engineSoundPlayer)

    if shouldScheduleNext and spawnConfig ~= nil then
        state = "idle"
        resetSpawnCountdown()
    else
        state = "disabled"
    end
end

local function spawn()
    stopSound(hornSoundPlayer)
    activeElapsedMilliseconds = 0
    yAmplitude = math.random(
        tuning.STEAMBOAT_MINIMUM_Y_AMPLITUDE,
        tuning.STEAMBOAT_MAXIMUM_Y_AMPLITUDE
    )
    yPeriodMilliseconds = math.random(
        tuning.STEAMBOAT_MINIMUM_Y_PERIOD_MS,
        tuning.STEAMBOAT_MAXIMUM_Y_PERIOD_MS
    )
    yPhase = math.random() * math.pi * 2
    baseY = math.random(
        tuning.STEAMBOAT_MINIMUM_BASE_Y + yAmplitude,
        tuning.STEAMBOAT_MAXIMUM_BASE_Y - yAmplitude
    )
    movementAngle = 90
    steamboatSprite:setImage(steamboatImagetable:getImage(12))
    steamboatSprite:moveTo(
        tuning.STEAMBOAT_SPAWN_X,
        baseY + math.sin(yPhase) * yAmplitude
    )
    steamboatSprite.active = true
    steamboatSprite:setVisible(true)
    state = "active"
    startEngine()
end

local function updateActive(elapsedMilliseconds, worldDisplacement, rocks)
    local previousX = steamboatSprite.x
    local previousY = steamboatSprite.y
    activeElapsedMilliseconds += elapsedMilliseconds

    local y = baseY + math.sin(
        yPhase + activeElapsedMilliseconds * math.pi * 2 / yPeriodMilliseconds
    ) * yAmplitude
    local x = previousX
        + worldDisplacement
        + tuning.STEAMBOAT_HORIZONTAL_SPEED_PIXELS_PER_SECOND
            * elapsedMilliseconds / 1000
    local movementX = x - previousX
    local movementY = y - previousY

    movementAngle = math.normalizeAngle(
        math.deg(math.atan2(movementY, movementX)) + 90
    )
    local frame = math.clamp(
        math.ceil(movementAngle / (360 / steamboatImagetable:getLength())),
        1,
        steamboatImagetable:getLength()
    )

    steamboatSprite:setImage(steamboatImagetable:getImage(frame))
    steamboatSprite:moveTo(x, y)
    emitWake()

    for index = 1, #rocks do
        local rock = rocks[index]

        if rock.active and steamboatSprite:alphaCollision(rock) then
            destroyRockCallback(rock)
        end
    end

    if steamboatSprite.x - steamboatSprite.imageWidth / 2 > 400 then
        makeInactive(true)
    end
end

function Steamboat.initialize(settings, sfxChannel, onDestroyRock, sharedExplosionImagetable)
    tuning = settings
    destroyRockCallback = onDestroyRock
    explosionImagetable = sharedExplosionImagetable
    hornSoundPlayer = pds.sampleplayer.new("sounds/ShipHorn")
    engineSoundPlayer = pds.sampleplayer.new("sounds/BoatEngine")
    sfxChannel:addSource(hornSoundPlayer)
    sfxChannel:addSource(engineSoundPlayer)

    steamboatSprite = pdg.sprite.new(steamboatImagetable:getImage(1))
    steamboatSprite.imageWidth, steamboatSprite.imageHeight =
        steamboatImagetable:getImage(1):getSize()
    steamboatSprite.objectType = "steamboat"
    steamboatSprite.active = false
    steamboatSprite.collisionResponse = pdg.sprite.kCollisionTypeOverlap
    steamboatSprite:setCollideRect(
        0,
        0,
        steamboatSprite.imageWidth,
        steamboatSprite.imageHeight
    )
    steamboatSprite:setZIndex(tuning.STEAMBOAT_Z_INDEX)
    steamboatSprite:setVisible(false)
    steamboatSprite:add()

    for index = 1, tuning.STEAMBOAT_WAKE_POOL_SIZE do
        wakeLines[index] = { active = false }
    end
end

function Steamboat.beginRun(difficultySpawnConfig)
    Steamboat.reset()
    spawnConfig = difficultySpawnConfig
    state = "idle"
    resetSpawnCountdown()
end

function Steamboat.update(elapsedMilliseconds, worldDisplacement, rocks)
    updateWakeLines(worldDisplacement, true)
    updateExplosion(elapsedMilliseconds, worldDisplacement)

    if state == "idle" then
        spawnRemainingMilliseconds -= elapsedMilliseconds

        if spawnRemainingMilliseconds <= 0 then
            if math.random() * 100 <= spawnConfig.SPAWN_CHANCE_PERCENT then
                state = "warning"
                activeElapsedMilliseconds = 0
                playHorn()
            else
                resetSpawnCountdown()
            end
        end
    elseif state == "warning" then
        activeElapsedMilliseconds += elapsedMilliseconds

        if activeElapsedMilliseconds >= tuning.STEAMBOAT_WARNING_DURATION_MS then
            spawn()
        end
    elseif state == "active" then
        updateActive(elapsedMilliseconds, worldDisplacement, rocks)
    end
end

function Steamboat.explode()
    if steamboatSprite.active == false then
        return false
    end

    local x, y = steamboatSprite.x, steamboatSprite.y
    makeInactive(true)
    startExplosion(x, y)
    return true
end

function Steamboat.rewind(elapsedMilliseconds, displacement)
    stopSound(hornSoundPlayer)
    stopSound(engineSoundPlayer)
    updateWakeLines(displacement, false)
    updateExplosion(elapsedMilliseconds, displacement)

    if state == "warning" or state == "idle" then
        state = "disabled"
    end

    if steamboatSprite.active then
        steamboatSprite:moveBy(displacement, 0)

        if steamboatSprite.x + steamboatSprite.imageWidth / 2 < 0 then
            makeInactive(false)
            return 0
        end

        return 1
    end

    return 0
end

function Steamboat.drawWakeLines()
    for index = 1, #wakeLines do
        local line = wakeLines[index]

        if line.active then
            local lifeProgress = line.age / line.lifetime
            local length = line.length * (1 - lifeProgress)
            local width = line.width

            if lifeProgress > 0.65 then
                width = 1
            end

            pdg.setLineWidth(width)
            pdg.drawLine(
                line.x,
                line.y,
                line.x + line.dx * length,
                line.y + line.dy * length
            )
        end
    end
end

function Steamboat.stopSounds()
    stopSound(hornSoundPlayer)
    stopSound(engineSoundPlayer)
end

function Steamboat.resumeSounds()
    if state == "warning" and hornSoundPlayer:isPlaying() == false then
        playHorn()
    elseif state == "active" then
        startEngine()
    end
end

function Steamboat.reset()
    Steamboat.stopSounds()
    spawnConfig = nil
    state = "disabled"
    spawnRemainingMilliseconds = 0
    activeElapsedMilliseconds = 0
    removeExplosion()
    clearWakeLines()

    if steamboatSprite ~= nil then
        steamboatSprite.active = false
        steamboatSprite:setVisible(false)
    end
end
