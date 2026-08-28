local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local whirlpoolImage = pdg.image.new("images/Whirlpool")
local tuning = nil
local spawnConfig = nil
local reservation = nil
local objectGroups = nil
local attractionSoundPlayer = nil
local escapeSoundPlayer = nil
local whirlpoolRotationImages = {}
local whirlpoolRotationAngle = 0
local whirlpoolRotationFrame = 1
local whirlpoolImageWidth = 0
local whirlpoolImageHeight = 0
local state = "disabled"
local spawnRemainingMilliseconds = 0
local x = 0
local y = 0
local fastEscapeElapsedMilliseconds = 0
local attracting = false
local escaped = false
local captureElapsedMilliseconds = 0
local capturing = false
local captureComplete = false

Whirlpool = {}

local function cacheRotationImages()
    local frameCount = math.max(1, math.floor(tuning.WHIRLPOOL_ROTATION_FRAME_COUNT))
    local angleStep = 360 / frameCount

    whirlpoolRotationImages[1] = whirlpoolImage

    for frameIndex = 2, frameCount do
        whirlpoolRotationImages[frameIndex] = whirlpoolImage:rotatedImage(
            (frameIndex - 1) * angleStep
        )
    end
end

local function resetRotation()
    whirlpoolRotationAngle = 0
    whirlpoolRotationFrame = 1
end

local function updateRotation(elapsedMilliseconds)
    local frameCount = #whirlpoolRotationImages
    local angleStep = 360 / frameCount

    whirlpoolRotationAngle = (
        whirlpoolRotationAngle
        - tuning.WHIRLPOOL_ROTATION_DEGREES_PER_SECOND * elapsedMilliseconds / 1000
    ) % 360
    whirlpoolRotationFrame = math.floor(
        whirlpoolRotationAngle / angleStep + 0.5
    ) % frameCount + 1
end

local function stopSound(soundPlayer)
    if soundPlayer ~= nil and soundPlayer:isPlaying() then
        soundPlayer:stop()
    end
end

local function startAttractionSound()
    if attractionSoundPlayer:isPlaying() == false then
        attractionSoundPlayer:setOffset(0)
        attractionSoundPlayer:setRate(tuning.WHIRLPOOL_ATTRACTION_SOUND_RATE)
        attractionSoundPlayer:setVolume(tuning.WHIRLPOOL_ATTRACTION_SOUND_VOLUME)
        attractionSoundPlayer:play(0)
    end
end

local function isVisible()
    return state == "active"
        and x + whirlpoolImageWidth / 2 >= 0
        and x - whirlpoolImageWidth / 2 <= 400
end

local function updateAttractionSound()
    if isVisible() then
        startAttractionSound()
    else
        stopSound(attractionSoundPlayer)
    end
end

local function resetCapture()
    captureElapsedMilliseconds = 0
    capturing = false
    captureComplete = false
end

local function stopAttraction()
    attracting = false
    fastEscapeElapsedMilliseconds = 0
    resetCapture()
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

local function deactivate(resetCountdown)
    state = "idle"
    reservation.active = false
    escaped = false
    stopAttraction()
    stopSound(attractionSoundPlayer)

    if resetCountdown then
        resetSpawnCountdown()
    end

    WakeLayer.markDirty()
end

local function playEscapeSound()
    stopSound(escapeSoundPlayer)
    escapeSoundPlayer:setOffset(0)
    escapeSoundPlayer:setVolume(tuning.WHIRLPOOL_ESCAPE_SOUND_VOLUME)
    escapeSoundPlayer:play()
end

local function escape()
    if state ~= "active" or escaped then
        return false
    end

    escaped = true
    stopAttraction()
    playEscapeSound()
    return true
end

local function isWithinEscapeRadius(playerX, playerY)
    if state ~= "active" or escaped then
        return false
    end

    local deltaX = x - playerX
    local deltaY = y - playerY
    return deltaX * deltaX + deltaY * deltaY
        <= tuning.WHIRLPOOL_ESCAPE_RADIUS * tuning.WHIRLPOOL_ESCAPE_RADIUS
end

local function trySpawn()
    if math.random() * 100 > spawnConfig.SPAWN_CHANCE_PERCENT then
        resetSpawnCountdown()
        return
    end

    local spawnX, spawnY = InteractiveSpawn.findPosition(
        objectGroups,
        reservation,
        reservation.imageWidth,
        reservation.imageHeight,
        tuning.WHIRLPOOL_SPAWN_MINIMUM_X,
        tuning.WHIRLPOOL_SPAWN_MAXIMUM_X,
        tuning.WHIRLPOOL_SPAWN_MINIMUM_Y,
        tuning.WHIRLPOOL_SPAWN_MAXIMUM_Y,
        tuning.INTERACTIVE_SPAWN_PADDING,
        tuning.INTERACTIVE_SPAWN_ATTEMPTS
    )

    if spawnX == nil then
        spawnRemainingMilliseconds = tuning.WHIRLPOOL_SPAWN_RETRY_INTERVAL_MS
        return
    end

    x = spawnX
    y = spawnY
    reservation.x = x
    reservation.y = y
    reservation.active = true
    fastEscapeElapsedMilliseconds = 0
    attracting = false
    escaped = false
    state = "active"
    resetRotation()
    WakeLayer.markDirty()
end

function Whirlpool.initialize(settings, sfxChannel, interactableGroups)
    tuning = settings
    objectGroups = interactableGroups
    attractionSoundPlayer = pds.sampleplayer.new("sounds/WhirlpoolAttraction")
    escapeSoundPlayer = pds.sampleplayer.new("sounds/WhirlpoolEscape")
    sfxChannel:addSource(attractionSoundPlayer)
    sfxChannel:addSource(escapeSoundPlayer)
    cacheRotationImages()
    whirlpoolImageWidth, whirlpoolImageHeight = whirlpoolImage:getSize()

    reservation = {
        active = false,
        x = 0,
        y = 0,
        imageWidth = tuning.WHIRLPOOL_SPAWN_RESERVATION_SIZE,
        imageHeight = tuning.WHIRLPOOL_SPAWN_RESERVATION_SIZE
    }
    objectGroups[#objectGroups + 1] = { reservation }

end

function Whirlpool.beginRun(difficultySpawnConfig)
    Whirlpool.reset()
    spawnConfig = difficultySpawnConfig
    state = "idle"
    resetSpawnCountdown()
end

function Whirlpool.update(elapsedMilliseconds, worldDisplacement)
    if state == "idle" then
        spawnRemainingMilliseconds -= elapsedMilliseconds

        if spawnRemainingMilliseconds <= 0 then
            trySpawn()
        end

        return
    end

    if state ~= "active" then
        return
    end

    updateRotation(elapsedMilliseconds)
    x += worldDisplacement
    reservation.x = x

    if x - whirlpoolImageWidth / 2 > 400 then
        deactivate(true)
        return
    end

    updateAttractionSound()
    WakeLayer.markDirty()
end

function Whirlpool.getAttraction(
    elapsedMilliseconds,
    playerX,
    playerY,
    isAirborne,
    isFastMode,
    dashSpeed,
    forceMultiplier,
    canCapture
)
    forceMultiplier = forceMultiplier or 1
    canCapture = canCapture ~= false
    if state ~= "active" or isAirborne then
        stopAttraction()
        return 0, 0
    end

    if isVisible() == false then
        stopAttraction()
        return 0, 0
    end

    local deltaX = x - playerX
    local deltaY = y - playerY
    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)

    if escaped then
        if distance <= tuning.WHIRLPOOL_ESCAPE_RADIUS then
            stopAttraction()
            return 0, 0
        end

        escaped = false
    end

    if distance > tuning.WHIRLPOOL_ATTRACTION_RADIUS then
        stopAttraction()
        return 0, 0
    end

    if attracting == false then
        attracting = true
    end

    local canEscape = distance <= tuning.WHIRLPOOL_ESCAPE_RADIUS

    if canEscape and dashSpeed >= tuning.WHIRLPOOL_DASH_ESCAPE_MINIMUM_SPEED then
        escape()
        return 0, 0
    end

    if isFastMode and canEscape then
        fastEscapeElapsedMilliseconds += elapsedMilliseconds

        if fastEscapeElapsedMilliseconds >= tuning.WHIRLPOOL_FAST_ESCAPE_HOLD_MS then
            escape()
            return 0, 0
        end
    else
        fastEscapeElapsedMilliseconds = 0
    end

    if canCapture and distance <= tuning.WHIRLPOOL_CAPTURE_RADIUS then
        capturing = true
        captureElapsedMilliseconds = math.min(
            tuning.WHIRLPOOL_CAPTURE_DURATION_MS,
            captureElapsedMilliseconds + elapsedMilliseconds
        )
        captureComplete = captureElapsedMilliseconds >= tuning.WHIRLPOOL_CAPTURE_DURATION_MS
    else
        resetCapture()
    end

    if distance <= 0.001 then
        return 0, 0
    end

    local directionX = deltaX / distance
    local directionY = deltaY / distance
    local proximity = 1 - math.min(distance / tuning.WHIRLPOOL_ATTRACTION_RADIUS, 1)
    local forceProgress = proximity ^ tuning.WHIRLPOOL_ATTRACTION_FORCE_POWER
    local radialForce = tuning.WHIRLPOOL_ATTRACTION_MINIMUM_FORCE
        + (tuning.WHIRLPOOL_ATTRACTION_MAXIMUM_FORCE
            - tuning.WHIRLPOOL_ATTRACTION_MINIMUM_FORCE) * forceProgress
    radialForce *= forceMultiplier
    local frameScale = elapsedMilliseconds / (1000 / 30)
    local pullDistance = math.min(radialForce * frameScale, distance)

    return directionX * pullDistance, directionY * pullDistance
end

function Whirlpool.isCapturing()
    return capturing
end

function Whirlpool.getCapturePosition()
    if capturing == false then
        return nil, nil
    end

    return x, y
end

function Whirlpool.getPlayerScale()
    if capturing == false then
        return 1
    end

    return math.max(
        0,
        1 - captureElapsedMilliseconds / tuning.WHIRLPOOL_CAPTURE_DURATION_MS
    )
end

function Whirlpool.isCaptureComplete()
    return captureComplete
end

function Whirlpool.onDash(playerX, playerY)
    if isWithinEscapeRadius(playerX, playerY) then
        escape()
    end
end

function Whirlpool.draw()
    if state ~= "active" then
        return
    end

    whirlpoolRotationImages[whirlpoolRotationFrame]:drawCentered(
        math.floor(x + 0.5),
        math.floor(y + 0.5)
    )
end

function Whirlpool.stopSounds()
    stopSound(attractionSoundPlayer)
    stopSound(escapeSoundPlayer)
end

function Whirlpool.resumeSounds()
    if isVisible() then
        startAttractionSound()
    end
end

function Whirlpool.rewind(displacement)
    Whirlpool.stopSounds()

    if state ~= "active" then
        state = "disabled"
        return 0
    end

    x += displacement
    reservation.x = x
    WakeLayer.markDirty()

    if x + whirlpoolImageWidth / 2 < 0 then
        state = "disabled"
        reservation.active = false
        return 0
    end

    return 1
end

function Whirlpool.reset()
    Whirlpool.stopSounds()
    spawnConfig = nil
    state = "disabled"
    spawnRemainingMilliseconds = 0
    fastEscapeElapsedMilliseconds = 0
    attracting = false
    escaped = false
    resetRotation()
    resetCapture()

    if reservation ~= nil then
        reservation.active = false
    end

    WakeLayer.markDirty()
end
