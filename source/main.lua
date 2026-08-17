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
import "AbilityTopUI"
import "UpgradeMenuUI"

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
    MAIN_MENU = 1,
    LAUNCHING = 2,
    WAITING_FOR_CRANK = 3,
    ALIGNING_TO_CRANK = 4,
    ALIVE = 5,
    CRASH_REWIND = 6,
    RETURNING_TO_MENU = 7,
    UPGRADE_MENU = 8
}

local BoatGameState = GameState.MAIN_MENU
local lastUpdateTimeMilliseconds = pd.getCurrentTimeMilliseconds()

local playerImagetable = pdg.imagetable.new("images/Boat")
local playerImagetableSize = playerImagetable:getLength()
local explosionImagetable = pdg.imagetable.new("images/Explosion")
local rockExplosionImagetable = pdg.imagetable.new("images/RockExplosion")
local mainMenuImages = {
    background = pdg.image.new("images/MainMenuBackground"),
    hud = pdg.image.new("images/MainMenuHud")
}
local backgroundHUDImage = pdg.image.new("images/BackgroundHUD")
local speedometerImage = pdg.image.new("images/Speedometer")
local speedometerNeedleImage = pdg.image.new("images/SpeedometerNeedle")
local coinImagetable = pdg.imagetable.new("images/Coin")
local starImage = pdg.image.new("images/Star")
local shieldCollectableImage = pdg.image.new("images/ShieldNoFrame")
local shrinkCollectableImage = pdg.image.new("images/SrinkNoFrame")
local speedReductionCollectableImage = pdg.image.new("images/SpeedReductionNoFrame")

local selectAbilitySoundPlayer = pds.sampleplayer.new("sounds/SelectAbility")
local openUpgradeMenuSoundPlayer = pds.sampleplayer.new("sounds/OpenUpgradeMenu")
local closeUpgradeMenuSoundPlayer = pds.sampleplayer.new("sounds/CloseUpgradeMenu")
local buyAbilitySoundPlayer = pds.sampleplayer.new("sounds/BuyAbility")
local noUpgradeSoundPlayer = pds.sampleplayer.new("sounds/NoUpgrade")
local upgradeAbilitySoundPlayers = {
    pds.sampleplayer.new("sounds/UpgradeAbilityFirstLevel"),
    pds.sampleplayer.new("sounds/UpgradeAbilitySecondLevel"),
    pds.sampleplayer.new("sounds/UpgradeAbilityThirdLevel")
}

local coinPickupSoundPlayer = pds.sampleplayer.new("sounds/CoinPickup")
local dashSoundPlayer = pds.sampleplayer.new("sounds/Dash")
local shrinkSoundPlayer = pds.sampleplayer.new("sounds/Shrink")
local shrinkReversedSoundPlayer = pds.sampleplayer.new("sounds/ShrinkReversed")
local shieldSoundPlayer = pds.sampleplayer.new("sounds/Shield")
local speedReductionSoundPlayer = pds.sampleplayer.new("sounds/SpeedReduction")
local boatExplosionSoundPlayer = pds.sampleplayer.new("sounds/BoatExplosion")
local boatEngineSoundPlayer = pds.sampleplayer.new("sounds/BoatEngine")
local boatEngineSoundRate = TUNING.ENGINE_MIN_WORLD_RATE
local boatEngineSoundVolume = TUNING.ENGINE_NORMAL_VOLUME
local waterFlowSoundPlayer = pds.sampleplayer.new("sounds/WaterFlow")
local waterFlowSoundRate = TUNING.WATER_FLOW_MIN_RATE
local musicPlayers = {
    menu = pds.fileplayer.new("sounds/The Forgotten Grove"),
    gameplay = pds.fileplayer.new("sounds/Banners in the Wind")
}
local gameMusicRate = TUNING.MUSIC_NORMAL_RATE
local sfxChannel = pds.channel.new()
local musicChannel = pds.channel.new()
local rockExplosionSoundPlayers = {}
local rockExplosionSoundPlayerCursor = 1

sfxChannel:addSource(selectAbilitySoundPlayer)
sfxChannel:addSource(openUpgradeMenuSoundPlayer)
sfxChannel:addSource(closeUpgradeMenuSoundPlayer)
sfxChannel:addSource(buyAbilitySoundPlayer)
sfxChannel:addSource(noUpgradeSoundPlayer)

for i = 1, #upgradeAbilitySoundPlayers do
    sfxChannel:addSource(upgradeAbilitySoundPlayers[i])
end

sfxChannel:addSource(coinPickupSoundPlayer)
sfxChannel:addSource(dashSoundPlayer)
sfxChannel:addSource(shrinkSoundPlayer)
sfxChannel:addSource(shrinkReversedSoundPlayer)
sfxChannel:addSource(shieldSoundPlayer)
sfxChannel:addSource(speedReductionSoundPlayer)
sfxChannel:addSource(boatExplosionSoundPlayer)
sfxChannel:addSource(boatEngineSoundPlayer)
sfxChannel:addSource(waterFlowSoundPlayer)
musicChannel:addSource(musicPlayers.menu)
musicChannel:addSource(musicPlayers.gameplay)

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

local function startMenuMusic()
    if musicPlayers.gameplay:isPlaying() then
        musicPlayers.gameplay:stop()
    end

    if musicPlayers.menu:isPlaying() == false then
        musicPlayers.menu:setRate(TUNING.MUSIC_NORMAL_RATE)
        musicPlayers.menu:setVolume(TUNING.MUSIC_VOLUME)
        musicPlayers.menu:play(0)
    end
end

local function startGameplayMusic()
    if musicPlayers.menu:isPlaying() then
        musicPlayers.menu:stop()
    end

    if musicPlayers.gameplay:isPlaying() == false then
        musicPlayers.gameplay:setRate(gameMusicRate)
        musicPlayers.gameplay:setVolume(TUNING.MUSIC_VOLUME)
        musicPlayers.gameplay:play(0)
    end
end

local function pauseGameMusic()
    if musicPlayers.menu:isPlaying() then
        musicPlayers.menu:pause()
    end

    if musicPlayers.gameplay:isPlaying() then
        musicPlayers.gameplay:pause()
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
    musicPlayers.gameplay:setRate(gameMusicRate)
end

local function startGameplayLoopSounds()
    startBoatEngineSound()
    startWaterFlowSound()
    startGameplayMusic()
end

local function stopGameplayLoopSounds()
    stopBoatEngineSound()
    stopWaterFlowSound()
    pauseGameMusic()
end

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

local function loadAbilityUpgradeLevel(savedLevel)
    local numericLevel = tonumber(savedLevel)

    if numericLevel == nil then
        return TUNING.LOCKED_ABILITY_LEVEL
    end

    return math.clamp(
        math.floor(numericLevel),
        TUNING.LOCKED_ABILITY_LEVEL,
        TUNING.MAX_ABILITY_UPGRADE_LEVEL
    )
end

local playerCoins = math.max(0, math.floor(tonumber(savedProgress.coins) or 0))
local shieldUpgradeLevel = loadAbilityUpgradeLevel(savedUpgrades.shield)
local shrinkUpgradeLevel = loadAbilityUpgradeLevel(savedUpgrades.shrink)
local speedReductionUpgradeLevel = loadAbilityUpgradeLevel(savedUpgrades.speedReduction)
local dashUpgradeLevel = loadAbilityUpgradeLevel(savedUpgrades.dash)

local function isAbilityPurchased(abilityType)
    if abilityType == "shield" then
        return shieldUpgradeLevel > TUNING.LOCKED_ABILITY_LEVEL
    elseif abilityType == "shrink" then
        return shrinkUpgradeLevel > TUNING.LOCKED_ABILITY_LEVEL
    elseif abilityType == "speedReduction" then
        return speedReductionUpgradeLevel > TUNING.LOCKED_ABILITY_LEVEL
    end

    return dashUpgradeLevel > TUNING.LOCKED_ABILITY_LEVEL
end

local function getDashCooldownDuration()
    local level = math.max(0, dashUpgradeLevel)
    return TUNING.DASH_COOLDOWN_MS_BY_LEVEL[level + 1]
end
local AUDIO_MODE_OPTIONS <const> = { "SFX + Music", "SFX", "Music" }
local selectedAudioMode = savedProgress.audioMode
local UI_MODE_OPTIONS <const> = { "On Top", "Near Boat", "Top + Boat" }
local selectedUiMode = savedProgress.uiMode

if selectedAudioMode ~= AUDIO_MODE_OPTIONS[1]
    and selectedAudioMode ~= AUDIO_MODE_OPTIONS[2]
    and selectedAudioMode ~= AUDIO_MODE_OPTIONS[3] then
    selectedAudioMode = AUDIO_MODE_OPTIONS[1]
end

if selectedUiMode ~= UI_MODE_OPTIONS[1]
    and selectedUiMode ~= UI_MODE_OPTIONS[2]
    and selectedUiMode ~= UI_MODE_OPTIONS[3] then
    selectedUiMode = UI_MODE_OPTIONS[1]
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
        uiMode = selectedUiMode,
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

pd.getSystemMenu():addOptionsMenuItem("UI", UI_MODE_OPTIONS, selectedUiMode, function(newUiMode)
    selectedUiMode = newUiMode
    markProgressChanged()
    saveProgress()
end)

-- Player variables
local playerScore = 0
local playerScoreStep = 10
local playerVelocity = 2
local playerSpeedMode = 1  -- 0: No speed, 1: Normal speed, 2: Fast speed
local playerStartX, playerStartY = TUNING.GAMEPLAY_ENTRY_BOAT_X, TUNING.GAMEPLAY_ENTRY_BOAT_Y
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
local dashCooldownDurationMilliseconds = getDashCooldownDuration()
local dashUiProgress = 1
local dashUiIsDraining = false
local speedometerNeedleAngle = TUNING.SPEEDOMETER_MIN_ANGLE
local hudSlideProgress = 0
local presentationElapsedMilliseconds = 0
local crashReturnDelayElapsedMilliseconds = 0
local waitingCrankMovement = 0
local startRotationAngle = 180
local launchVisualAngle = 180

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

-- pdc converts the colorful source PNG to Playdate's 1-bit format. Its alpha
-- channel leaves the lower river opening transparent so the water remains visible.
local mainMenuBackgroundSprite = pdg.sprite.new(mainMenuImages.background)
mainMenuBackgroundSprite:moveTo(200, TUNING.MAIN_MENU_BACKGROUND_CENTER_Y)
mainMenuBackgroundSprite:setZIndex(TUNING.MAIN_MENU_Z_INDEX)
mainMenuBackgroundSprite:add()

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
    if BoatGameState == GameState.ALIVE then
        worldVelocity = math.min(
            TUNING.MAX_WORLD_VELOCITY,
            worldVelocity * TUNING.WORLD_VELOCITY_GROWTH_MULTIPLIER
        )
        playerScoreStep += 10
    end
end)
velocityIncreaseTimer.repeats = true
velocityIncreaseTimer:pause()

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

local collectablesByType = {}
local collectableSpawnRemainingMilliseconds = {}
local collectableTypes <const> = { "coin", "shield", "shrink", "speedReduction" }

local function isCollectableAvailable(collectableType)
    return collectableType == "coin" or isAbilityPurchased(collectableType)
end

local function onCoinCollected()
    playerCoins += 1
    playSoundOneShot(coinPickupSoundPlayer)
    markProgressChanged()
    saveProgress()
end

local function onShieldCollected()
    if isAbilityPurchased("shield") == false then
        return
    end

    shieldHitsRemaining = math.min(
        TUNING.MAX_SHIELD_HITS,
        shieldHitsRemaining + TUNING.SHIELD_HITS_BY_LEVEL[shieldUpgradeLevel + 1]
    )
    playSoundOneShot(shieldSoundPlayer)
end

local function onShrinkCollected()
    if isAbilityPurchased("shrink") == false then
        return
    end

    shrinkDurationMilliseconds = TUNING.SHRINK_DURATION_MS_BY_LEVEL[shrinkUpgradeLevel + 1]
    targetPlayerScale = TUNING.SHRUNK_PLAYER_SCALE
    shrinkRemainingMilliseconds = shrinkDurationMilliseconds
    shrinkUiProgress = 0
    shrinkUiIsFilling = true
    playSoundOneShot(shrinkSoundPlayer)
end

local function onSpeedReductionCollected()
    if isAbilityPurchased("speedReduction") == false then
        return
    end

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
        elseif isCollectableAvailable(collectableType) then
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
                playSoundOneShot(shrinkReversedSoundPlayer)
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
    if isAbilityPurchased("dash") == false or dashCooldownRemainingMilliseconds > 0 then
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
    dashCooldownDurationMilliseconds = getDashCooldownDuration()
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
local upgradeMenuState = {
    progress = 0,
    closing = false,
    selectionIndex = 1,
    message = nil,
    messageRemainingMilliseconds = 0
}
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
        upgradePurchaseMenuItem:setTitle(label .. ": MAX")
    elseif level == TUNING.LOCKED_ABILITY_LEVEL then
        local cost = TUNING.ABILITY_PURCHASE_COSTS[selectedUpgradeAbility]
        upgradePurchaseMenuItem:setTitle("Buy " .. label .. " (" .. cost .. "c)")
    else
        local cost = TUNING.ABILITY_UPGRADE_COSTS[selectedUpgradeAbility][level + 1]
        upgradePurchaseMenuItem:setTitle(
            "Upgrade " .. label .. " L" .. (level + 1) .. " (" .. cost .. "c)"
        )
    end
end

local function purchaseAbilityUpgrade(abilityType)
    local level = getAbilityUpgradeLevel(abilityType)

    if level >= TUNING.MAX_ABILITY_UPGRADE_LEVEL then
        playSoundOneShot(noUpgradeSoundPlayer)
        return false, nil
    end

    local isPurchase = level == TUNING.LOCKED_ABILITY_LEVEL
    local cost
    local nextLevel

    if isPurchase then
        cost = TUNING.ABILITY_PURCHASE_COSTS[abilityType]
        nextLevel = 0
    else
        cost = TUNING.ABILITY_UPGRADE_COSTS[abilityType][level + 1]
        nextLevel = level + 1
    end

    if playerCoins < cost then
        playSoundOneShot(noUpgradeSoundPlayer)
        return false, nil
    end

    playerCoins -= cost
    setAbilityUpgradeLevel(abilityType, nextLevel)

    if abilityType == "dash" and dashCooldownRemainingMilliseconds <= 0 then
        dashCooldownDurationMilliseconds = getDashCooldownDuration()
    end

    markProgressChanged()
    saveProgress()
    refreshUpgradeMenuTitles()

    if isPurchase then
        playSoundOneShot(buyAbilitySoundPlayer)
    else
        playSoundOneShot(upgradeAbilitySoundPlayers[nextLevel])
    end

    return true, nil
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

local function drawDashChargeChevrons(currentVelocityAngle, drawWhiteBackground)
    local dashChargeProgress = 1
    local visibleChevronCount

    if dashCooldownRemainingMilliseconds > 0 then
        dashChargeProgress = 1
            - dashCooldownRemainingMilliseconds / dashCooldownDurationMilliseconds
        visibleChevronCount = math.min(
            TUNING.DIEGETIC_DASH_CHEVRON_COUNT - 1,
            math.floor(math.clamp(dashChargeProgress, 0, 1) * TUNING.DIEGETIC_DASH_CHEVRON_COUNT)
        )
    else
        -- The final arrow is reserved for the exact frame Dash becomes usable.
        visibleChevronCount = TUNING.DIEGETIC_DASH_CHEVRON_COUNT
    end

    if visibleChevronCount <= 0 then
        return
    end

    local angleRadians = math.rad(currentVelocityAngle - 5)
    local forwardX = math.sin(angleRadians)
    local forwardY = -math.cos(angleRadians)
    local rightX = math.cos(angleRadians)
    local rightY = math.sin(angleRadians)
    local indicatorRadiusScale = 0.5 + currentPlayerScale * 0.5
    local frontDistance = TUNING.DIEGETIC_DASH_FRONT_DISTANCE * indicatorRadiusScale

    for chevronIndex = 1, visibleChevronCount do
        -- Build the charge outward from the bow in fixed forward-facing slots.
        local distance = frontDistance
            + (chevronIndex - 1) * TUNING.DIEGETIC_DASH_CHEVRON_SPACING
        local centerX = playerX + forwardX * distance
        local centerY = playerY + forwardY * distance
        local tipX = centerX + forwardX * 2
        local tipY = centerY + forwardY * 2
        local baseX = centerX - forwardX * 2
        local baseY = centerY - forwardY * 2
        local sideX = rightX * TUNING.DIEGETIC_DASH_CHEVRON_HALF_WIDTH
        local sideY = rightY * TUNING.DIEGETIC_DASH_CHEVRON_HALF_WIDTH

        if drawWhiteBackground then
            local backgroundForwardX = forwardX * TUNING.DIEGETIC_DASH_BACKGROUND_HALF_LENGTH
            local backgroundForwardY = forwardY * TUNING.DIEGETIC_DASH_BACKGROUND_HALF_LENGTH
            local backgroundRightX = rightX * TUNING.DIEGETIC_DASH_BACKGROUND_HALF_WIDTH
            local backgroundRightY = rightY * TUNING.DIEGETIC_DASH_BACKGROUND_HALF_WIDTH

            pdg.fillPolygon(
                centerX + backgroundForwardX + backgroundRightX,
                centerY + backgroundForwardY + backgroundRightY,
                centerX + backgroundForwardX - backgroundRightX,
                centerY + backgroundForwardY - backgroundRightY,
                centerX - backgroundForwardX - backgroundRightX,
                centerY - backgroundForwardY - backgroundRightY,
                centerX - backgroundForwardX + backgroundRightX,
                centerY - backgroundForwardY + backgroundRightY
            )
        else
            pdg.drawLine(baseX + sideX, baseY + sideY, tipX, tipY)
            pdg.drawLine(baseX - sideX, baseY - sideY, tipX, tipY)
        end
    end
end

local function drawShrinkProgressArc(currentVelocityAngle)
    local progress = math.clamp(shrinkUiProgress, 0, 1)

    if progress <= 0 then
        return
    end

    local angleRadians = math.rad(currentVelocityAngle)
    local forwardX = math.sin(angleRadians)
    local forwardY = -math.cos(angleRadians)
    local rightX = math.cos(angleRadians)
    local rightY = math.sin(angleRadians)
    local radiusScale = 0.5 + currentPlayerScale * 0.5
    local majorRadius = TUNING.DIEGETIC_SHRINK_ARC_MAJOR_RADIUS * radiusScale
    local minorRadius = TUNING.DIEGETIC_SHRINK_ARC_MINOR_RADIUS * radiusScale
    local segmentCount = TUNING.DIEGETIC_SHRINK_ARC_SEGMENT_COUNT
    local completedSegments = progress * segmentCount
    local endInset = math.rad(TUNING.DIEGETIC_SHRINK_ARC_END_INSET_DEGREES)
    local arcStartAngle = math.pi + endInset
    local arcLength = math.pi - endInset * 2

    for segmentIndex = 1, math.ceil(completedSegments) do
        local segmentStart = (segmentIndex - 1) / segmentCount
        local segmentEnd = math.min(segmentIndex / segmentCount, progress)
        local startAngle = arcStartAngle + arcLength * segmentStart
        local endAngle = arcStartAngle + arcLength * segmentEnd
        local startForward = math.cos(startAngle) * majorRadius
        local startRight = math.sin(startAngle) * minorRadius
        local endForward = math.cos(endAngle) * majorRadius
        local endRight = math.sin(endAngle) * minorRadius

        pdg.drawLine(
            playerX + forwardX * startForward + rightX * startRight,
            playerY + forwardY * startForward + rightY * startRight,
            playerX + forwardX * endForward + rightX * endRight,
            playerY + forwardY * endForward + rightY * endRight
        )
    end
end

local function drawShieldStorage(currentVelocityAngle)
    if shieldHitsRemaining <= 0 then
        return
    end

    local angleRadians = math.rad(currentVelocityAngle)
    local forwardX = math.sin(angleRadians)
    local forwardY = -math.cos(angleRadians)
    local rightX = math.cos(angleRadians)
    local rightY = math.sin(angleRadians)
    local radiusScale = 0.5 + currentPlayerScale * 0.5
    local starboardDistance = TUNING.DIEGETIC_SHIELD_STARBOARD_DISTANCE * radiusScale
    local iconCount = math.min(shieldHitsRemaining, 3)
    local extraRingCharges = math.max(0, math.min(shieldHitsRemaining, 9) - 3)
    local shieldImageWidth, shieldImageHeight = shieldCollectableImage:getSize()
    local previousImageDrawMode = pdg.getImageDrawMode()
    local previousLineWidth = pdg.getLineWidth()
    local previousColor = pdg.getColor()

    pdg.setImageDrawMode(pdg.kDrawModeCopy)

    for iconIndex = 1, iconCount do
        local forwardOffset = 0
        local iconSpacing = TUNING.DIEGETIC_SHIELD_ICON_SPACING

        if shieldHitsRemaining >= TUNING.MAX_SHIELD_HITS then
            iconSpacing = TUNING.DIEGETIC_SHIELD_FULL_ICON_SPACING
        end

        if iconCount == 2 then
            forwardOffset = (iconIndex - 1.5) * iconSpacing
        elseif iconCount == 3 then
            forwardOffset = (iconIndex - 2) * iconSpacing
        end

        local centerX = playerX + rightX * starboardDistance + forwardX * forwardOffset
        local centerY = playerY + rightY * starboardDistance + forwardY * forwardOffset
        local shieldIconScale = TUNING.DIEGETIC_SHIELD_ICON_SCALE

        if shieldHitsRemaining >= TUNING.MAX_SHIELD_HITS and iconIndex == 2 then
            shieldIconScale = TUNING.DIEGETIC_SHIELD_FULL_CENTER_ICON_SCALE
        end

        local ringCount = math.floor(extraRingCharges / 3)
        local partialRingCount = extraRingCharges % 3

        -- Add partial rounds center-first, then aft, then forward.
        if partialRingCount >= 1 and iconIndex == 2 then
            ringCount += 1
        elseif partialRingCount >= 2 and iconIndex == 1 then
            ringCount += 1
        end

        for ringIndex = 1, ringCount do
            local ringRadius = shieldImageWidth * shieldIconScale / 2
                + TUNING.DIEGETIC_SHIELD_RING_GAP
                + (ringIndex - 1) * TUNING.DIEGETIC_SHIELD_RING_SPACING

            pdg.setColor(pdg.kColorWhite)
            pdg.setLineWidth(3)
            pdg.drawCircleAtPoint(centerX, centerY, ringRadius)
            pdg.setColor(pdg.kColorBlack)
            pdg.setLineWidth(1)
            pdg.drawCircleAtPoint(centerX, centerY, ringRadius)
        end

        shieldCollectableImage:drawScaled(
            math.floor(centerX - shieldImageWidth * shieldIconScale / 2 + 0.5),
            math.floor(centerY - shieldImageHeight * shieldIconScale / 2 + 0.5)
                + TUNING.DIEGETIC_SHIELD_IMAGE_Y_OFFSET,
            shieldIconScale
        )
    end

    pdg.setImageDrawMode(previousImageDrawMode)
    pdg.setLineWidth(previousLineWidth)
    pdg.setColor(previousColor)
end

local function drawDiegeticAbilities(currentVelocityAngle)
    local previousLineWidth = pdg.getLineWidth()
    local previousColor = pdg.getColor()

    pdg.setColor(pdg.kColorWhite)

    if isAbilityPurchased("dash") then
        -- Solid white backing plates prevent the water texture from crossing Dash arrows.
        drawDashChargeChevrons(currentVelocityAngle, true)
    end

    if isAbilityPurchased("shrink") then
        -- The wider white line keeps the curved Shrink bar readable over the world.
        pdg.setLineWidth(TUNING.DIEGETIC_SHRINK_ARC_BACKGROUND_LINE_WIDTH)
        drawShrinkProgressArc(currentVelocityAngle)
    end

    pdg.setColor(pdg.kColorBlack)

    if isAbilityPurchased("dash") then
        pdg.setLineWidth(TUNING.DIEGETIC_DASH_LINE_WIDTH)
        drawDashChargeChevrons(currentVelocityAngle, false)
    end

    if isAbilityPurchased("shrink") then
        pdg.setLineWidth(TUNING.DIEGETIC_SHRINK_ARC_LINE_WIDTH)
        drawShrinkProgressArc(currentVelocityAngle)
    end

    -- Shield storage uses the recognizable collectable art at a smaller scale.
    drawShieldStorage(currentVelocityAngle)

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

local fixedWidthDigitCellWidth = 0

for digit = 0, 9 do
    local digitWidth = pdg.getTextSize(tostring(digit))
    fixedWidthDigitCellWidth = math.max(fixedWidthDigitCellWidth, digitWidth)
end

local function getFixedWidthNumberWidth(numberText)
    return string.len(numberText) * (fixedWidthDigitCellWidth + 1)
end

local function drawFixedWidthNumber(numberText, x, y)
    local digitCenterX = x + math.floor(fixedWidthDigitCellWidth / 2)

    for digitIndex = 1, string.len(numberText) do
        pdg.drawTextAligned(
            string.sub(numberText, digitIndex, digitIndex),
            digitCenterX,
            y,
            kTextAlignment.center
        )
        digitCenterX += fixedWidthDigitCellWidth + 1
    end
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
    local easedHudProgress = hudSlideProgress * hudSlideProgress * (3 - 2 * hudSlideProgress)
    local hiddenHudProgress = 1 - easedHudProgress
    local leftHudOffsetX = math.floor(TUNING.HUD_LEFT_HIDDEN_OFFSET_X * hiddenHudProgress + 0.5)
    local rightHudOffsetX = math.floor(TUNING.HUD_RIGHT_HIDDEN_OFFSET_X * hiddenHudProgress + 0.5)
    local speedometerX = 2 + leftHudOffsetX
    local speedometerY <const> = 2
    local speedometerWidth, speedometerHeight = speedometerImage:getSize()

    backgroundHUDImage:draw(rightHudOffsetX, 0)
    speedometerImage:draw(speedometerX, speedometerY)
    speedometerNeedleImage:drawRotated(
        speedometerX + speedometerWidth / 2,
        speedometerY + speedometerHeight / 2,
        speedometerNeedleAngle
    )

    if selectedUiMode == UI_MODE_OPTIONS[1] or selectedUiMode == UI_MODE_OPTIONS[3] then
        AbilityTopUI.draw(
            dashUiProgress,
            dashCooldownRemainingMilliseconds <= 0,
            shrinkUiProgress,
            shieldHitsRemaining,
            isAbilityPurchased("dash"),
            isAbilityPurchased("shrink"),
            TUNING,
            leftHudOffsetX
        )
    end

    local scoreText = tostring(playerScore)
    local scoreLength = string.len(scoreText)
    local emptyNumberDigits = 7 - scoreLength

    for i = 1, emptyNumberDigits, 1 do
        scoreText = "0" .. scoreText
    end

    local scoreTextWidth = getFixedWidthNumberWidth(scoreText)
    local scoreX = 400 - scoreTextWidth - 2 + rightHudOffsetX
    local starImageWidth = starImage:getSize()
    local starX = 400 - scoreTextWidth - starImageWidth - 5 + rightHudOffsetX

    local coinText = tostring(playerCoins)
    emptyNumberDigits = 3 - string.len(coinText)

    for i = 1, emptyNumberDigits, 1 do
        coinText = "0" .. coinText
    end

    local coinTextWidth = getFixedWidthNumberWidth(coinText)
    local coinImage = coinImagetable:getImage(1)
    local coinImageWidth = coinImage:getSize()
    local coinTextX = 400 - coinTextWidth - 2 + rightHudOffsetX
    local coinX = coinTextX - coinImageWidth - 3
    local previousColor = pdg.getColor()

    pdg.setColor(pdg.kColorBlack)
    drawFixedWidthNumber(scoreText, scoreX, 6)
    starImage:draw(starX, 2)

    drawFixedWidthNumber(coinText, coinTextX, 27)
    coinImage:draw(coinX, 25)
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

local function setWaterTransform(scrollX, centerY)
    waterScrollX = scrollX % waterImageWidth
    waterSprites[1]:moveTo(waterScrollX, centerY)
    waterSprites[2]:moveTo(waterScrollX - waterImageWidth, centerY)
end

local function hideGameplayWorld()
    clearWakeLines()
    resetCollectables()
    decorationManager:reset()
    clearRockExplosions()

    for i = 1, TUNING.MAX_ROCKS do
        rockSprites[i].active = false
        rockSprites[i]:setVisible(false)
    end
end

local function rewindGameplayWorld(elapsedMilliseconds, displacement)
    local remainingObjectCount = 0

    for i = 1, TUNING.MAX_ROCKS do
        local rock = rockSprites[i]

        if rock.active then
            rock:moveBy(displacement, 0)

            if rock.x + rock.imageWidth / 2 < 0 then
                rock.active = false
                rock:setVisible(false)
            else
                remainingObjectCount += 1
            end
        end
    end

    for i = 1, #collectableSprites do
        local collectable = collectableSprites[i]

        if collectable.active then
            collectable:moveBy(displacement, 0)

            if collectable.x + collectable.imageWidth / 2 < 0 then
                collectable:despawn()
            else
                remainingObjectCount += 1
            end
        end
    end

    for i = 1, #decorationSprites do
        local decoration = decorationSprites[i]

        if decoration.active then
            decoration:moveBy(displacement, 0)

            if decoration.x + decoration.imageWidth / 2 < 0 then
                decoration.active = false
                decoration:setVisible(false)
                decoration:remove()
            else
                remainingObjectCount += 1
            end
        end
    end

    updateRockExplosions(elapsedMilliseconds, displacement)
    explosionX += displacement
    return remainingObjectCount
end

local function prepareNewRun()
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
    dashCooldownDurationMilliseconds = getDashCooldownDuration()
    dashUiProgress = 1
    dashUiIsDraining = false
    speedometerNeedleAngle = TUNING.SPEEDOMETER_MIN_ANGLE
    hudSlideProgress = 0
    launchVisualAngle = 180
    boatEngineSoundRate = TUNING.ENGINE_MIN_WORLD_RATE
    boatEngineSoundVolume = TUNING.ENGINE_NORMAL_VOLUME
    waterFlowSoundRate = TUNING.WATER_FLOW_MIN_RATE
    gameMusicRate = TUNING.MUSIC_NORMAL_RATE
    musicPlayers.gameplay:stop()
    crashReturnDelayElapsedMilliseconds = 0

    scoreTimer:reset()
    velocityIncreaseTimer:reset()
    velocityIncreaseTimer:pause()
    stopGameplayLoopSounds()

    playerSprite:setVisible(true)
    playerSprite:setScale(1)
    playerSprite:setCollideRect(
        playerCollisionX,
        playerCollisionY,
        playerCollisionWidth,
        playerCollisionHeight
    )
    playerSprite:moveTo(playerX, playerY)
    hideGameplayWorld()
    resetExplosion()
end

local function enterMainMenu()
    prepareNewRun()
    BoatGameState = GameState.MAIN_MENU
    presentationElapsedMilliseconds = 0
    waitingCrankMovement = 0

    mainMenuBackgroundSprite:setVisible(true)
    mainMenuBackgroundSprite:moveTo(200, TUNING.MAIN_MENU_BACKGROUND_CENTER_Y)
    setWaterTransform(waterScrollX, TUNING.MAIN_MENU_WATER_CENTER_Y)

    playerX = TUNING.MAIN_MENU_BOAT_X
    playerY = TUNING.MAIN_MENU_BOAT_Y
    playerSprite:setImage(playerImagetable:getImage(TUNING.MAIN_MENU_BOAT_FRAME_INDEX))
    playerSprite:moveTo(playerX, playerY)
    startMenuMusic()
end

local function startLaunchTransition()
    BoatGameState = GameState.LAUNCHING
    presentationElapsedMilliseconds = 0
    launchVisualAngle = 180
    clearWakeLines()
    startBoatEngineSound()
    startWaterFlowSound()
    startMenuMusic()
end

local function beginWaitingForCrank()
    BoatGameState = GameState.WAITING_FOR_CRANK
    presentationElapsedMilliseconds = 0
    hudSlideProgress = 0
    waitingCrankMovement = 0
    mainMenuBackgroundSprite:setVisible(false)
    setWaterTransform(waterScrollX, TUNING.WATER_BACKGROUND_Y_OFFSET)
    playerX = TUNING.GAMEPLAY_ENTRY_BOAT_X
    playerY = TUNING.GAMEPLAY_ENTRY_BOAT_Y
    playerSprite:moveTo(playerX, playerY)
    startBoatEngineSound()
    startWaterFlowSound()
    startMenuMusic()
end

local function beginStartRotation()
    BoatGameState = GameState.ALIGNING_TO_CRANK
    presentationElapsedMilliseconds = 0
    startRotationAngle = launchVisualAngle
    startGameplayLoopSounds()
end

local function beginGameplay()
    BoatGameState = GameState.ALIVE
    scoreTimer:reset()
    velocityIncreaseTimer:reset()
    velocityIncreaseTimer:start()

    for i = 1, TUNING.MAX_ROCKS do
        resetRockPosition(rockSprites[i])
    end

    lastUpdateTimeMilliseconds = pd.getCurrentTimeMilliseconds()
    startGameplayLoopSounds()
end

local function beginReturnToMenu()
    BoatGameState = GameState.RETURNING_TO_MENU
    presentationElapsedMilliseconds = 0
    hideGameplayWorld()
    resetExplosion()
    stopBoatEngineSound()
    stopWaterFlowSound()

    mainMenuBackgroundSprite:setVisible(true)
    mainMenuBackgroundSprite:moveTo(200, TUNING.MAIN_MENU_BACKGROUND_OFFSCREEN_Y)
    playerSprite:setVisible(true)
    playerSprite:setScale(1)
    playerSprite:setImage(playerImagetable:getImage(TUNING.MAIN_MENU_BOAT_FRAME_INDEX))
    playerSpeedMode = 1
    playerX = TUNING.MAIN_MENU_BOAT_X
    playerY = TUNING.MAIN_MENU_BACKGROUND_OFFSCREEN_Y
        - TUNING.MAIN_MENU_BACKGROUND_CENTER_Y
        + TUNING.MAIN_MENU_BOAT_Y
    playerSprite:moveTo(playerX, playerY)
    startMenuMusic()
end

local function smoothstep(progress)
    local clampedProgress = math.clamp(progress, 0, 1)
    return clampedProgress * clampedProgress * (3 - 2 * clampedProgress)
end

enterMainMenu()

function playdate.crankDocked()
    velocityIncreaseTimer:pause()

    if BoatGameState == GameState.ALIVE then
        stopGameplayLoopSounds()
    else
        stopBoatEngineSound()
        stopWaterFlowSound()
    end
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
    elseif BoatGameState == GameState.ALIGNING_TO_CRANK then
        startGameplayLoopSounds()
    elseif BoatGameState == GameState.LAUNCHING then
        startBoatEngineSound()
        startWaterFlowSound()
        startMenuMusic()
    elseif BoatGameState ~= GameState.CRASH_REWIND
        or crashReturnDelayElapsedMilliseconds >= TUNING.CRASH_RETURN_DELAY_MS
    then
        startMenuMusic()
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

    if BoatGameState == GameState.WAITING_FOR_CRANK
        or BoatGameState == GameState.ALIGNING_TO_CRANK
        or BoatGameState == GameState.ALIVE
    then
        hudSlideProgress = math.min(
            1,
            hudSlideProgress + elapsedMilliseconds / TUNING.HUD_SLIDE_DURATION_MS
        )
    elseif BoatGameState == GameState.CRASH_REWIND then
        hudSlideProgress = math.max(
            0,
            hudSlideProgress - elapsedMilliseconds / TUNING.HUD_SLIDE_DURATION_MS
        )
    end

    if BoatGameState == GameState.UPGRADE_MENU then
        stopBoatEngineSound()
        stopWaterFlowSound()
        startMenuMusic()

        local initialWorldDisplacement = math.max(
            TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
            math.floor(TUNING.INITIAL_WORLD_VELOCITY + 0.5)
        )
        setWaterTransform(
            waterScrollX + initialWorldDisplacement,
            TUNING.MAIN_MENU_WATER_CENTER_Y
        )

        if upgradeMenuState.closing then
            upgradeMenuState.progress = math.max(
                0,
                upgradeMenuState.progress
                    - elapsedMilliseconds / TUNING.UPGRADE_MENU_SLIDE_DURATION_MS
            )
        else
            upgradeMenuState.progress = math.min(
                1,
                upgradeMenuState.progress
                    + elapsedMilliseconds / TUNING.UPGRADE_MENU_SLIDE_DURATION_MS
            )
        end

        if upgradeMenuState.messageRemainingMilliseconds > 0 then
            upgradeMenuState.messageRemainingMilliseconds -= elapsedMilliseconds
            if upgradeMenuState.messageRemainingMilliseconds <= 0 then
                upgradeMenuState.message = nil
            end
        end

        if upgradeMenuState.progress >= 1 and upgradeMenuState.closing == false then
            if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then
                upgradeMenuState.selectionIndex -= 1

                if upgradeMenuState.selectionIndex < 1 then
                    upgradeMenuState.selectionIndex = #UpgradeMenuUI.ABILITIES
                end

                upgradeMenuState.message = nil
                playSoundOneShot(selectAbilitySoundPlayer)
            elseif pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then
                upgradeMenuState.selectionIndex = upgradeMenuState.selectionIndex
                    % #UpgradeMenuUI.ABILITIES + 1
                upgradeMenuState.message = nil
                playSoundOneShot(selectAbilitySoundPlayer)
            end

            local selectedAbility = UpgradeMenuUI.ABILITIES[upgradeMenuState.selectionIndex]
            selectedUpgradeAbility = selectedAbility.type

            if pd.buttonJustPressed(pd.kButtonA) then
                local _, purchaseMessage = purchaseAbilityUpgrade(selectedAbility.type)
                upgradeMenuState.message = purchaseMessage
                upgradeMenuState.messageRemainingMilliseconds =
                    TUNING.UPGRADE_MENU_MESSAGE_DURATION_MS
            elseif pd.buttonJustPressed(pd.kButtonB) then
                upgradeMenuState.closing = true
                upgradeMenuState.message = nil
                playSoundOneShot(closeUpgradeMenuSoundPlayer)
            end
        end

        pdg.sprite.update()
        mainMenuImages.hud:draw(0, 0)
        pdg.drawText("Start", TUNING.MAIN_MENU_START_TEXT_X, TUNING.MAIN_MENU_START_TEXT_Y)
        pdg.drawText("Upgrade", TUNING.MAIN_MENU_UPGRADE_TEXT_X, TUNING.MAIN_MENU_UPGRADE_TEXT_Y)

        UpgradeMenuUI.update(elapsedMilliseconds)
        local upgradeMenuProgress = smoothstep(upgradeMenuState.progress)
        UpgradeMenuUI.draw(
            math.floor(-240 * (1 - upgradeMenuProgress)),
            upgradeMenuState.selectionIndex,
            {
                dash = dashUpgradeLevel,
                shield = shieldUpgradeLevel,
                shrink = shrinkUpgradeLevel,
                speedReduction = speedReductionUpgradeLevel
            },
            playerCoins,
            upgradeMenuState.message,
            TUNING
        )

        if upgradeMenuState.closing and upgradeMenuState.progress <= 0 then
            BoatGameState = GameState.MAIN_MENU
            upgradeMenuState.closing = false
        end

        return
    end

    if BoatGameState == GameState.MAIN_MENU then
        stopBoatEngineSound()
        stopWaterFlowSound()
        startMenuMusic()
        local initialWorldDisplacement = math.max(
            TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
            math.floor(TUNING.INITIAL_WORLD_VELOCITY + 0.5)
        )
        setWaterTransform(
            waterScrollX + initialWorldDisplacement,
            TUNING.MAIN_MENU_WATER_CENTER_Y
        )
        pdg.sprite.update()
        mainMenuImages.hud:draw(0, 0)
        pdg.drawText("Start", TUNING.MAIN_MENU_START_TEXT_X, TUNING.MAIN_MENU_START_TEXT_Y)
        pdg.drawText("Upgrade", TUNING.MAIN_MENU_UPGRADE_TEXT_X, TUNING.MAIN_MENU_UPGRADE_TEXT_Y)

        if pd.buttonJustPressed(pd.kButtonA) then
            startLaunchTransition()
        elseif pd.buttonJustPressed(pd.kButtonB) then
            BoatGameState = GameState.UPGRADE_MENU
            upgradeMenuState.progress = 0
            upgradeMenuState.closing = false
            upgradeMenuState.message = nil
            playSoundOneShot(openUpgradeMenuSoundPlayer)
        end

        return
    end

    if BoatGameState == GameState.LAUNCHING then
        startBoatEngineSound()
        startWaterFlowSound()
        presentationElapsedMilliseconds += elapsedMilliseconds
        local transitionProgress = smoothstep(
            presentationElapsedMilliseconds / TUNING.MENU_LAUNCH_DURATION_MS
        )
        local menuY = TUNING.MAIN_MENU_BACKGROUND_CENTER_Y
            + (TUNING.MAIN_MENU_BACKGROUND_OFFSCREEN_Y
                - TUNING.MAIN_MENU_BACKGROUND_CENTER_Y) * transitionProgress
        local waterY = TUNING.MAIN_MENU_WATER_CENTER_Y
            + (TUNING.WATER_BACKGROUND_Y_OFFSET
                - TUNING.MAIN_MENU_WATER_CENTER_Y) * transitionProgress

        local initialWorldDisplacement = math.max(
            TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
            math.floor(TUNING.INITIAL_WORLD_VELOCITY + 0.5)
        )
        local curve = TUNING.MENU_LAUNCH_CURVE
        local curveProgress
        local inverseCurveProgress
        local launchVelocityX
        local launchVelocityY

        if transitionProgress < curve.SPLIT then
            curveProgress = transitionProgress / curve.SPLIT
            inverseCurveProgress = 1 - curveProgress
            playerX = inverseCurveProgress ^ 3 * TUNING.MAIN_MENU_BOAT_X
                + 3 * inverseCurveProgress ^ 2 * curveProgress * curve.FIRST_CONTROL_X
                + 3 * inverseCurveProgress * curveProgress ^ 2 * curve.TURN_CONTROL_X
                + curveProgress ^ 3 * curve.TURN_X
            playerY = inverseCurveProgress ^ 3 * TUNING.MAIN_MENU_BOAT_Y
                + 3 * inverseCurveProgress ^ 2 * curveProgress * curve.FIRST_CONTROL_Y
                + 3 * inverseCurveProgress * curveProgress ^ 2 * curve.TURN_CONTROL_Y
                + curveProgress ^ 3 * curve.TURN_Y
            launchVelocityX = 3 * inverseCurveProgress ^ 2
                    * (curve.FIRST_CONTROL_X - TUNING.MAIN_MENU_BOAT_X)
                + 6 * inverseCurveProgress * curveProgress
                    * (curve.TURN_CONTROL_X - curve.FIRST_CONTROL_X)
                + 3 * curveProgress ^ 2 * (curve.TURN_X - curve.TURN_CONTROL_X)
            launchVelocityY = 3 * inverseCurveProgress ^ 2
                    * (curve.FIRST_CONTROL_Y - TUNING.MAIN_MENU_BOAT_Y)
                + 6 * inverseCurveProgress * curveProgress
                    * (curve.TURN_CONTROL_Y - curve.FIRST_CONTROL_Y)
                + 3 * curveProgress ^ 2 * (curve.TURN_Y - curve.TURN_CONTROL_Y)
        else
            curveProgress = (transitionProgress - curve.SPLIT) / (1 - curve.SPLIT)
            inverseCurveProgress = 1 - curveProgress
            playerX = inverseCurveProgress ^ 3 * curve.TURN_X
                + 3 * inverseCurveProgress ^ 2 * curveProgress * curve.SECOND_CONTROL_X
                + 3 * inverseCurveProgress * curveProgress ^ 2 * curve.FINAL_CONTROL_X
                + curveProgress ^ 3 * TUNING.GAMEPLAY_ENTRY_BOAT_X
            playerY = inverseCurveProgress ^ 3 * curve.TURN_Y
                + 3 * inverseCurveProgress ^ 2 * curveProgress * curve.SECOND_CONTROL_Y
                + 3 * inverseCurveProgress * curveProgress ^ 2 * curve.FINAL_CONTROL_Y
                + curveProgress ^ 3 * TUNING.GAMEPLAY_ENTRY_BOAT_Y
            launchVelocityX = 3 * inverseCurveProgress ^ 2
                    * (curve.SECOND_CONTROL_X - curve.TURN_X)
                + 6 * inverseCurveProgress * curveProgress
                    * (curve.FINAL_CONTROL_X - curve.SECOND_CONTROL_X)
                + 3 * curveProgress ^ 2 * (TUNING.GAMEPLAY_ENTRY_BOAT_X - curve.FINAL_CONTROL_X)
            launchVelocityY = 3 * inverseCurveProgress ^ 2
                    * (curve.SECOND_CONTROL_Y - curve.TURN_Y)
                + 6 * inverseCurveProgress * curveProgress
                    * (curve.FINAL_CONTROL_Y - curve.SECOND_CONTROL_Y)
                + 3 * curveProgress ^ 2 * (TUNING.GAMEPLAY_ENTRY_BOAT_Y - curve.FINAL_CONTROL_Y)
        end

        local launchTargetAngle = math.normalizeAngle(
            math.deg(math.atan2(launchVelocityY, launchVelocityX)) + 90
        )
        if transitionProgress >= curve.FINAL_ROTATION_START then
            local finalRotationProgress = smoothstep(
                (transitionProgress - curve.FINAL_ROTATION_START)
                    / (1 - curve.FINAL_ROTATION_START)
            )
            local finalRotationDelta = (TUNING.GAMEPLAY_ENTRY_BOAT_ANGLE
                - launchTargetAngle + 180) % 360 - 180
            launchTargetAngle = math.normalizeAngle(
                launchTargetAngle + finalRotationDelta * finalRotationProgress
            )
        end

        local launchRotationDelta = (launchTargetAngle - launchVisualAngle + 180) % 360 - 180
        local launchRotationInterpolation = 1 - math.exp(
            -TUNING.MENU_BOAT_ROTATION_RESPONSE_PER_SECOND * elapsedMilliseconds / 1000
        )
        launchVisualAngle = math.normalizeAngle(
            launchVisualAngle + launchRotationDelta * launchRotationInterpolation
        )
        local launchFrameIndex = math.clamp(
            math.ceil(launchVisualAngle / 7.5),
            1,
            playerImagetableSize
        )

        mainMenuBackgroundSprite:moveTo(200, menuY)
        setWaterTransform(waterScrollX + initialWorldDisplacement, waterY)
        playerSprite:setImage(playerImagetable:getImage(launchFrameIndex))
        playerSprite:moveTo(playerX, playerY)
        updateWakeLines(
            launchVisualAngle,
            launchFrameIndex,
            false,
            initialWorldDisplacement
        )
        pdg.sprite.update()
        drawWakeLines()

        if presentationElapsedMilliseconds >= TUNING.MENU_LAUNCH_DURATION_MS then
            beginWaitingForCrank()
        end

        return
    end

    if BoatGameState == GameState.WAITING_FOR_CRANK then
        velocityIncreaseTimer:pause()
        startBoatEngineSound()
        startWaterFlowSound()
        startMenuMusic()
        local initialWorldDisplacement = math.max(
            TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
            math.floor(TUNING.INITIAL_WORLD_VELOCITY + 0.5)
        )
        setWaterTransform(
            waterScrollX + initialWorldDisplacement,
            TUNING.WATER_BACKGROUND_Y_OFFSET
        )
        waitingCrankMovement += math.abs(pd.getCrankChange())
        local waitingRotationDelta = (TUNING.GAMEPLAY_ENTRY_BOAT_ANGLE
            - launchVisualAngle + 180) % 360 - 180
        local waitingRotationInterpolation = 1 - math.exp(
            -TUNING.MENU_BOAT_ROTATION_RESPONSE_PER_SECOND * elapsedMilliseconds / 1000
        )
        launchVisualAngle = math.normalizeAngle(
            launchVisualAngle + waitingRotationDelta * waitingRotationInterpolation
        )
        local waitingFrameIndex = math.clamp(
            math.ceil(launchVisualAngle / 7.5),
            1,
            playerImagetableSize
        )
        playerSprite:setImage(playerImagetable:getImage(waitingFrameIndex))
        updateWakeLines(
            launchVisualAngle,
            waitingFrameIndex,
            false,
            initialWorldDisplacement
        )
        pdg.sprite.update()
        drawWakeLines()
        drawHud()
        pd.ui.crankIndicator:draw()

        if pd.isCrankDocked() == false
            and waitingCrankMovement >= TUNING.START_CRANK_MOVEMENT_DEGREES
        then
            beginStartRotation()
        end

        return
    end

    if BoatGameState == GameState.ALIGNING_TO_CRANK then
        startGameplayLoopSounds()
        presentationElapsedMilliseconds += elapsedMilliseconds
        local rotationProgress = smoothstep(
            presentationElapsedMilliseconds / TUNING.START_ROTATION_DURATION_MS
        )
        local targetRotationAngle = pd.getCrankPosition()
        local rotationDelta = (targetRotationAngle - startRotationAngle + 180) % 360 - 180
        local currentRotationAngle = math.normalizeAngle(
            startRotationAngle + rotationDelta * rotationProgress
        )
        local playerFrameIndex = math.clamp(
            math.ceil(currentRotationAngle / 7.5),
            1,
            playerImagetableSize
        )
        local initialWorldDisplacement = math.max(
            TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
            math.floor(TUNING.INITIAL_WORLD_VELOCITY + 0.5)
        )

        setWaterTransform(
            waterScrollX + initialWorldDisplacement,
            TUNING.WATER_BACKGROUND_Y_OFFSET
        )
        playerSprite:setImage(playerImagetable:getImage(playerFrameIndex))
        updateWakeLines(
            currentRotationAngle,
            playerFrameIndex,
            false,
            initialWorldDisplacement
        )
        pdg.sprite.update()
        drawWakeLines()
        drawHud()

        if presentationElapsedMilliseconds >= TUNING.START_ROTATION_DURATION_MS then
            beginGameplay()
        end

        return
    end

    if BoatGameState == GameState.CRASH_REWIND then
        presentationElapsedMilliseconds += elapsedMilliseconds
        crashReturnDelayElapsedMilliseconds += elapsedMilliseconds
        local rewindDisplacement = 0
        local crashDelayFinished = crashReturnDelayElapsedMilliseconds
            >= TUNING.CRASH_RETURN_DELAY_MS

        -- Freeze the world immediately after the crash. Once the pause ends,
        -- start the rewind and let every world element move together.
        if crashDelayFinished then
            startMenuMusic()
            local rewindElapsedMilliseconds = crashReturnDelayElapsedMilliseconds
                - TUNING.CRASH_RETURN_DELAY_MS
            local rewindSpeedProgress = smoothstep(
                rewindElapsedMilliseconds / TUNING.CRASH_REWIND_ACCELERATION_MS
            )
            rewindDisplacement = -TUNING.CRASH_REWIND_SPEED_PIXELS_PER_SECOND
                * rewindSpeedProgress * elapsedMilliseconds / 1000
        end

        local remainingObjectCount = rewindGameplayWorld(
            elapsedMilliseconds,
            rewindDisplacement
        )

        setWaterTransform(waterScrollX + rewindDisplacement, TUNING.WATER_BACKGROUND_Y_OFFSET)
        pdg.sprite.update()
        updateExplosion()
        drawHud()

        if crashDelayFinished and remainingObjectCount == 0 then
            beginReturnToMenu()
        end

        return
    end

    if BoatGameState == GameState.RETURNING_TO_MENU then
        presentationElapsedMilliseconds += elapsedMilliseconds
        local transitionProgress = smoothstep(
            presentationElapsedMilliseconds / TUNING.MENU_RETURN_DURATION_MS
        )
        local menuY = TUNING.MAIN_MENU_BACKGROUND_OFFSCREEN_Y
            + (TUNING.MAIN_MENU_BACKGROUND_CENTER_Y
                - TUNING.MAIN_MENU_BACKGROUND_OFFSCREEN_Y) * transitionProgress
        local waterY = TUNING.WATER_BACKGROUND_Y_OFFSET
            + (TUNING.MAIN_MENU_WATER_CENTER_Y
                - TUNING.WATER_BACKGROUND_Y_OFFSET) * transitionProgress

        local initialWorldDisplacement = math.max(
            TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
            math.floor(TUNING.INITIAL_WORLD_VELOCITY + 0.5)
        )

        mainMenuBackgroundSprite:moveTo(200, menuY)
        setWaterTransform(waterScrollX + initialWorldDisplacement, waterY)
        playerX = TUNING.MAIN_MENU_BOAT_X
        playerY = menuY - TUNING.MAIN_MENU_BACKGROUND_CENTER_Y + TUNING.MAIN_MENU_BOAT_Y
        playerSprite:moveTo(playerX, playerY)
        pdg.sprite.update()

        if presentationElapsedMilliseconds >= TUNING.MENU_RETURN_DURATION_MS then
            enterMainMenu()
        end

        return
    end

    -- Docking pauses only an active run; menu transitions remain available.
    if pd.isCrankDocked() then
        stopGameplayLoopSounds()
        pdg.sprite.update()
        drawHud()
        pd.ui.crankIndicator:draw()
        velocityIncreaseTimer:pause()
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
        TUNING.HUD_HEIGHT + playerImageHeight / 2,
        240 - scaledPlayerHeight / 3
    )
    playerSprite:moveTo(playerX, playerY)
    updateDashInertia(elapsedMilliseconds)

    local didCrash = handlePlayerCollisions(collisions, length)

    if didCrash then
        BoatGameState = GameState.CRASH_REWIND
        presentationElapsedMilliseconds = 0
        crashReturnDelayElapsedMilliseconds = 0
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
    elseif selectedUiMode == UI_MODE_OPTIONS[2] or selectedUiMode == UI_MODE_OPTIONS[3] then
        drawDiegeticAbilities(currentVelocityAngle)
    end

    drawHud()
end
