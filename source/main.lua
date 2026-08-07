import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank"
import "CoreLibs/animation"
import "CoreLibs/object"
import "CoreLibs/sprites"
import "GameplayTuning"
import "Collectable"
import "CoinCollectable"
import "ShieldCollectable"
import "ShrinkCollectable"
import "SpeedReductionCollectable"
import "InteractiveSpawn"
import "DecorationManager"

-- Localizing commonly used globals
local pd <const> = playdate
local pdg <const> = playdate.graphics
local pds <const> = playdate.sound
local TUNING <const> = GameplayTuning

function math.clamp(val, lower, upper)
    return math.max(lower, math.min(upper, val))
end

function math.normalizeAngle(angle)
    return angle % 360
end

local secondsSinceEpoch = pd.getSecondsSinceEpoch()
math.randomseed(secondsSinceEpoch)

local GameState = {
    ALIVE = 1,
    CRASHED = 2
}

local BoatGameState = GameState.ALIVE
local lastUpdateTimeMilliseconds = pd.getCurrentTimeMilliseconds()

local playerImagetable = pdg.imagetable.new("images/Boat")
local playerImagetableSize = playerImagetable:getLength()
local explosionImagetable = pdg.imagetable.new("images/Explosion")
local rockExplosionImagetable = pdg.imagetable.new("images/RockExplosion")
local backgroundHUDImage = pdg.image.new("images/BackgroundHUD")
local speedometerImage = pdg.image.new("images/Speedometer")
local speedometerNeedleImage = pdg.image.new("images/SpeedometerNeedle")
local coinImagetable = pdg.imagetable.new("images/Coin")
local starImage = pdg.image.new("images/Star")
local shieldImage = pdg.image.new("images/Shield")
local shrinkImage = pdg.image.new("images/Srink")
local speedReductionImage = pdg.image.new("images/SpeedReduction")
local dashImage = pdg.image.new("images/Dash")
local shieldCollectableImage = pdg.image.new("images/ShieldNoFrame")
local shrinkCollectableImage = pdg.image.new("images/SrinkNoFrame")
local speedReductionCollectableImage = pdg.image.new("images/SpeedReductionNoFrame")
local coinPickupSoundPlayer = pds.sampleplayer.new("sounds/CoinPickup")
local dashSoundPlayer = pds.sampleplayer.new("sounds/Dash")
local shrinkSoundPlayer = pds.sampleplayer.new("sounds/Shrink")
local shieldSoundPlayer = pds.sampleplayer.new("sounds/Shield")
local speedReductionSoundPlayer = pds.sampleplayer.new("sounds/SpeedReduction")
local boatExplosionSoundPlayer = pds.sampleplayer.new("sounds/BoatExplosion")
local boatEngineSoundPlayer = pds.sampleplayer.new("sounds/BoatEngine")
local boatEngineSoundRate = TUNING.ENGINE_MIN_WORLD_RATE
local boatEngineSoundVolume = TUNING.ENGINE_NORMAL_VOLUME
local waterFlowSoundPlayer = pds.sampleplayer.new("sounds/WaterFlow")
local waterFlowSoundRate = TUNING.WATER_FLOW_MIN_RATE
local gameMusicPlayer = pds.fileplayer.new("sounds/Banners in the Wind")
local gameMusicRate = TUNING.MUSIC_NORMAL_RATE
local sfxChannel = pds.channel.new()
local musicChannel = pds.channel.new()
local rockExplosionSoundPlayers = {}
local rockExplosionSoundPlayerCursor = 1

sfxChannel:addSource(coinPickupSoundPlayer)
sfxChannel:addSource(dashSoundPlayer)
sfxChannel:addSource(shrinkSoundPlayer)
sfxChannel:addSource(shieldSoundPlayer)
sfxChannel:addSource(speedReductionSoundPlayer)
sfxChannel:addSource(boatExplosionSoundPlayer)
sfxChannel:addSource(boatEngineSoundPlayer)
sfxChannel:addSource(waterFlowSoundPlayer)
musicChannel:addSource(gameMusicPlayer)

for i = 1, 4 do
    rockExplosionSoundPlayers[i] = pds.sampleplayer.new("sounds/RockExplosion")
    sfxChannel:addSource(rockExplosionSoundPlayers[i])
end

local function playSoundOneShot(soundPlayer)
    if soundPlayer:isPlaying() then
        soundPlayer:stop()
    end

    soundPlayer:setOffset(0)
    soundPlayer:play()
end

local function playRockExplosionSound()
    local soundPlayer = rockExplosionSoundPlayers[rockExplosionSoundPlayerCursor]
    rockExplosionSoundPlayerCursor = rockExplosionSoundPlayerCursor % #rockExplosionSoundPlayers + 1
    playSoundOneShot(soundPlayer)
end

local function startBoatEngineSound()
    if boatEngineSoundPlayer:isPlaying() == false then
        boatEngineSoundPlayer:setOffset(0)
        boatEngineSoundPlayer:setRate(boatEngineSoundRate)
        boatEngineSoundPlayer:setVolume(boatEngineSoundVolume)
        boatEngineSoundPlayer:play(0)
    end
end

local function stopBoatEngineSound()
    if boatEngineSoundPlayer:isPlaying() then
        boatEngineSoundPlayer:stop()
    end
end

local function updateBoatEngineSound(isFast, isShrunk, currentWorldVelocity)
    local velocityRange = TUNING.MAX_WORLD_VELOCITY - TUNING.INITIAL_WORLD_VELOCITY
    local velocityProgress = 0
    if velocityRange > 0 then
        velocityProgress = math.clamp(
            (currentWorldVelocity - TUNING.INITIAL_WORLD_VELOCITY) / velocityRange,
            0,
            1
        )
    end

    local targetRate = TUNING.ENGINE_MIN_WORLD_RATE
        + (TUNING.ENGINE_MAX_WORLD_RATE - TUNING.ENGINE_MIN_WORLD_RATE) * velocityProgress
    if isFast then
        targetRate *= TUNING.ENGINE_FAST_RATE_MULTIPLIER
    end
    if isShrunk then
        targetRate *= TUNING.ENGINE_SHRINK_RATE_MULTIPLIER
    end
    targetRate = math.min(targetRate, TUNING.ENGINE_MAX_RATE)
    local targetVolume = isFast and TUNING.ENGINE_FAST_VOLUME or TUNING.ENGINE_NORMAL_VOLUME

    boatEngineSoundRate +=
        (targetRate - boatEngineSoundRate) * TUNING.ENGINE_SOUND_INTERPOLATION_SPEED
    boatEngineSoundVolume +=
        (targetVolume - boatEngineSoundVolume) * TUNING.ENGINE_SOUND_INTERPOLATION_SPEED
    boatEngineSoundPlayer:setRate(boatEngineSoundRate)
    boatEngineSoundPlayer:setVolume(boatEngineSoundVolume)
end

local function startWaterFlowSound()
    if waterFlowSoundPlayer:isPlaying() == false then
        waterFlowSoundPlayer:setOffset(0)
        waterFlowSoundPlayer:setRate(waterFlowSoundRate)
        waterFlowSoundPlayer:setVolume(TUNING.WATER_FLOW_VOLUME)
        waterFlowSoundPlayer:play(0)
    end
end

local function stopWaterFlowSound()
    if waterFlowSoundPlayer:isPlaying() then
        waterFlowSoundPlayer:stop()
    end
end

local function updateWaterFlowSound(currentWorldVelocity)
    local velocityProgress = math.clamp(
        (currentWorldVelocity - TUNING.MIN_WORLD_VELOCITY)
            / (TUNING.MAX_WORLD_VELOCITY - TUNING.MIN_WORLD_VELOCITY),
        0,
        1
    )
    local targetRate = TUNING.WATER_FLOW_MIN_RATE
        + (TUNING.WATER_FLOW_MAX_RATE - TUNING.WATER_FLOW_MIN_RATE) * velocityProgress

    waterFlowSoundRate +=
        (targetRate - waterFlowSoundRate) * TUNING.WATER_FLOW_RATE_INTERPOLATION_SPEED
    waterFlowSoundPlayer:setRate(waterFlowSoundRate)
end

local function startGameMusic()
    if gameMusicPlayer:isPlaying() == false then
        gameMusicPlayer:setRate(gameMusicRate)
        gameMusicPlayer:setVolume(TUNING.MUSIC_VOLUME)
        gameMusicPlayer:play(0)
    end
end

local function pauseGameMusic()
    if gameMusicPlayer:isPlaying() then
        gameMusicPlayer:pause()
    end
end

local function updateGameMusic(currentWorldVelocity)
    local velocityProgress = math.clamp(
        (currentWorldVelocity - TUNING.INITIAL_WORLD_VELOCITY)
            / (TUNING.MAX_WORLD_VELOCITY - TUNING.INITIAL_WORLD_VELOCITY),
        0,
        1
    )
    local targetRate = TUNING.MUSIC_NORMAL_RATE
        + (TUNING.MUSIC_MAX_RATE - TUNING.MUSIC_NORMAL_RATE) * velocityProgress

    gameMusicRate +=
        (targetRate - gameMusicRate) * TUNING.MUSIC_RATE_INTERPOLATION_SPEED
    gameMusicPlayer:setRate(gameMusicRate)
end

local function startGameplayLoopSounds()
    startBoatEngineSound()
    startWaterFlowSound()
    startGameMusic()
end

local function stopGameplayLoopSounds()
    stopBoatEngineSound()
    stopWaterFlowSound()
    pauseGameMusic()
end

local CRASH_MESSAGE_TEXT <const> = "*You crashed!*\n*Press A to restart*"
local CRASH_MESSAGE_PADDING <const> = 8
local crashMessageWidth, crashMessageHeight = pdg.getTextSize(CRASH_MESSAGE_TEXT)
local explosionX, explosionY = 0, 0
local explosionAnimation = nil
local explosionFrameDelay = 100
local explosionImageWidth, explosionImageHeight = explosionImagetable:getImage(1):getSize()
local rockExplosions = {}

local savedProgress = pd.datastore.read(TUNING.SAVE_FILE_NAME)
if type(savedProgress) ~= "table" then
    savedProgress = {}
end

local savedUpgrades = savedProgress.upgrades
if type(savedUpgrades) ~= "table" then
    savedUpgrades = {}
end

local playerCoins = math.max(0, math.floor(tonumber(savedProgress.coins) or 0))
local shieldUpgradeLevel = math.clamp(math.floor(tonumber(savedUpgrades.shield) or 0), 0, TUNING.MAX_ABILITY_UPGRADE_LEVEL)
local shrinkUpgradeLevel = math.clamp(math.floor(tonumber(savedUpgrades.shrink) or 0), 0, TUNING.MAX_ABILITY_UPGRADE_LEVEL)
local speedReductionUpgradeLevel =
    math.clamp(math.floor(tonumber(savedUpgrades.speedReduction) or 0), 0, TUNING.MAX_ABILITY_UPGRADE_LEVEL)
local dashUpgradeLevel =
    math.clamp(math.floor(tonumber(savedUpgrades.dash) or 0), 0, TUNING.MAX_ABILITY_UPGRADE_LEVEL)
local AUDIO_MODE_OPTIONS <const> = { "SFX + Music", "SFX", "Music" }
local selectedAudioMode = savedProgress.audioMode

if selectedAudioMode ~= AUDIO_MODE_OPTIONS[1]
    and selectedAudioMode ~= AUDIO_MODE_OPTIONS[2]
    and selectedAudioMode ~= AUDIO_MODE_OPTIONS[3] then
    selectedAudioMode = AUDIO_MODE_OPTIONS[1]
end

local progressNeedsSave = false
local saveFailureWasLogged = false

local function markProgressChanged()
    progressNeedsSave = true
end

local function saveProgress()
    if progressNeedsSave == false then
        return true
    end

    local progress = {
        coins = playerCoins,
        audioMode = selectedAudioMode,
        upgrades = {
            shield = shieldUpgradeLevel,
            shrink = shrinkUpgradeLevel,
            speedReduction = speedReductionUpgradeLevel,
            dash = dashUpgradeLevel
        }
    }

    -- A read-only Simulator SDK folder must not be able to terminate gameplay.
    -- Keep the data dirty so lifecycle callbacks can retry after permissions change.
    local writeCompleted, writeResult = pcall(pd.datastore.write, progress, TUNING.SAVE_FILE_NAME)

    if writeCompleted and writeResult ~= false then
        progressNeedsSave = false
        saveFailureWasLogged = false
        return true
    end

    if saveFailureWasLogged == false then
        print("Unable to save progress: " .. tostring(writeResult))
        saveFailureWasLogged = true
    end

    return false
end

local function applyAudioMode()
    sfxChannel:setVolume(selectedAudioMode == AUDIO_MODE_OPTIONS[3] and 0 or 1)
    musicChannel:setVolume(selectedAudioMode == AUDIO_MODE_OPTIONS[2] and 0 or 1)
end

applyAudioMode()

pd.getSystemMenu():addOptionsMenuItem("audio", AUDIO_MODE_OPTIONS, selectedAudioMode, function(newAudioMode)
    selectedAudioMode = newAudioMode
    applyAudioMode()
    markProgressChanged()
    saveProgress()
end)

-- Player variables
local playerScore = 0
local playerScoreStep = 10
local playerVelocity = 2
local playerSpeedMode = 1  -- 0: No speed, 1: Normal speed, 2: Fast speed
local playerStartX, playerStartY = 200, 130
local playerX, playerY = playerStartX, playerStartY
local currentPlayerScale = 1
local targetPlayerScale = 1
local shrinkRemainingMilliseconds = nil
local shrinkDurationMilliseconds = nil
local shrinkUiProgress = 0
local shrinkUiIsFilling = false
local shieldHitsRemaining = 0
local bButtonHeldMilliseconds = 0
local bButtonIsBeingHeld = false
local bButtonHoldModeActivated = false
local dashVelocityX = 0
local dashVelocityY = 0
local dashCooldownRemainingMilliseconds = 0
local dashCooldownDurationMilliseconds = TUNING.DASH_COOLDOWN_MS_BY_LEVEL[dashUpgradeLevel + 1]
local dashUiProgress = 1
local dashUiIsDraining = false
local speedometerNeedleAngle = TUNING.SPEEDOMETER_MIN_ANGLE

local scoreTimer = pd.timer.new(1000, function()
    if BoatGameState == GameState.ALIVE and pd.isCrankDocked() == false then
        playerScore += playerScoreStep
    end
end)
scoreTimer.repeats = true

-- Velocity inertia variables
local xVelocity = 0
local yVelocity = 0
local targetXVelocity = 0
local targetYVelocity = 0
local velocityInterpolationSpeed = 0.25  -- Smoothness of velocity transitions (0.0-1.0)

-- Water stream velocity
local waterStreamVelocity = 3  -- X+ direction velocity from water stream

-- Every world object uses these same target and interpolated velocity values.
local worldVelocity = TUNING.INITIAL_WORLD_VELOCITY
local interpolatedWorldVelocity = worldVelocity
local waterImage = pdg.image.new("images/WaterBackground")
local waterImageWidth = waterImage:getSize()
local waterSprites = {}
local waterScrollX = 0

for i = 1, 2 do
    local waterSprite = pdg.sprite.new(waterImage)
    waterSprite:moveTo(-(i - 1) * waterImageWidth, TUNING.WATER_BACKGROUND_Y_OFFSET)
    waterSprite:setZIndex(-1000)
    waterSprite:add()
    waterSprites[i] = waterSprite
end

local worldVelocityInterpolationSpeed = 0.08
local rockImage1 = pdg.image.new("images/Rock1")
local rockImage2 = pdg.image.new("images/Rock2")
local rockImage3 = pdg.image.new("images/Rock3")
local rockImage4 = pdg.image.new("images/Rock4")
local rockImages = { rockImage1, rockImage2, rockImage3, rockImage4 }
local rockImageWidths = {}
local rockImageHeights = {}
local rockSprites = {}
local collectableSprites = {}
local decorationSprites = {}
local interactableObjectGroups = { rockSprites, collectableSprites, decorationSprites }

for i = 1, #rockImages do
    rockImageWidths[i], rockImageHeights[i] = rockImages[i]:getSize()
end

local function setRockImage(rock, imageIndex)
    rock.imageIndex = imageIndex
    rock.imageWidth = rockImageWidths[imageIndex]
    rock.imageHeight = rockImageHeights[imageIndex]
    rock:setImage(rockImages[imageIndex])
    rock:setCollideRect(0, 0, rock.imageWidth, rock.imageHeight)
end

local function findRockSpawnPosition(rock)
    return InteractiveSpawn.findPosition(
        interactableObjectGroups,
        rock,
        rock.imageWidth,
        rock.imageHeight,
        TUNING.ROCK_SPAWN_MINIMUM_X,
        -rock.imageWidth / 2,
        TUNING.WORLD_SPAWN_MINIMUM_Y + rock.imageHeight / 2,
        TUNING.WORLD_SPAWN_MAXIMUM_Y - rock.imageHeight / 2,
        TUNING.INTERACTIVE_SPAWN_PADDING,
        TUNING.INTERACTIVE_SPAWN_ATTEMPTS
    )
end

local function resetRockPosition(rock)
    setRockImage(rock, math.random(#rockImages))

    local x, y = findRockSpawnPosition(rock)
    if x == nil then
        rock.active = false
        rock:setVisible(false)
        return false
    end

    rock:moveTo(x, y)
    rock.active = true
    rock:setVisible(true)
    return true
end

for i = 1, TUNING.MAX_ROCKS do
    local rock = pdg.sprite.new()
    rock.objectType = "rock"
    rock.collisionResponse = pdg.sprite.kCollisionTypeOverlap
    rock:setZIndex(TUNING.ROCK_Z_INDEX)
    rock:moveTo(-20, -100)
    rock:setVisible(false)
    rock.active = false
    rock:add()
    rockSprites[i] = rock
end

for i = 1, TUNING.MAX_ROCKS do
    resetRockPosition(rockSprites[i])
end

local velocityIncreaseTimer = pd.timer.new(TUNING.VELOCITY_INCREASE_INTERVAL_MS, function()
    worldVelocity = math.min(
        TUNING.MAX_WORLD_VELOCITY,
        worldVelocity * TUNING.WORLD_VELOCITY_GROWTH_MULTIPLIER
    )
    playerScoreStep += 10
end)
velocityIncreaseTimer.repeats = true

if pd.isCrankDocked() then
    velocityIncreaseTimer:pause()
end

-- Player image
local playerSprite = pdg.sprite.new(playerImagetable:getImage(1))
local playerImageWidth, playerImageHeight = playerImagetable:getImage(1):getSize()
local playerCollisionX = playerImageWidth / 3
local playerCollisionY = playerImageHeight / 2
local playerCollisionWidth = playerImageWidth / 3
local playerCollisionHeight = playerImageHeight / 5
playerSprite.collisionResponse = pdg.sprite.kCollisionTypeOverlap
playerSprite:setZIndex(TUNING.PLAYER_Z_INDEX)
playerSprite:setCollideRect(playerCollisionX, playerCollisionY, playerCollisionWidth, playerCollisionHeight)
playerSprite:moveTo(playerStartX, playerStartY)
playerSprite:add()

local hudMessage = nil
local hudMessageRemainingMilliseconds = 0
local collectablesByType = {}
local collectableSpawnRemainingMilliseconds = {}
local collectableTypes <const> = { "coin", "shield", "shrink", "speedReduction" }

local function showHudMessage(message)
    hudMessage = message
    hudMessageRemainingMilliseconds = 1800
end

local function onCoinCollected()
    playerCoins += 1
    playSoundOneShot(coinPickupSoundPlayer)
    markProgressChanged()
    saveProgress()
end

local function onShieldCollected()
    shieldHitsRemaining = math.min(
        TUNING.MAX_SHIELD_HITS,
        shieldHitsRemaining + TUNING.SHIELD_HITS_BY_LEVEL[shieldUpgradeLevel + 1]
    )
    playSoundOneShot(shieldSoundPlayer)
end

local function onShrinkCollected()
    shrinkDurationMilliseconds = TUNING.SHRINK_DURATION_MS_BY_LEVEL[shrinkUpgradeLevel + 1]
    targetPlayerScale = TUNING.SHRUNK_PLAYER_SCALE
    shrinkRemainingMilliseconds = shrinkDurationMilliseconds
    shrinkUiProgress = 0
    shrinkUiIsFilling = true
    playSoundOneShot(shrinkSoundPlayer)
end

local function onSpeedReductionCollected()
    local reduction = TUNING.SPEED_REDUCTION_BY_LEVEL[speedReductionUpgradeLevel + 1]
    worldVelocity = math.max(TUNING.MIN_WORLD_VELOCITY, worldVelocity - reduction)
    playSoundOneShot(speedReductionSoundPlayer)
end

collectablesByType.coin = CoinCollectable(coinImagetable, onCoinCollected)
collectablesByType.shield = ShieldCollectable(shieldCollectableImage, onShieldCollected)
collectablesByType.shrink = ShrinkCollectable(shrinkCollectableImage, onShrinkCollected)
collectablesByType.speedReduction =
    SpeedReductionCollectable(speedReductionCollectableImage, onSpeedReductionCollected)

for i = 1, #collectableTypes do
    local collectableType = collectableTypes[i]
    local collectable = collectablesByType[collectableType]
    collectable:setZIndex(TUNING.COLLECTABLE_Z_INDEX)
    collectableSprites[#collectableSprites + 1] = collectable

    local config = TUNING.COLLECTABLE_SPAWN_CONFIG[collectableType]
    collectableSpawnRemainingMilliseconds[collectableType] =
        math.random(config.minimumIntervalMs, config.maximumIntervalMs)
end

local function resetCollectableSpawnCountdown(collectableType)
    local config = TUNING.COLLECTABLE_SPAWN_CONFIG[collectableType]
    collectableSpawnRemainingMilliseconds[collectableType] =
        math.random(config.minimumIntervalMs, config.maximumIntervalMs)
end

local function spawnCollectable(collectable)
    local x, y = InteractiveSpawn.findPosition(
        interactableObjectGroups,
        collectable,
        collectable.imageWidth,
        collectable.imageHeight,
        TUNING.COLLECTABLE_SPAWN_MINIMUM_X,
        -collectable.imageWidth / 2,
        TUNING.WORLD_SPAWN_MINIMUM_Y + collectable.imageHeight / 2,
        TUNING.WORLD_SPAWN_MAXIMUM_Y - collectable.imageHeight / 2,
        TUNING.INTERACTIVE_SPAWN_PADDING,
        TUNING.INTERACTIVE_SPAWN_ATTEMPTS
    )

    if x == nil then
        return false
    end

    collectable:spawnAt(x, y)
    return true
end

local function updateCollectables(elapsedMilliseconds, worldDisplacement)
    for i = 1, #collectableTypes do
        local collectableType = collectableTypes[i]
        local collectable = collectablesByType[collectableType]

        if collectable.active then
            if collectable.isCollecting == false then
                collectable:moveBy(worldDisplacement, 0)

                if collectable.x - collectable.imageWidth / 2 > 400 then
                    collectable:despawn()
                end
            end
        else
            local remaining =
                collectableSpawnRemainingMilliseconds[collectableType] - elapsedMilliseconds
            collectableSpawnRemainingMilliseconds[collectableType] = remaining

            if remaining <= 0 then
                local config = TUNING.COLLECTABLE_SPAWN_CONFIG[collectableType]
                resetCollectableSpawnCountdown(collectableType)

                if math.random(100) <= config.spawnChancePercent then
                    spawnCollectable(collectable)
                end
            end
        end
    end
end

local function resetCollectables()
    for i = 1, #collectableTypes do
        local collectableType = collectableTypes[i]
        collectablesByType[collectableType]:despawn()
        resetCollectableSpawnCountdown(collectableType)
    end
end

local decorationManager = DecorationManager.new(
    TUNING.DECORATION_SPAWN_CONFIG,
    interactableObjectGroups,
    decorationSprites,
    TUNING
)

local function updatePlayerScale(elapsedMilliseconds)
    if shrinkRemainingMilliseconds ~= nil then
        if shrinkUiIsFilling then
            shrinkUiProgress = math.min(
                1,
                shrinkUiProgress + elapsedMilliseconds / TUNING.SHRINK_UI_FILL_DURATION_MS
            )

            if shrinkUiProgress >= 1 then
                shrinkUiProgress = 1
                shrinkUiIsFilling = false
            end
        else
            shrinkRemainingMilliseconds -= elapsedMilliseconds
            shrinkUiProgress = math.max(
                0,
                shrinkRemainingMilliseconds / shrinkDurationMilliseconds
            )

            if shrinkRemainingMilliseconds <= 0 then
                shrinkRemainingMilliseconds = nil
                shrinkDurationMilliseconds = nil
                shrinkUiProgress = 0
                targetPlayerScale = 1
            end
        end
    else
        shrinkUiProgress = 0
        shrinkUiIsFilling = false
    end

    local scaleDifference = targetPlayerScale - currentPlayerScale

    if math.abs(scaleDifference) < 0.005 then
        currentPlayerScale = targetPlayerScale
    else
        currentPlayerScale += scaleDifference * TUNING.PLAYER_SCALE_INTERPOLATION_SPEED
    end

    playerSprite:setScale(currentPlayerScale)
    playerSprite:setCollideRect(
        playerCollisionX * currentPlayerScale,
        playerCollisionY * currentPlayerScale,
        playerCollisionWidth * currentPlayerScale,
        playerCollisionHeight * currentPlayerScale
    )
end

local function updateDashCooldown(elapsedMilliseconds)
    if dashCooldownRemainingMilliseconds > 0 then
        dashCooldownRemainingMilliseconds =
            math.max(0, dashCooldownRemainingMilliseconds - elapsedMilliseconds)
    end

    if dashUiIsDraining then
        dashUiProgress = math.max(
            0,
            dashUiProgress - elapsedMilliseconds / TUNING.DASH_UI_DRAIN_DURATION_MS
        )

        if dashUiProgress == 0 then
            dashUiIsDraining = false
        end
    elseif dashCooldownRemainingMilliseconds > 0 then
        dashUiProgress = 1
            - dashCooldownRemainingMilliseconds / dashCooldownDurationMilliseconds
    else
        dashUiProgress = 1
    end
end

local function startDash(crankPositionForVelocity)
    if dashCooldownRemainingMilliseconds > 0 then
        return false
    end

    local currentSpeed = math.sqrt(xVelocity * xVelocity + yVelocity * yVelocity)
    local directionX
    local directionY

    if currentSpeed > 0.05 then
        directionX = xVelocity / currentSpeed
        directionY = yVelocity / currentSpeed
    else
        directionX = math.cos(math.rad(crankPositionForVelocity))
        directionY = math.sin(math.rad(crankPositionForVelocity))
    end

    dashVelocityX = directionX * TUNING.DASH_INITIAL_VELOCITY
    dashVelocityY = directionY * TUNING.DASH_INITIAL_VELOCITY
    dashCooldownDurationMilliseconds = TUNING.DASH_COOLDOWN_MS_BY_LEVEL[dashUpgradeLevel + 1]
    dashCooldownRemainingMilliseconds = dashCooldownDurationMilliseconds
    dashUiProgress = 1
    dashUiIsDraining = true
    playSoundOneShot(dashSoundPlayer)
    return true
end

local function updateBButton(elapsedMilliseconds, crankPositionForVelocity)
    if pd.buttonJustPressed(pd.kButtonB) then
        bButtonHeldMilliseconds = 0
        bButtonIsBeingHeld = true
        bButtonHoldModeActivated = false
    end

    if bButtonIsBeingHeld and pd.buttonIsPressed(pd.kButtonB) then
        bButtonHeldMilliseconds += elapsedMilliseconds

        if bButtonHeldMilliseconds >= TUNING.DASH_HOLD_THRESHOLD_MS
            and bButtonHoldModeActivated == false
        then
            bButtonHoldModeActivated = true
            playerSpeedMode = 2
        end
    end

    if pd.buttonJustReleased(pd.kButtonB) then
        if bButtonIsBeingHeld and bButtonHoldModeActivated == false then
            startDash(crankPositionForVelocity)
        end

        bButtonHeldMilliseconds = 0
        bButtonIsBeingHeld = false
        bButtonHoldModeActivated = false
        playerSpeedMode = 1
    end
end

local function updateDashInertia(elapsedMilliseconds)
    local frameDurationMilliseconds <const> = 1000 / 30
    local retention = TUNING.DASH_INERTIA_RETENTION_PER_FRAME
        ^ (elapsedMilliseconds / frameDurationMilliseconds)
    dashVelocityX *= retention
    dashVelocityY *= retention

    if math.abs(dashVelocityX) < TUNING.DASH_STOP_VELOCITY then
        dashVelocityX = 0
    end

    if math.abs(dashVelocityY) < TUNING.DASH_STOP_VELOCITY then
        dashVelocityY = 0
    end
end

local selectedUpgradeAbility = "shield"
local upgradePurchaseMenuItem = nil
local upgradeAbilityLabels <const> = {
    shield = "Shield",
    shrink = "Shrink",
    speedReduction = "Slowdown",
    dash = "Dash"
}
local upgradeAbilityTypesByLabel <const> = {
    Shield = "shield",
    Shrink = "shrink",
    Slowdown = "speedReduction",
    Dash = "dash"
}

local function getAbilityUpgradeLevel(abilityType)
    if abilityType == "shield" then
        return shieldUpgradeLevel
    elseif abilityType == "shrink" then
        return shrinkUpgradeLevel
    elseif abilityType == "speedReduction" then
        return speedReductionUpgradeLevel
    end

    return dashUpgradeLevel
end

local function setAbilityUpgradeLevel(abilityType, level)
    if abilityType == "shield" then
        shieldUpgradeLevel = level
    elseif abilityType == "shrink" then
        shrinkUpgradeLevel = level
    elseif abilityType == "speedReduction" then
        speedReductionUpgradeLevel = level
    else
        dashUpgradeLevel = level
    end
end

local function refreshUpgradeMenuTitles()
    if upgradePurchaseMenuItem == nil then
        return
    end

    local level = getAbilityUpgradeLevel(selectedUpgradeAbility)
    local label = upgradeAbilityLabels[selectedUpgradeAbility]

    if level >= TUNING.MAX_ABILITY_UPGRADE_LEVEL then
        upgradePurchaseMenuItem:setTitle("Buy " .. label .. ": MAX")
    else
        local cost = TUNING.ABILITY_UPGRADE_COSTS[selectedUpgradeAbility][level + 1]
        upgradePurchaseMenuItem:setTitle("Buy " .. label .. " L" .. (level + 1) .. " (" .. cost .. "c)")
    end
end

local function purchaseAbilityUpgrade(abilityType)
    local level = getAbilityUpgradeLevel(abilityType)

    if level >= TUNING.MAX_ABILITY_UPGRADE_LEVEL then
        showHudMessage("Ability is already max level")
        return
    end

    local cost = TUNING.ABILITY_UPGRADE_COSTS[abilityType][level + 1]
    if playerCoins < cost then
        showHudMessage("Need " .. cost .. " coins")
        return
    end

    playerCoins -= cost
    setAbilityUpgradeLevel(abilityType, level + 1)

    if abilityType == "dash" and dashCooldownRemainingMilliseconds <= 0 then
        dashCooldownDurationMilliseconds = TUNING.DASH_COOLDOWN_MS_BY_LEVEL[dashUpgradeLevel + 1]
    end

    markProgressChanged()
    saveProgress()
    refreshUpgradeMenuTitles()
    showHudMessage("Ability upgraded to level " .. (level + 1))
end

local systemMenu = pd.getSystemMenu()
systemMenu:addOptionsMenuItem(
    "Upgrade",
    { "Shield", "Shrink", "Slowdown", "Dash" },
    "Shield",
    function(selectedLabel)
        selectedUpgradeAbility = upgradeAbilityTypesByLabel[selectedLabel]
        refreshUpgradeMenuTitles()
    end
)
upgradePurchaseMenuItem = systemMenu:addMenuItem("Buy upgrade", function()
    purchaseAbilityUpgrade(selectedUpgradeAbility)
end)
refreshUpgradeMenuTitles()

local function resetExplosion()
    explosionAnimation = nil
end

local function startExplosion(x, y)
    explosionX = x
    explosionY = y
    explosionAnimation = pdg.animation.loop.new(explosionFrameDelay, explosionImagetable, false)
end

local function updateExplosion()
    if explosionAnimation == nil or explosionAnimation:isValid() == false then
        return
    end

    explosionAnimation:draw(explosionX - explosionImageWidth / 2, explosionY - explosionImageHeight / 2)
end

-- Particle emitter offsets for each sprite direction (indexed by playerSpriteIndexFromAngle)
-- Each entry is {offsetX, offsetY} relative to boat center
local playerParticleEmitterOffsets = {
    {x = 0, y = 25},    -- 1 frame
    {x = -5, y = 26},   -- 2 frame
    {x = -9, y = 26},   -- 3 frame
    {x = -13, y = 26},  -- 4 frame
    {x = -17, y = 26},  -- 5 frame
    {x = -19, y = 24},  -- 6 frame
    {x = -21, y = 24},  -- 7 frame
    {x = -24, y = 23},  -- 8 frame
    {x = -24, y = 22},  -- 9 frame
    {x = -26, y = 20},  -- 10 frame
    {x = -28, y = 17},  -- 11 frame
    {x = -29, y = 14},  -- 12 frame
    {x = -30, y = 11},  -- 13 frame
    {x = -31, y = 8},   -- 14 frame
    {x = -30, y = 3},   -- 15 frame
    {x = -29, y = -1},  -- 16 frame
    {x = -27, y = -5},  -- 17 frame
    {x = -25, y = -7},  -- 18 frame
    {x = -23, y = -7},  -- 19 frame
    {x = -22, y = -9},  -- 20 frame
    {x = -19, y = -10}, -- 21 frame
    {x = -16, y = -11}, -- 22 frame
    {x = -11, y = -14}, -- 23 frame
    {x = -6, y = -16},  -- 24 frame
    {x = -2, y = -15},  -- 25 frame
    {x = 3, y = -15},   -- 26 frame
    {x = 7, y = -15},   -- 27 frame
    {x = 10, y = -14},  -- 28 frame
    {x = 13, y = -13},  -- 29 frame
    {x = 15, y = -12},  -- 30 frame
    {x = 17, y = -8},   -- 31 frame
    {x = 22, y = -6},   -- 32 frame
    {x = 24, y = -5},   -- 33 frame
    {x = 26, y = -1},   -- 34 frame
    {x = 28, y = 3},    -- 35 frame
    {x = 29, y = 6},    -- 36 frame
    {x = 29, y = 9},    -- 37 frame
    {x = 28, y = 13},   -- 38 frame
    {x = 27, y = 16},   -- 39 frame
    {x = 24, y = 19},   -- 40 frame
    {x = 22, y = 21},   -- 41 frame
    {x = 21, y = 23},   -- 42 frame
    {x = 19, y = 24},   -- 43 frame
    {x = 17, y = 25},   -- 44 frame
    {x = 15, y = 26},   -- 45 frame
    {x = 12, y = 28},   -- 46 frame
    {x = 8, y = 29},    -- 47 frame
    {x = 4, y = 30},    -- 48 frame
}

local wakeLinePoolSize = 28
local wakeLinePool = {}
local wakeLineCursor = 1
local wakeLineSpawnCounter = 0

for i = 1, wakeLinePoolSize do
    wakeLinePool[i] = { active = false }
end

local function clearWakeLines()
    for i = 1, wakeLinePoolSize do
        wakeLinePool[i].active = false
    end
end

local function spawnWakeLine(engineX, engineY, wakeAngle, speedMultiplier)
    local line = wakeLinePool[wakeLineCursor]

    wakeLineCursor += 1
    if wakeLineCursor > wakeLinePoolSize then
        wakeLineCursor = 1
    end

    local angle = wakeAngle + math.random(-12, 12)
    local perpendicularAngle = angle + 90
    local sideOffset = math.random(-3, 3)
    local speed = math.random(12, 20) / 10 * speedMultiplier

    line.active = true
    line.x = engineX + math.sin(math.rad(perpendicularAngle)) * sideOffset
    line.y = engineY - math.cos(math.rad(perpendicularAngle)) * sideOffset
    line.dx = math.sin(math.rad(angle))
    line.dy = -math.cos(math.rad(angle))
    line.speed = speed
    line.length = math.random(8, 15)
    line.age = 0
    line.lifetime = math.random(10, 16)
    line.width = math.random(1, 2)
end

local function updateWakeLines(
    currentVelocityAngle,
    playerSpriteIndexFromAngle,
    isDashing,
    worldDisplacement
)
    for i = 1, wakeLinePoolSize do
        local line = wakeLinePool[i]

        if line.active == true then
            local lifeProgress = line.age / line.lifetime

            if lifeProgress >= 1 then
                line.active = false
            else
                line.x += line.dx * line.speed + worldDisplacement
                line.y += line.dy * line.speed
                line.age += 1
            end
        end
    end

    local emitterOffset = playerParticleEmitterOffsets[playerSpriteIndexFromAngle]
    local engineX = playerX + emitterOffset.x * currentPlayerScale
    local engineY = playerY + emitterOffset.y * currentPlayerScale
    local wakeAngle = math.normalizeAngle(currentVelocityAngle + 180)

    if playerSpeedMode == 2 or isDashing then
        spawnWakeLine(engineX, engineY, wakeAngle, 1.6)
        spawnWakeLine(engineX, engineY, wakeAngle, 1.6)
    elseif playerSpeedMode == 1 then
        wakeLineSpawnCounter += 1

        if wakeLineSpawnCounter >= 2 then
            spawnWakeLine(engineX, engineY, wakeAngle, 1)
            wakeLineSpawnCounter = 0
        end
    end
end

local function drawWakeLines()
    local previousLineWidth = pdg.getLineWidth()
    local previousColor = pdg.getColor()

    pdg.setColor(pdg.kColorBlack)

    for i = 1, wakeLinePoolSize do
        local line = wakeLinePool[i]

        if line.active == true then
            local lifeProgress = line.age / line.lifetime
            local lineLength = line.length * (1 - lifeProgress)
            local lineWidth = line.width

            if lifeProgress > 0.55 then
                lineWidth = 1
            end

            pdg.setLineWidth(lineWidth)
            pdg.drawLine(line.x, line.y, line.x + line.dx * lineLength, line.y + line.dy * lineLength)
        end
    end

    pdg.setLineWidth(previousLineWidth)
    pdg.setColor(previousColor)
end

local function startRockExplosion(x, y)
    local explosionSprite = pdg.sprite.new(rockExplosionImagetable:getImage(1))
    explosionSprite:setZIndex(TUNING.ROCK_EXPLOSION_Z_INDEX)
    explosionSprite:moveTo(x, y)
    explosionSprite:add()

    rockExplosions[#rockExplosions + 1] = {
        sprite = explosionSprite,
        frame = 1,
        elapsedMilliseconds = 0
    }
end

local function updateRockExplosions(elapsedMilliseconds, worldDisplacement)
    for i = #rockExplosions, 1, -1 do
        local rockExplosion = rockExplosions[i]
        rockExplosion.sprite:moveBy(worldDisplacement, 0)
        rockExplosion.elapsedMilliseconds += elapsedMilliseconds

        local nextFrame = math.floor(rockExplosion.elapsedMilliseconds / 50) + 1

        if nextFrame > rockExplosionImagetable:getLength() then
            rockExplosion.sprite:remove()
            table.remove(rockExplosions, i)
        elseif nextFrame ~= rockExplosion.frame then
            rockExplosion.frame = nextFrame
            rockExplosion.sprite:setImage(rockExplosionImagetable:getImage(nextFrame))
        end
    end
end

local function clearRockExplosions()
    for i = 1, #rockExplosions do
        rockExplosions[i].sprite:remove()
    end

    rockExplosions = {}
end

local function drawVerticalProgressIcon(image, x, y, progress)
    local width, height = image:getSize()
    local clampedProgress = math.clamp(progress, 0, 1)
    local filledHeight = math.floor(height * clampedProgress + 0.5)

    -- Keep the ability recognizable while unavailable, then reveal the solid icon
    -- from bottom to top as its progress fills.
    image:drawFaded(x, y, 0.25, pdg.image.kDitherTypeBayer8x8)

    if filledHeight > 0 then
        pdg.setClipRect(x, y + height - filledHeight, width, filledHeight)
        image:draw(x, y)
        pdg.clearClipRect()
    end

    return width
end

local function updateSpeedometerNeedle(dashSpeed)
    local worldSpeedProgress = math.clamp(
        (interpolatedWorldVelocity - TUNING.MIN_WORLD_VELOCITY)
            / (TUNING.MAX_WORLD_VELOCITY - TUNING.MIN_WORLD_VELOCITY),
        0,
        1
    )
    local speedProgress = worldSpeedProgress * TUNING.SPEEDOMETER_WORLD_SPEED_WEIGHT

    if playerSpeedMode == 2 then
        speedProgress += TUNING.SPEEDOMETER_FAST_MODE_BOOST
    end

    speedProgress += math.clamp(dashSpeed / TUNING.DASH_INITIAL_VELOCITY, 0, 1)
        * TUNING.SPEEDOMETER_DASH_BOOST
    speedProgress = math.clamp(speedProgress, 0, 1)

    local targetAngle = TUNING.SPEEDOMETER_MIN_ANGLE
        + (TUNING.SPEEDOMETER_MAX_ANGLE - TUNING.SPEEDOMETER_MIN_ANGLE) * speedProgress
    speedometerNeedleAngle +=
        (targetAngle - speedometerNeedleAngle) * TUNING.SPEEDOMETER_NEEDLE_INTERPOLATION_SPEED
end

local function drawHud()
    backgroundHUDImage:draw(0, 0)
    local speedometerX <const> = 15
    local speedometerY <const> = 12
    local speedometerWidth, speedometerHeight = speedometerImage:getSize()
    speedometerImage:draw(speedometerX, speedometerY)
    speedometerNeedleImage:drawRotated(
        speedometerX + speedometerWidth / 2,
        speedometerY + speedometerHeight / 2,
        speedometerNeedleAngle
    )
    local abilitiesY = 18

    drawVerticalProgressIcon(
        dashImage,
        60,
        abilitiesY,
        dashUiProgress
    )

    drawVerticalProgressIcon(shrinkImage, 92, abilitiesY, shrinkUiProgress)

    local shieldProgress = shieldHitsRemaining / TUNING.MAX_SHIELD_HITS
    drawVerticalProgressIcon(shieldImage, 124, abilitiesY, shieldProgress)
    -- pdg.drawText("x" .. shieldHitsRemaining, 124 + 20, abilitiesY + 2)

    local scoreText = "" .. playerScore
    local scoreTextWidth = pdg.getTextSize(scoreText)
    local scoreX = 400 - scoreTextWidth - 18
    local starImageWidth = starImage:getSize()
    local starX = scoreX - starImageWidth - 5
    starImage:draw(starX, 17)
    pdg.drawText(scoreText, scoreX, 21)

    local coinText = tostring(playerCoins)
    local coinTextWidth = pdg.getTextSize(coinText)
    local coinImage = coinImagetable:getImage(1)
    local coinImageWidth = coinImage:getSize()
    local coinX = starX - coinImageWidth - coinTextWidth - 10
    coinImage:draw(coinX, 18)
    pdg.drawText(coinText, coinX + coinImageWidth + 2, 21)

    if hudMessage ~= nil then
        pdg.drawText(hudMessage, 10, 216)
    end
end

local function drawCrashMessage()
    local textX = 200
    local textY = math.floor((240 - crashMessageHeight) / 2)
    local backgroundX = math.floor(textX - crashMessageWidth / 2) - CRASH_MESSAGE_PADDING
    local backgroundY = textY - CRASH_MESSAGE_PADDING
    local backgroundWidth = crashMessageWidth + CRASH_MESSAGE_PADDING * 2
    local backgroundHeight = crashMessageHeight + CRASH_MESSAGE_PADDING * 2
    local previousColor = pdg.getColor()

    pdg.setColor(pdg.kColorWhite)
    pdg.fillRect(backgroundX, backgroundY, backgroundWidth, backgroundHeight)
    pdg.setColor(pdg.kColorBlack)
    pdg.drawRect(backgroundX, backgroundY, backgroundWidth, backgroundHeight)
    pdg.drawTextAligned(
        CRASH_MESSAGE_TEXT,
        textX,
        textY,
        kTextAlignment.center
    )

    pdg.setColor(previousColor)
end

local function destroyRock(rock)
    startRockExplosion(rock.x, rock.y)
    playRockExplosionSound()
    rock.active = false
    rock:setVisible(false)
end

local function handlePlayerCollisions(collisions, length)
    -- Temporarily expose the complete scaled boat bounds for pickup checks. Rock
    -- collisions continue to use the smaller gameplay hitbox restored below.
    playerSprite:setCollideRect(
        0,
        0,
        playerImageWidth * currentPlayerScale,
        playerImageHeight * currentPlayerScale
    )

    for i = 1, #collectableSprites do
        local collectable = collectableSprites[i]

        if collectable.active
            and collectable.isCollecting == false
            and playerSprite:alphaCollision(collectable)
        then
            collectable:collect()
        end
    end

    playerSprite:setCollideRect(
        playerCollisionX * currentPlayerScale,
        playerCollisionY * currentPlayerScale,
        playerCollisionWidth * currentPlayerScale,
        playerCollisionHeight * currentPlayerScale
    )

    for i = 1, length do
        local other = collisions[i].other

        if other ~= nil
            and other.objectType == "rock"
            and other.active
            and playerSprite:alphaCollision(other)
        then
            if shieldHitsRemaining > 0 then
                shieldHitsRemaining -= 1
                destroyRock(other)
            else
                return true
            end
        end
    end

    return false
end

local function resetGame()
    BoatGameState = GameState.ALIVE
    xVelocity = 0
    yVelocity = 0
    targetXVelocity = 0
    targetYVelocity = 0
    playerX = playerStartX
    playerY = playerStartY
    worldVelocity = TUNING.INITIAL_WORLD_VELOCITY
    interpolatedWorldVelocity = worldVelocity
    playerSpeedMode = 1
    playerScore = 0
    playerScoreStep = 10
    shieldHitsRemaining = 0
    shrinkRemainingMilliseconds = nil
    shrinkDurationMilliseconds = nil
    shrinkUiProgress = 0
    shrinkUiIsFilling = false
    currentPlayerScale = 1
    targetPlayerScale = 1
    bButtonHeldMilliseconds = 0
    bButtonIsBeingHeld = false
    bButtonHoldModeActivated = false
    dashVelocityX = 0
    dashVelocityY = 0
    dashCooldownRemainingMilliseconds = 0
    dashCooldownDurationMilliseconds = TUNING.DASH_COOLDOWN_MS_BY_LEVEL[dashUpgradeLevel + 1]
    dashUiProgress = 1
    dashUiIsDraining = false
    speedometerNeedleAngle = TUNING.SPEEDOMETER_MIN_ANGLE
    boatEngineSoundRate = TUNING.ENGINE_MIN_WORLD_RATE
    boatEngineSoundVolume = TUNING.ENGINE_NORMAL_VOLUME
    waterFlowSoundRate = TUNING.WATER_FLOW_MIN_RATE
    gameMusicRate = TUNING.MUSIC_NORMAL_RATE
    gameMusicPlayer:stop()
    hudMessage = nil
    hudMessageRemainingMilliseconds = 0

    scoreTimer:reset()
    velocityIncreaseTimer:reset()
    if pd.isCrankDocked() then
        velocityIncreaseTimer:pause()
        stopGameplayLoopSounds()
    else
        velocityIncreaseTimer:start()
        stopGameplayLoopSounds()
        startGameplayLoopSounds()
    end

    playerSprite:setScale(1)
    playerSprite:setCollideRect(
        playerCollisionX,
        playerCollisionY,
        playerCollisionWidth,
        playerCollisionHeight
    )
    playerSprite:moveTo(playerX, playerY)
    waterScrollX = 0
    waterSprites[1]:moveTo(0, TUNING.WATER_BACKGROUND_Y_OFFSET)
    waterSprites[2]:moveTo(-waterImageWidth, TUNING.WATER_BACKGROUND_Y_OFFSET)
    clearWakeLines()
    resetCollectables()
    decorationManager:reset()

    for i = 1, TUNING.MAX_ROCKS do
        rockSprites[i].active = false
        rockSprites[i]:setVisible(false)
    end

    for i = 1, TUNING.MAX_ROCKS do
        resetRockPosition(rockSprites[i])
    end

    resetExplosion()
    clearRockExplosions()
end

function playdate.crankDocked()
    velocityIncreaseTimer:pause()
    stopGameplayLoopSounds()
end

function playdate.crankUndocked()
    lastUpdateTimeMilliseconds = pd.getCurrentTimeMilliseconds()

    if BoatGameState == GameState.ALIVE then
        velocityIncreaseTimer:start()
        startGameplayLoopSounds()
    end
end

function playdate.gameWillPause()
    saveProgress()
    stopGameplayLoopSounds()
end

function playdate.gameWillResume()
    lastUpdateTimeMilliseconds = pd.getCurrentTimeMilliseconds()

    if BoatGameState == GameState.ALIVE and pd.isCrankDocked() == false then
        startGameplayLoopSounds()
    end
end

function playdate.gameWillTerminate()
    saveProgress()
    stopGameplayLoopSounds()
end

function playdate.deviceWillSleep()
    saveProgress()
    stopGameplayLoopSounds()
end

function playdate.update()
    local currentTimeMilliseconds = pd.getCurrentTimeMilliseconds()
    local elapsedMilliseconds = currentTimeMilliseconds - lastUpdateTimeMilliseconds
    lastUpdateTimeMilliseconds = currentTimeMilliseconds

    if elapsedMilliseconds < 0 then
        elapsedMilliseconds = 0
    end

    -- elapsedMilliseconds = math.min(elapsedMilliseconds, TUNING.MAX_GAMEPLAY_FRAME_DURATION_MS)

    pd.timer.updateTimers()

    if hudMessageRemainingMilliseconds > 0 then
        hudMessageRemainingMilliseconds -= elapsedMilliseconds

        if hudMessageRemainingMilliseconds <= 0 then
            hudMessage = nil
        end
    end

    -- Keep gameplay paused until the player uses the crank.
    if pd.isCrankDocked() then
        stopGameplayLoopSounds()
        pdg.sprite.update()
        drawHud()
        pd.ui.crankIndicator:draw()
        velocityIncreaseTimer:pause()
        return
    end

    if BoatGameState == GameState.CRASHED then
        stopGameplayLoopSounds()
        pdg.sprite.update()
        updateExplosion()
        drawHud()
        drawCrashMessage()

        if pd.buttonJustReleased(pd.kButtonA) then
            resetGame()
        end

        return
    end

    interpolatedWorldVelocity +=
        (worldVelocity - interpolatedWorldVelocity) * worldVelocityInterpolationSpeed
    local worldDisplacement = math.max(
        TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
        math.floor(interpolatedWorldVelocity + 0.5)
    )
    startGameplayLoopSounds()

    -- Both tiles derive from one phase, so rounding and seam recycling cannot
    -- make them pause, separate, or briefly move in opposite directions.
    waterScrollX = (waterScrollX + worldDisplacement) % waterImageWidth
    waterSprites[1]:moveTo(waterScrollX, TUNING.WATER_BACKGROUND_Y_OFFSET)
    waterSprites[2]:moveTo(waterScrollX - waterImageWidth, TUNING.WATER_BACKGROUND_Y_OFFSET)

    for i = 1, TUNING.MAX_ROCKS do
        local rock = rockSprites[i]

        if rock.active then
            rock:moveBy(worldDisplacement, 0)

            if rock.x - rock.imageWidth / 2 > 400 then
                rock.active = false
                rock:setVisible(false)
            end
        end
    end

    decorationManager:update(elapsedMilliseconds, worldDisplacement, interpolatedWorldVelocity)
    updateCollectables(elapsedMilliseconds, worldDisplacement)
    updateRockExplosions(elapsedMilliseconds, worldDisplacement)

    -- Recycle rocks after collectables move/spawn so the shared overlap check sees
    -- every interactable object at its final position for this frame.
    for i = 1, TUNING.MAX_ROCKS do
        local rock = rockSprites[i]

        if rock.active == false then
            resetRockPosition(rock)
        end
    end

    updatePlayerScale(elapsedMilliseconds)
    updateDashCooldown(elapsedMilliseconds)

    local crankPositionForVelocity = pd.getCrankPosition() - 90
    updateBButton(elapsedMilliseconds, crankPositionForVelocity)

    local playerVelocityMultiplier = 1

    if playerSpeedMode == 2 then
        playerVelocityMultiplier = 2.25
    end

    targetXVelocity =
        math.cos(math.rad(crankPositionForVelocity)) * playerVelocity * playerVelocityMultiplier
    targetYVelocity =
        math.sin(math.rad(crankPositionForVelocity)) * playerVelocity * playerVelocityMultiplier

    xVelocity += (targetXVelocity - xVelocity) * velocityInterpolationSpeed
    yVelocity += (targetYVelocity - yVelocity) * velocityInterpolationSpeed

    local movementVelocityX = xVelocity + dashVelocityX
    local movementVelocityY = yVelocity + dashVelocityY
    local currentVelocityAngle =
        math.normalizeAngle(math.deg(math.atan2(movementVelocityY, movementVelocityX)) + 90)
    local playerSpriteIndexFromAngle =
        math.clamp(math.ceil(currentVelocityAngle / 7.5), 1, playerImagetableSize)
    playerSprite:setImage(playerImagetable:getImage(playerSpriteIndexFromAngle))

    local dashSpeed = math.sqrt(dashVelocityX * dashVelocityX + dashVelocityY * dashVelocityY)
    local isDashing = dashSpeed >= TUNING.DASH_WAKE_MINIMUM_VELOCITY
    updateSpeedometerNeedle(dashSpeed)
    updateBoatEngineSound(
        playerSpeedMode == 2,
        shrinkRemainingMilliseconds ~= nil,
        interpolatedWorldVelocity
    )
    updateWaterFlowSound(interpolatedWorldVelocity)
    updateGameMusic(interpolatedWorldVelocity)
    playerX += movementVelocityX + waterStreamVelocity
    playerY += movementVelocityY

    local actualX, actualY, collisions, length = playerSprite:moveWithCollisions(playerX, playerY)
    playerX = actualX
    playerY = actualY

    local scaledPlayerWidth = playerImageWidth * currentPlayerScale
    local scaledPlayerHeight = playerImageHeight * currentPlayerScale
    playerX = math.clamp(playerX, scaledPlayerWidth / 2, 400 - scaledPlayerWidth / 3)
    playerY = math.clamp(
        playerY,
        TUNING.HUD_HEIGHT + scaledPlayerHeight / 2,
        240 - scaledPlayerHeight / 3
    )
    playerSprite:moveTo(playerX, playerY)
    updateDashInertia(elapsedMilliseconds)

    local didCrash = handlePlayerCollisions(collisions, length)

    if didCrash then
        BoatGameState = GameState.CRASHED
        velocityIncreaseTimer:pause()
        stopGameplayLoopSounds()
        playerSprite:setScale(0)
        clearWakeLines()
        startExplosion(playerX, playerY)
        playSoundOneShot(boatExplosionSoundPlayer)
    else
        updateWakeLines(
            currentVelocityAngle,
            playerSpriteIndexFromAngle,
            isDashing,
            worldDisplacement
        )
    end

    pdg.sprite.update()
    drawWakeLines()

    if didCrash then
        updateExplosion()
    end

    drawHud()
end
