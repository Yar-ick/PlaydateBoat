import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank"
import "CoreLibs/animation"
import "CoreLibs/object"
import "CoreLibs/sprites"
import "code/Config/GameplayTuning"
import "code/World/InteractiveSpawn"
import "code/World/DecorationManager"
import "code/Collectables/Collectable"
import "code/Collectables/CoinCollectable"
import "code/Collectables/ShieldCollectable"
import "code/Collectables/ShrinkCollectable"
import "code/Collectables/GrowthCollectable"
import "code/Collectables/SpeedReductionCollectable"
import "code/Gameplay/BoatJump"
import "code/Gameplay/AbilityProgression"
import "code/Gameplay/Difficulty"
import "code/Gameplay/OtherSide"
import "code/Obstacles/Ramp"
import "code/Obstacles/Steamboat"
import "code/Obstacles/Whirlpool"
import "code/Gameplay/GameModes/GameMode"
import "code/Gameplay/GameModes/WakebreakerGameMode"
import "code/Gameplay/GameModes/TheOtherSideGameMode"
import "code/Gameplay/GameModes/GameModeRegistry"
import "code/Effects/LandingSplash"
import "code/Effects/ScoreFlyEffect"
import "code/Effects/ScreenShake"
import "code/Effects/WakeLayer"
import "code/Effects/FlightShadow"
import "code/UI/AbilityTopUI"
import "code/UI/FixedWidthNumber"
import "code/UI/DifficultyMenuUI"
import "code/UI/MainMenuHUDAnimation"
import "code/UI/MenuCrankNavigation"
import "code/UI/UpgradeMenuUI"
import "code/UI/WaitingControlsUI"

-- Localizing commonly used globals
local pd <const> = playdate
local pdg <const> = playdate.graphics
local pds <const> = playdate.sound
local TUNING <const> = GameplayTuning
local mainMenuActionFont = pdg.getFont(pdg.font.kVariantBold)

GameModes.initialize(TUNING)

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

local playerImagetable = GameModes.wakebreaker:getPlayerImagetable()
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
local growthCollectableImage = pdg.image.new("images/Growth")
local speedReductionCollectableImage = pdg.image.new("images/SpeedReductionNoFrame")

local selectAbilitySoundPlayer = pds.sampleplayer.new("sounds/SelectAbility")
local openUpgradeMenuSoundPlayer = pds.sampleplayer.new("sounds/OpenUpgradeMenu")
local closeUpgradeMenuSoundPlayer = pds.sampleplayer.new("sounds/CloseUpgradeMenu")
local startJourneySoundPlayer = pds.sampleplayer.new("sounds/StartJourney")
local rampSoundPlayers = {
    takeoff = pds.sampleplayer.new("sounds/RampTakeoff"),
    landing = pds.sampleplayer.new("sounds/WaterLanding"),
    success = pds.sampleplayer.new("sounds/AbilityUpgradeSuccess3"),
    impulse = pds.sampleplayer.new("sounds/Impulse"),
    impulsePickup = pds.sampleplayer.new("sounds/Impulse"),
    bigRockBounce = pds.sampleplayer.new("sounds/BigRockBounce")
}
rampSoundPlayers.success:setRate(TUNING.RAMP_SUCCESS_SOUND_RATE)
rampSoundPlayers.success:setVolume(TUNING.RAMP_SUCCESS_SOUND_VOLUME)
rampSoundPlayers.impulse:setVolume(TUNING.OTHER_SIDE_IMPULSE_SOUND_VOLUME)
rampSoundPlayers.impulsePickup:setVolume(TUNING.OTHER_SIDE_IMPULSE_PICKUP_SOUND_VOLUME)
rampSoundPlayers.impulsePickup:setRate(TUNING.OTHER_SIDE_IMPULSE_PICKUP_SOUND_RATE)
rampSoundPlayers.bigRockBounce:setVolume(TUNING.OTHER_SIDE_BIG_ROCK_BOUNCE_SOUND_VOLUME)
local buyAbilitySoundPlayer = pds.sampleplayer.new("sounds/AbilityPurchaseSuccess")
local noUpgradeSoundPlayer = pds.sampleplayer.new("sounds/NoUpgrade")
local upgradeAbilitySoundPlayers = {
    pds.sampleplayer.new("sounds/AbilityUpgradeSuccess1"),
    pds.sampleplayer.new("sounds/AbilityUpgradeSuccess2"),
    pds.sampleplayer.new("sounds/AbilityUpgradeSuccess3")
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
local menuMusicPlayer = pds.fileplayer.new("sounds/The Forgotten Grove")
local gameMusicRate = TUNING.MUSIC_NORMAL_RATE
local sfxChannel = pds.channel.new()
local musicChannel = pds.channel.new()
local rockExplosionSoundPlayers = {}
local rockExplosionSoundPlayerCursor = 1

sfxChannel:addSource(selectAbilitySoundPlayer)
sfxChannel:addSource(openUpgradeMenuSoundPlayer)
sfxChannel:addSource(closeUpgradeMenuSoundPlayer)
sfxChannel:addSource(startJourneySoundPlayer)
sfxChannel:addSource(rampSoundPlayers.takeoff)
sfxChannel:addSource(rampSoundPlayers.landing)
sfxChannel:addSource(rampSoundPlayers.success)
sfxChannel:addSource(rampSoundPlayers.impulse)
sfxChannel:addSource(rampSoundPlayers.impulsePickup)
sfxChannel:addSource(rampSoundPlayers.bigRockBounce)
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
musicChannel:addSource(menuMusicPlayer)
GameModes.addGameplayMusicSources(musicChannel)

for i = 1, 4 do
    rockExplosionSoundPlayers[i] = pds.sampleplayer.new("sounds/RockExplosion")
    sfxChannel:addSource(rockExplosionSoundPlayers[i])
end

local function playSoundOneShot(soundPlayer, startOffsetSeconds)
    if soundPlayer:isPlaying() then
        soundPlayer:stop()
    end

    soundPlayer:setOffset(startOffsetSeconds or 0)
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

local function resetBoatEngineSoundForCurrentMode()
    stopBoatEngineSound()
    boatEngineSoundRate = GameModes.active:getEngineInitialRate()
    boatEngineSoundVolume = GameModes.active:getEngineVolume(false)

    boatEngineSoundPlayer:setRate(boatEngineSoundRate)
    boatEngineSoundPlayer:setVolume(boatEngineSoundVolume)
end

local function updateBoatEngineSound(isFast, isShrunk, currentWorldVelocity)
    local targetRate = GameModes.active:getEngineTargetRate(
        isFast,
        isShrunk,
        currentWorldVelocity
    )
    local targetVolume = GameModes.active:getEngineVolume(isFast)

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
            / (Difficulty.getMaxWorldVelocity() - TUNING.MIN_WORLD_VELOCITY),
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
    GameModes.stopGameplayMusic()

    if menuMusicPlayer:isPlaying() == false then
        menuMusicPlayer:setRate(TUNING.MUSIC_NORMAL_RATE)
        menuMusicPlayer:setVolume(TUNING.MUSIC_VOLUME)
        menuMusicPlayer:play(0)
    end
end

local function startGameplayMusic()
    if menuMusicPlayer:isPlaying() then
        menuMusicPlayer:stop()
    end

    local gameplayMusic = GameModes.active:getGameplayMusicPlayer()
    GameModes.stopInactiveGameplayMusic()

    if gameplayMusic:isPlaying() == false then
        gameplayMusic:setRate(gameMusicRate)
        gameplayMusic:setVolume(TUNING.MUSIC_VOLUME)
        gameplayMusic:play(0)
    end
end

local function pauseGameMusic()
    if menuMusicPlayer:isPlaying() then
        menuMusicPlayer:pause()
    end

    GameModes.pauseGameplayMusic()
end

local function updateGameMusic(currentWorldVelocity)
    local velocityProgress = math.clamp(
        (currentWorldVelocity - TUNING.INITIAL_WORLD_VELOCITY)
            / (Difficulty.getMaxWorldVelocity() - TUNING.INITIAL_WORLD_VELOCITY),
        0,
        1
    )
    local targetRate = TUNING.MUSIC_NORMAL_RATE
        + (TUNING.MUSIC_MAX_RATE - TUNING.MUSIC_NORMAL_RATE) * velocityProgress

    gameMusicRate +=
        (targetRate - gameMusicRate) * TUNING.MUSIC_RATE_INTERPOLATION_SPEED
    GameModes.setGameplayMusicRate(gameMusicRate)
end

local function startGameplayLoopSounds()
    startBoatEngineSound()
    startWaterFlowSound()
    startGameplayMusic()
    Steamboat.resumeSounds()
    Whirlpool.resumeSounds()
end

local function stopGameplayLoopSounds()
    stopBoatEngineSound()
    stopWaterFlowSound()
    pauseGameMusic()
    Steamboat.stopSounds()
    OtherSide.stopSounds()
    Whirlpool.stopSounds()
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

AbilityProgression.initialize(savedProgress, TUNING)
Difficulty.setSecretModeUnlocked(AbilityProgression.areRegularAbilitiesMaxed())
Difficulty.initialize(savedProgress, TUNING)
GameModes.refreshActiveMode()

local function isAbilityPurchased(abilityType)
    return GameModes.active:isAbilityPurchased(abilityType)
end

local function getDashCooldownDuration()
    return GameModes.active:getPrimaryCooldownDuration()
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

    local abilityProgress = AbilityProgression.getSaveData()
    local progress = {
        coins = abilityProgress.coins,
        audioMode = selectedAudioMode,
        uiMode = selectedUiMode,
        difficulty = Difficulty.getSaveData(),
        upgrades = abilityProgress.upgrades,
        otherSide = abilityProgress.otherSide
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
end)

pd.getSystemMenu():addOptionsMenuItem("UI", UI_MODE_OPTIONS, selectedUiMode, function(newUiMode)
    selectedUiMode = newUiMode
    markProgressChanged()
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
local menuBoatFloatElapsedMilliseconds = 0
local menuVesselSwap = {
    displayedMode = GameModes.wakebreaker,
    targetMode = GameModes.wakebreaker,
    elapsedMilliseconds = TUNING.MAIN_MENU_VESSEL_SWAP_DURATION_MS,
    active = false
}
local launchStartX = 0
local launchStartY = 0
GameplayProgress = {
    suspended = true,
    impulseCharge = 0,
    hornActiveRemainingMilliseconds = 0,
    waitingControlsSlideProgress = 0,
    waitingControlsExitStarted = false
}

local scoreTimer = pd.timer.new(1000, function()
    if GameplayProgress.suspended == false
        and BoatGameState == GameState.ALIVE
        and pd.isCrankDocked() == false
        and GameModes.active:shouldAwardSurvivalScore()
    then
        playerScore += playerScoreStep
    end
end)
scoreTimer.repeats = true
scoreTimer:pause()

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

-- The lower river opening stays transparent so the animated water remains visible.
local mainMenuBackgroundSprite = pdg.sprite.new(mainMenuImages.background)
mainMenuBackgroundSprite:moveTo(200, TUNING.MAIN_MENU_BACKGROUND_CENTER_Y)
mainMenuBackgroundSprite:setZIndex(TUNING.MAIN_MENU_Z_INDEX)
mainMenuBackgroundSprite:add()

local worldVelocityInterpolationSpeed = 0.08
local rockImageTables = {
    pdg.imagetable.new("images/Rock1"),
    pdg.imagetable.new("images/Rock2"),
    pdg.imagetable.new("images/Rock3"),
    pdg.imagetable.new("images/Rock4"),
    pdg.imagetable.new("images/BigRock1")
}
local rockImages = {
    rockImageTables[1]:getImage(1),
    rockImageTables[2]:getImage(1),
    rockImageTables[3]:getImage(1),
    rockImageTables[4]:getImage(1),
    rockImageTables[5]:getImage(1)
}
local rockWaveStartTimeMilliseconds = pd.getCurrentTimeMilliseconds()
local rockImageWidths = {}
local rockImageHeights = {}
local rockSprites = {}
local collectableSprites = {}
local decorationSprites = {}
local interactableObjectGroups = { rockSprites, collectableSprites, decorationSprites }

Ramp.initialize(TUNING, interactableObjectGroups)
Whirlpool.initialize(TUNING, sfxChannel, interactableObjectGroups)
BoatJump.initialize(TUNING)
FlightShadow.initialize(TUNING)
ScoreFlyEffect.initialize(TUNING)

for i = 1, #rockImages do
    rockImageWidths[i], rockImageHeights[i] = rockImages[i]:getSize()
end

local function setRockImage(rock, imageIndex)
    rock.imageIndex = imageIndex
    rock.isBig = imageIndex >= TUNING.BIG_ROCK_FIRST_IMAGE_INDEX
    rock.bigRockSpawnEdge = nil
    rock.nextPlayerBounceTimeMilliseconds = 0
    rock.imageWidth = rockImageWidths[imageIndex]
    rock.imageHeight = rockImageHeights[imageIndex]

    if rock.animation == nil then
        rock.animation = pdg.animation.loop.new(
            TUNING.ROCK_ANIMATION_FRAME_DELAY_MS,
            rockImageTables[imageIndex],
            true
        )
    else
        rock.animation:setImageTable(rockImageTables[imageIndex])
    end

    rock.animationFrame = nil
    rock:setImage(rock.animation:image())
    rock:setCollideRect(0, 0, rock.imageWidth, rock.imageHeight)
end

local function updateRockAnimation(rock)
    local xPhaseMilliseconds = rock.x * 1000 / TUNING.ROCK_WAVE_SPEED_PIXELS_PER_SECOND
    rock.animation.t = rockWaveStartTimeMilliseconds + xPhaseMilliseconds

    local animationFrame = rock.animation.frame
    if animationFrame ~= rock.animationFrame then
        rock.animationFrame = animationFrame
        rock:setImage(rock.animation:image())
    end
end

local function findRockSpawnPosition(rock)
    local minimumY, maximumY = GameModes.active:getRockSpawnYRange(
        rock,
        TUNING.WORLD_SPAWN_MINIMUM_Y + rock.imageHeight / 2,
        TUNING.WORLD_SPAWN_MAXIMUM_Y - rock.imageHeight / 2
    )

    return InteractiveSpawn.findPosition(
        interactableObjectGroups,
        rock,
        rock.imageWidth,
        rock.imageHeight,
        TUNING.ROCK_SPAWN_MINIMUM_X,
        -rock.imageWidth / 2,
        minimumY,
        maximumY,
        TUNING.INTERACTIVE_SPAWN_PADDING,
        TUNING.INTERACTIVE_SPAWN_ATTEMPTS
    )
end

local function resetRockPosition(rock)
    local imageIndex = math.random(TUNING.BIG_ROCK_FIRST_IMAGE_INDEX - 1)

    if #rockImages >= TUNING.BIG_ROCK_FIRST_IMAGE_INDEX
        and math.random(100) <= TUNING.BIG_ROCK_SPAWN_CHANCE_PERCENT
    then
        imageIndex = math.random(TUNING.BIG_ROCK_FIRST_IMAGE_INDEX, #rockImages)
    end

    setRockImage(rock, imageIndex)

    local x, y = findRockSpawnPosition(rock)
    if x == nil then
        rock.active = false
        rock:setVisible(false)
        return false
    end

    rock:moveTo(x, y)
    updateRockAnimation(rock)
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
            Difficulty.getMaxWorldVelocity(),
            worldVelocity * Difficulty.getWorldVelocityGrowthMultiplier()
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

local function applyPlayerVessel(gameMode)
    playerImagetable = gameMode:getPlayerImagetable()
    playerImagetableSize = playerImagetable:getLength()
    playerImageWidth, playerImageHeight = playerImagetable:getImage(1):getSize()
    playerCollisionX, playerCollisionY, playerCollisionWidth, playerCollisionHeight =
        gameMode:getCollisionRect(playerImageWidth, playerImageHeight)
    playerSprite:setImage(playerImagetable:getImage(gameMode:getMainMenuBoatFrameIndex()))
    playerSprite:setCollideRect(
        playerCollisionX,
        playerCollisionY,
        playerCollisionWidth,
        playerCollisionHeight
    )
end

local collectablesByType = {}
local collectableSpawnRemainingMilliseconds = {}
local collectableTypes <const> = { "coin", "shield", "shrink", "growth", "speedReduction" }

local function isCollectableAvailable(collectableType)
    return GameModes.active:isCollectableAvailable(collectableType)
end

local function canSpawnCollectable(collectableType)
    if isCollectableAvailable(collectableType) == false then
        return false
    end

    return collectableType ~= "speedReduction"
        or worldVelocity >= Difficulty.getMaxWorldVelocity()
end

local function onCoinCollected()
    GameModes.active:addCoins(GameModes.active:getCoinReward())
    playSoundOneShot(coinPickupSoundPlayer)
    markProgressChanged()
end

local function onShieldCollected()
    if isAbilityPurchased("shield") == false then
        return
    end

    shieldHitsRemaining = math.min(
        GameModes.active:getMaximumShieldHits(),
        shieldHitsRemaining + GameModes.active:getShieldPickupAmount()
    )
    playSoundOneShot(shieldSoundPlayer)
end

local function onShrinkCollected()
    if isAbilityPurchased("shrink") == false then
        return
    end

    shrinkDurationMilliseconds = TUNING.SHRINK_DURATION_MS_BY_LEVEL[
        AbilityProgression.getLevel("shrink", false) + 1
    ]
    targetPlayerScale = TUNING.SHRUNK_PLAYER_SCALE
    shrinkRemainingMilliseconds = shrinkDurationMilliseconds
    shrinkUiProgress = 0
    shrinkUiIsFilling = true
    playSoundOneShot(shrinkSoundPlayer)
end

local function onGrowthCollected()
    if isAbilityPurchased("growth") == false then
        return
    end

    GameplayProgress.impulseCharge = 1
    playSoundOneShot(
        rampSoundPlayers.impulsePickup,
        TUNING.OTHER_SIDE_IMPULSE_PICKUP_SOUND_OFFSET_SECONDS
    )
end

local function onSpeedReductionCollected()
    if isAbilityPurchased("speedReduction") == false then
        return
    end

    local reduction = GameModes.active:getSpeedReductionAmount()
    worldVelocity = math.max(TUNING.MIN_WORLD_VELOCITY, worldVelocity - reduction)
    playSoundOneShot(speedReductionSoundPlayer)
end

collectablesByType.coin = CoinCollectable(coinImagetable, onCoinCollected)
collectablesByType.shield = ShieldCollectable(shieldCollectableImage, onShieldCollected)
collectablesByType.shrink = ShrinkCollectable(shrinkCollectableImage, onShrinkCollected)
collectablesByType.growth = GrowthCollectable(growthCollectableImage, onGrowthCollected)
collectablesByType.speedReduction =
    SpeedReductionCollectable(speedReductionCollectableImage, onSpeedReductionCollected)

for i = 1, #collectableTypes do
    local collectableType = collectableTypes[i]
    local collectable = collectablesByType[collectableType]
    collectable:setZIndex(TUNING.COLLECTABLE_Z_INDEX)
    collectableSprites[#collectableSprites + 1] = collectable

    local config = TUNING.COLLECTABLE_SPAWN_CONFIG[collectableType]
    collectableSpawnRemainingMilliseconds[collectableType] =
        Difficulty.getRandomCollectableInterval(config, collectableType)
end

local function resetCollectableSpawnCountdown(collectableType)
    local config = TUNING.COLLECTABLE_SPAWN_CONFIG[collectableType]
    collectableSpawnRemainingMilliseconds[collectableType] =
        Difficulty.getRandomCollectableInterval(config, collectableType)
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
        elseif canSpawnCollectable(collectableType) then
            local remaining =
                collectableSpawnRemainingMilliseconds[collectableType] - elapsedMilliseconds
            collectableSpawnRemainingMilliseconds[collectableType] = remaining

            if remaining <= 0 then
                local config = TUNING.COLLECTABLE_SPAWN_CONFIG[collectableType]
                resetCollectableSpawnCountdown(collectableType)

                if math.random() * 100
                    <= Difficulty.getCollectableSpawnChance(config, collectableType)
                then
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

    playerSprite:setScale(currentPlayerScale * BoatJump.getScale())
    playerSprite:setCollideRect(
        playerCollisionX * currentPlayerScale,
        playerCollisionY * currentPlayerScale,
        playerCollisionWidth * currentPlayerScale,
        playerCollisionHeight * currentPlayerScale
    )
end

local function updateDashCooldown(elapsedMilliseconds)
    dashCooldownRemainingMilliseconds,
        dashUiProgress,
        dashUiIsDraining,
        GameplayProgress.hornActiveRemainingMilliseconds =
        GameModes.active:updatePrimaryAbilityState(
            elapsedMilliseconds,
            dashCooldownRemainingMilliseconds,
            dashCooldownDurationMilliseconds,
            dashUiProgress,
            dashUiIsDraining,
            GameplayProgress.hornActiveRemainingMilliseconds
        )
end

local function startDash(crankPositionForVelocity)
    if BoatJump.isAirborne()
        or isAbilityPurchased("dash") == false
        or dashCooldownRemainingMilliseconds > 0
    then
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
    Whirlpool.onDash(playerX, playerY)
    playSoundOneShot(dashSoundPlayer)
    return true
end

local function startHorn()
    if isAbilityPurchased("horn") == false
        or dashCooldownRemainingMilliseconds > 0
        or GameplayProgress.hornActiveRemainingMilliseconds > 0
    then
        return false
    end

    local hornLevel = math.max(0, GameModes.active:getAbilityLevel("horn"))

    if OtherSide.soundHorn(playerX, playerY, launchVisualAngle, hornLevel) == false then
        return false
    end

    dashCooldownDurationMilliseconds = getDashCooldownDuration()
    dashCooldownRemainingMilliseconds = 0
    GameplayProgress.hornActiveRemainingMilliseconds =
        TUNING.OTHER_SIDE_HORN_DURATION_MS_BY_LEVEL[hornLevel + 1]
    dashUiProgress = 1
    dashUiIsDraining = true
    return true
end

function GameplayProgress.startImpulse()
    if isAbilityPurchased("growth") == false
        or GameplayProgress.impulseCharge <= 0
    then
        return false
    end

    local impulseLevel = math.max(0, GameModes.active:getAbilityLevel("growth"))

    if OtherSide.startImpulse(
        playerX,
        playerY,
        launchVisualAngle,
        impulseLevel
    ) == false then
        return false
    end

    GameplayProgress.impulseCharge = 0
    ScreenShake.start(
        TUNING.OTHER_SIDE_IMPULSE_SCREEN_SHAKE_BY_LEVEL[impulseLevel + 1]
    )
    playSoundOneShot(rampSoundPlayers.impulse)
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
            GameModes.active:performPrimaryTap(
                crankPositionForVelocity,
                startDash,
                startHorn
            )
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

local upgradeMenuState = {
    progress = 0,
    closing = false,
    selectionIndex = 1,
    message = nil,
    messageRemainingMilliseconds = 0,
    pendingUpgradeSoundPlayer = nil,
    isOtherSide = false
}

local function purchaseAbilityUpgrade(abilityType)
    local didPurchase, nextLevel, isPurchase = AbilityProgression.tryPurchase(
        abilityType,
        upgradeMenuState.isOtherSide
    )

    if didPurchase == false then
        playSoundOneShot(noUpgradeSoundPlayer)
        return false, nil
    end

    local shouldDelayUpgradeSound = UpgradeMenuUI.playUpgradeEffect(nextLevel)

    if (abilityType == "dash" or abilityType == "horn")
        and dashCooldownRemainingMilliseconds <= 0
    then
        dashCooldownDurationMilliseconds = getDashCooldownDuration()
    end

    Difficulty.setSecretModeUnlocked(AbilityProgression.areRegularAbilitiesMaxed())
    GameModes.refreshActiveMode()

    markProgressChanged()

    local upgradeSoundPlayer

    if isPurchase then
        upgradeSoundPlayer = buyAbilitySoundPlayer
    else
        upgradeSoundPlayer = upgradeAbilitySoundPlayers[nextLevel]
    end

    if shouldDelayUpgradeSound then
        upgradeMenuState.pendingUpgradeSoundPlayer = upgradeSoundPlayer
    else
        upgradeMenuState.pendingUpgradeSoundPlayer = nil
        playSoundOneShot(upgradeSoundPlayer)
    end

    return true, nil
end

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

local playerParticleEmitterOffsets = TUNING.PLAYER_WAKE_EMITTER_OFFSETS

local wakeLinePool = {}
local wakeLineCursor = 1
local wakeLineSpawnCounter = 0

for i = 1, TUNING.WAKE_LINE_POOL_SIZE do
    wakeLinePool[i] = { active = false }
end

local function clearWakeLines()
    for i = 1, TUNING.WAKE_LINE_POOL_SIZE do
        wakeLinePool[i].active = false
    end

    LandingSplash.reset()
    WakeLayer.markDirty()
end

local function spawnWakeLine(
    engineX,
    engineY,
    wakeAngle,
    speedMultiplier,
    angleSpread,
    useSteamboatDimensions,
    lengthMultiplier
)
    local line = wakeLinePool[wakeLineCursor]

    wakeLineCursor += 1
    if wakeLineCursor > TUNING.WAKE_LINE_POOL_SIZE then
        wakeLineCursor = 1
    end

    local angle = wakeAngle + math.random(-angleSpread, angleSpread)
    local perpendicularAngle = angle + 90
    local sideOffset = math.random(-3, 3)
    local speed = math.random(12, 20) / 10 * speedMultiplier
    local length = math.random(8, 15)
    local width = math.random(1, 2)
    local lifetime = math.random(10, 16)

    if useSteamboatDimensions then
        sideOffset = math.random(
            -TUNING.STEAMBOAT_WAKE_SIDE_OFFSET,
            TUNING.STEAMBOAT_WAKE_SIDE_OFFSET
        )
        speed = math.random(
            TUNING.STEAMBOAT_WAKE_MINIMUM_SPEED_TENTHS,
            TUNING.STEAMBOAT_WAKE_MAXIMUM_SPEED_TENTHS
        ) / 10 * speedMultiplier
        length = math.random(
            TUNING.STEAMBOAT_WAKE_MINIMUM_LENGTH,
            TUNING.STEAMBOAT_WAKE_MAXIMUM_LENGTH
        )
        width = math.random(
            TUNING.STEAMBOAT_WAKE_MINIMUM_WIDTH,
            TUNING.STEAMBOAT_WAKE_MAXIMUM_WIDTH
        )
        lifetime = math.random(
            TUNING.STEAMBOAT_WAKE_MINIMUM_LIFETIME_FRAMES,
            TUNING.STEAMBOAT_WAKE_MAXIMUM_LIFETIME_FRAMES
        )
        length = math.floor(length * (lengthMultiplier or 1) + 0.5)
    end

    line.active = true
    line.x = engineX + math.sin(math.rad(perpendicularAngle)) * sideOffset
    line.y = engineY - math.cos(math.rad(perpendicularAngle)) * sideOffset
    line.dx = math.sin(math.rad(angle))
    line.dy = -math.cos(math.rad(angle))
    line.speed = speed
    line.length = length
    line.age = 0
    line.lifetime = lifetime
    line.width = width
end

local function updateWakeLines(
    currentVelocityAngle,
    playerSpriteIndexFromAngle,
    isDashing,
    worldDisplacement,
    allowSpawning
)
    for i = 1, TUNING.WAKE_LINE_POOL_SIZE do
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

    WakeLayer.markDirty()

    if allowSpawning == false then
        return
    end

    if playerSpeedMode == 0 then
        return
    end

    local isDefaultScale = currentPlayerScale >= TUNING.WAKE_DEFAULT_SCALE_THRESHOLD
    local emitterOffset,
        spawnCount,
        spawnInterval,
        speedMultiplier,
        angleSpread,
        useSteamboatDimensions,
        lengthMultiplier = GameModes.active:getWakeParameters(
            playerSpriteIndexFromAngle,
            playerSpeedMode == 2 or isDashing,
            isDefaultScale,
            playerParticleEmitterOffsets
        )
    local engineX = playerX + emitterOffset.x * currentPlayerScale
    local engineY = playerY + emitterOffset.y * currentPlayerScale
    local wakeAngle = math.normalizeAngle(currentVelocityAngle + 180)

    wakeLineSpawnCounter += 1

    if wakeLineSpawnCounter >= spawnInterval then
        for _ = 1, spawnCount do
            spawnWakeLine(
                engineX,
                engineY,
                wakeAngle,
                speedMultiplier,
                angleSpread,
                useSteamboatDimensions,
                lengthMultiplier
            )
        end

        wakeLineSpawnCounter = 0
    end
end

local function drawWakeLines()
    local previousLineWidth = pdg.getLineWidth()
    local previousColor = pdg.getColor()

    pdg.setColor(pdg.kColorBlack)

    for i = 1, TUNING.WAKE_LINE_POOL_SIZE do
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

    Steamboat.drawWakeLines()
    OtherSide.drawWakeLines(playerX, playerY, launchVisualAngle)
    Whirlpool.draw()
    LandingSplash.draw()
    FlightShadow.draw()

    pdg.setLineWidth(previousLineWidth)
    pdg.setColor(previousColor)
end

LandingSplash.initialize(TUNING)
WakeLayer.initialize(drawWakeLines, TUNING.WAKE_Z_INDEX)

local function drawHornChargeArcs(
    currentVelocityAngle,
    visibleArcCount,
    drawWhiteBackground
)
    local angleRadians = math.rad(currentVelocityAngle - 5)
    local forwardX = math.sin(angleRadians)
    local forwardY = -math.cos(angleRadians)
    local rightX = math.cos(angleRadians)
    local rightY = math.sin(angleRadians)
    local halfLineLength = TUNING.OTHER_SIDE_DIEGETIC_HORN_LINE_LENGTH / 2
    local lineWidth = drawWhiteBackground
        and TUNING.OTHER_SIDE_DIEGETIC_HORN_BACKGROUND_LINE_WIDTH
        or TUNING.OTHER_SIDE_DIEGETIC_HORN_LINE_WIDTH
    local endRadius = math.floor(lineWidth / 2)
    local arcSegmentCount = TUNING.OTHER_SIDE_DIEGETIC_HORN_CURVE_SEGMENT_COUNT

    pdg.setLineWidth(lineWidth)

    for arcIndex = 1, visibleArcCount do
        local distance = TUNING.OTHER_SIDE_DIEGETIC_HORN_FRONT_DISTANCE
            + (arcIndex - 1) * TUNING.OTHER_SIDE_DIEGETIC_HORN_LINE_SPACING
        local previousX = nil
        local previousY = nil
        local startX = nil
        local startY = nil
        local endX = nil
        local endY = nil

        for segmentIndex = 0, arcSegmentCount do
            local progress = segmentIndex / arcSegmentCount
            local arcAngle = -math.pi / 2 + math.pi * progress
            local forwardOffset = distance
                + math.cos(arcAngle) * TUNING.OTHER_SIDE_DIEGETIC_HORN_CURVE_DEPTH
            local rightOffset = math.sin(arcAngle) * halfLineLength
            local x = playerX + forwardX * forwardOffset + rightX * rightOffset
            local y = playerY + forwardY * forwardOffset + rightY * rightOffset

            if previousX ~= nil then
                pdg.drawLine(previousX, previousY, x, y)
            else
                startX = x
                startY = y
            end

            previousX = x
            previousY = y
            endX = x
            endY = y
        end

        pdg.fillCircleAtPoint(startX, startY, endRadius)
        pdg.fillCircleAtPoint(endX, endY, endRadius)
    end
end

local function drawDashChargeChevrons(
    currentVelocityAngle,
    visibleChevronCount,
    drawWhiteBackground
)
    if visibleChevronCount <= 0 then
        return
    end

    local angleRadians = math.rad(currentVelocityAngle - 5)
    local forwardX = math.sin(angleRadians)
    local forwardY = -math.cos(angleRadians)
    local rightX = math.cos(angleRadians)
    local rightY = math.sin(angleRadians)
    local indicatorRadiusScale = 0.5
        + currentPlayerScale * BoatJump.getScale() * 0.5
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

local function drawShrinkProgressArc(currentVelocityAngle, abilityProgress)
    local progress = math.clamp(abilityProgress, 0, 1)

    if progress <= 0 then
        return
    end

    local angleRadians = math.rad(currentVelocityAngle)
    local forwardX = math.sin(angleRadians)
    local forwardY = -math.cos(angleRadians)
    local rightX = math.cos(angleRadians)
    local rightY = math.sin(angleRadians)
    local radiusScale = 0.5
        + currentPlayerScale * BoatJump.getScale() * 0.5
    local majorRadius, minorRadius, forwardOffset, rightOffset =
        GameModes.active:getSecondaryArcConfiguration()
    majorRadius *= radiusScale
    minorRadius *= radiusScale
    local centerX = playerX
    local centerY = playerY
    centerX += forwardX * forwardOffset + rightX * rightOffset
    centerY += forwardY * forwardOffset + rightY * rightOffset

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
            centerX + forwardX * startForward + rightX * startRight,
            centerY + forwardY * startForward + rightY * startRight,
            centerX + forwardX * endForward + rightX * endRight,
            centerY + forwardY * endForward + rightY * endRight
        )
    end
end

local function drawShieldStorageArc(currentVelocityAngle, drawFilledSegments)
    local angleRadians = math.rad(currentVelocityAngle)
    local forwardX = math.sin(angleRadians)
    local forwardY = -math.cos(angleRadians)
    local rightX = math.cos(angleRadians)
    local rightY = math.sin(angleRadians)
    local radiusScale = 0.5
        + currentPlayerScale * BoatJump.getScale() * 0.5
    local majorRadius, minorRadius, forwardOffset, rightOffset, segmentCount =
        GameModes.active:getShieldArcConfiguration()
    majorRadius *= radiusScale
    minorRadius *= radiusScale
    local centerX = playerX
    local centerY = playerY
    centerX += forwardX * forwardOffset + rightX * rightOffset
    centerY += forwardY * forwardOffset + rightY * rightOffset
    local segmentsToDraw = segmentCount
    local endInset = math.rad(TUNING.DIEGETIC_SHIELD_ARC_END_INSET_DEGREES)
    local arcLength = math.pi - endInset * 2
    local gapFraction = TUNING.DIEGETIC_SHIELD_ARC_GAP_FRACTION

    if drawFilledSegments then
        segmentsToDraw = math.min(shieldHitsRemaining, segmentCount)
    end

    for segmentIndex = 1, segmentsToDraw do
        local slotIndex = segmentIndex

        if drawFilledSegments then
            slotIndex = segmentCount - segmentIndex + 1
        end

        local slotStart = (slotIndex - 1) / segmentCount
        local slotEnd = slotIndex / segmentCount
        local gapInset = gapFraction / segmentCount / 2
        local segmentStart = slotStart + gapInset
        local segmentEnd = slotEnd - gapInset
        local startAngle = math.pi - endInset - arcLength * segmentStart
        local endAngle = math.pi - endInset - arcLength * segmentEnd
        local startForward = math.cos(startAngle) * majorRadius
        local startRight = math.sin(startAngle) * minorRadius
        local endForward = math.cos(endAngle) * majorRadius
        local endRight = math.sin(endAngle) * minorRadius

        pdg.drawLine(
            centerX + forwardX * startForward + rightX * startRight,
            centerY + forwardY * startForward + rightY * startRight,
            centerX + forwardX * endForward + rightX * endRight,
            centerY + forwardY * endForward + rightY * endRight
        )
    end
end

local function drawDiegeticAbilities(currentVelocityAngle)
    local previousLineWidth = pdg.getLineWidth()
    local previousColor = pdg.getColor()
    local secondaryAbilityProgress = GameModes.active:getSecondaryAbilityProgress(
        shrinkUiProgress,
        GameplayProgress.impulseCharge
    )
    local primaryAbilityType = GameModes.active:getPrimaryAbilityType()
    local secondaryAbilityType = GameModes.active:getSecondaryAbilityType()

    pdg.setColor(pdg.kColorWhite)

    if isAbilityPurchased(primaryAbilityType) then
        -- Solid white backing plates prevent the water texture from crossing Dash arrows.
        GameModes.active:drawPrimaryIndicator(
            currentVelocityAngle,
            true,
            dashUiProgress,
            dashUiIsDraining,
            dashCooldownRemainingMilliseconds,
            dashCooldownDurationMilliseconds,
            drawDashChargeChevrons,
            drawHornChargeArcs
        )
    end

    if isAbilityPurchased(secondaryAbilityType) then
        -- The wider white line keeps the curved Shrink bar readable over the world.
        pdg.setLineWidth(TUNING.DIEGETIC_SHRINK_ARC_BACKGROUND_LINE_WIDTH)
        drawShrinkProgressArc(currentVelocityAngle, secondaryAbilityProgress)
    end

    if isAbilityPurchased("shield") and shieldHitsRemaining > 0 then
        pdg.setLineWidth(TUNING.DIEGETIC_SHIELD_ARC_BACKGROUND_LINE_WIDTH)
        drawShieldStorageArc(currentVelocityAngle, false)
    end

    pdg.setColor(pdg.kColorBlack)

    if isAbilityPurchased(primaryAbilityType) then
        pdg.setLineWidth(TUNING.DIEGETIC_DASH_LINE_WIDTH)
        GameModes.active:drawPrimaryIndicator(
            currentVelocityAngle,
            false,
            dashUiProgress,
            dashUiIsDraining,
            dashCooldownRemainingMilliseconds,
            dashCooldownDurationMilliseconds,
            drawDashChargeChevrons,
            drawHornChargeArcs
        )
    end

    if isAbilityPurchased(secondaryAbilityType) then
        pdg.setLineWidth(TUNING.DIEGETIC_SHRINK_ARC_LINE_WIDTH)
        drawShrinkProgressArc(currentVelocityAngle, secondaryAbilityProgress)
    end

    if isAbilityPurchased("shield") and shieldHitsRemaining > 0 then
        pdg.setLineWidth(TUNING.DIEGETIC_SHIELD_ARC_LINE_WIDTH)
        drawShieldStorageArc(currentVelocityAngle, true)
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

local hudScoreNumber = FixedWidthNumber.new(7)
local hudCoinNumber = FixedWidthNumber.new(3)

local function updateSpeedometerNeedle(dashSpeed)
    local worldSpeedProgress = math.clamp(
        (interpolatedWorldVelocity - TUNING.MIN_WORLD_VELOCITY)
            / (Difficulty.getMaxWorldVelocity() - TUNING.MIN_WORLD_VELOCITY),
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
    local usesOtherSidePresentation = GameModes.active:usesOtherSidePresentation()
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
            dashCooldownRemainingMilliseconds <= 0
                and GameplayProgress.hornActiveRemainingMilliseconds <= 0,
            GameModes.active:getSecondaryAbilityProgress(
                shrinkUiProgress,
                GameplayProgress.impulseCharge
            ),
            shieldHitsRemaining,
            isAbilityPurchased(GameModes.active:getPrimaryAbilityType()),
            isAbilityPurchased(GameModes.active:getSecondaryAbilityType()),
            TUNING,
            leftHudOffsetX,
            usesOtherSidePresentation
        )
    end

    FixedWidthNumber.update(hudScoreNumber, playerScore)
    local scoreX = 400 - hudScoreNumber.width - 2 + rightHudOffsetX
    local starImageWidth = starImage:getSize()
    local starX = 400 - hudScoreNumber.width - starImageWidth - 5 + rightHudOffsetX

    FixedWidthNumber.update(hudCoinNumber, GameModes.active:getCoins())
    local coinImage = coinImagetable:getImage(1)
    local coinImageWidth = coinImage:getSize()
    local coinTextX = 400 - hudCoinNumber.width - 2 + rightHudOffsetX
    local coinX = coinTextX - coinImageWidth - 3
    local previousColor = pdg.getColor()

    pdg.setColor(pdg.kColorBlack)
    FixedWidthNumber.draw(hudScoreNumber, scoreX, 6)
    starImage:draw(starX, 2)

    FixedWidthNumber.draw(hudCoinNumber, coinTextX, 27)
    coinImage:draw(coinX, 25)
    pdg.setColor(previousColor)

end

local function destroyRock(rock, shouldShake)
    startRockExplosion(rock.x, rock.y)
    playRockExplosionSound()

    if shouldShake ~= false then
        ScreenShake.start(TUNING.ROCK_BREAK_SCREEN_SHAKE)
    end

    rock.active = false
    rock:setVisible(false)
end

local function handlePlayerCollisions(collisions, length, takeoffSpeed)
    -- Temporarily expose the complete scaled boat bounds for pickup checks. Rock
    -- collisions continue to use the smaller gameplay hitbox restored below.
    playerSprite:setCollideRect(
        0,
        0,
        playerImageWidth * currentPlayerScale,
        playerImageHeight * currentPlayerScale
    )

    local rampCollision = GameModes.active:findRampCollision(
        collisions,
        length,
        playerSprite
    )

    if rampCollision ~= nil then
        local launchVelocityX = (xVelocity + dashVelocityX)
                * TUNING.RAMP_JUMP_HORIZONTAL_SPEED_RETENTION
            - TUNING.RAMP_JUMP_LEFT_BOOST
        local launchVelocityY = yVelocity + dashVelocityY

        if BoatJump.start(
            takeoffSpeed,
            playerSpeedMode == 2,
            launchVelocityX,
            launchVelocityY,
            launchVisualAngle
        ) then
            Ramp.markUsed(rampCollision)
            playSoundOneShot(rampSoundPlayers.takeoff)
            xVelocity *= TUNING.RAMP_JUMP_HORIZONTAL_SPEED_RETENTION
            dashVelocityX = dashVelocityX
                * TUNING.RAMP_JUMP_HORIZONTAL_SPEED_RETENTION
                - TUNING.RAMP_JUMP_LEFT_BOOST
        end
    end

    for i = 1, #collectableSprites do
        local collectable = collectableSprites[i]

        if collectable.active
            and collectable.isCollecting == false
            and playerSprite:alphaCollision(collectable)
        then
            collectable:collect()
        end
    end

    GameModes.active:consumeTouchedDecoration(
        decorationSprites,
        playerSprite,
        decorationManager
    )

    playerSprite:setCollideRect(
        playerCollisionX * currentPlayerScale,
        playerCollisionY * currentPlayerScale,
        playerCollisionWidth * currentPlayerScale,
        playerCollisionHeight * currentPlayerScale
    )

    if BoatJump.isAirborne() then
        return false
    end

    for i = 1, length do
        local other = collisions[i].other

        if other ~= nil and other.active then
            local collisionAction
            collisionAction, shieldHitsRemaining = GameModes.active:resolveCollision(
                other,
                playerSprite,
                shieldHitsRemaining
            )

            if collisionAction == "destroyRock" then
                destroyRock(other)
            elseif collisionAction == "destroyRockForScore" then
                destroyRock(other, false)
                playerScore += TUNING.OTHER_SIDE_ROCK_SCORE
            elseif collisionAction == "explodeSteamboat"
                or collisionAction == "destroySmallBoat"
            then
                playSoundOneShot(boatExplosionSoundPlayer)
                ScreenShake.start(TUNING.STEAMBOAT_EXPLOSION_SCREEN_SHAKE)
            elseif collisionAction == "bounceFromBigRock" then
                playSoundOneShot(rampSoundPlayers.bigRockBounce)
                xVelocity,
                    yVelocity,
                    dashVelocityX,
                    dashVelocityY,
                    playerX,
                    playerY = GameModes.active:getBigRockBounceResponse(
                        other,
                        playerX,
                        playerY,
                        xVelocity,
                        yVelocity
                    )
                playerSprite:moveTo(playerX, playerY)
            elseif collisionAction == "crash" then
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

local function getWaterVisualDisplacement(worldDisplacement)
    return worldDisplacement * TUNING.WATER_BACKGROUND_VELOCITY_MULTIPLIER
end

local function hideGameplayWorld()
    clearWakeLines()
    ScoreFlyEffect.reset()
    resetCollectables()
    decorationManager:reset()
    clearRockExplosions()
    Ramp.reset()
    Steamboat.reset()
    OtherSide.reset()
    Whirlpool.reset()

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

    remainingObjectCount += Ramp.rewind(displacement)
    remainingObjectCount += Whirlpool.rewind(displacement)
    remainingObjectCount += OtherSide.rewind(displacement)

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
    remainingObjectCount += Steamboat.rewind(elapsedMilliseconds, displacement)
    explosionX += displacement
    return remainingObjectCount
end

local function prepareNewRun()
    ScreenShake.reset()
    BoatJump.reset()
    FlightShadow.reset()
    GameplayProgress.suspended = true
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
    GameplayProgress.impulseCharge = 0
    GameplayProgress.hornActiveRemainingMilliseconds = 0
    GameplayProgress.waitingControlsSlideProgress = 0
    GameplayProgress.waitingControlsExitStarted = false
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
    boatEngineSoundRate = GameModes.active:getEngineInitialRate()
    boatEngineSoundVolume = GameModes.active:getEngineVolume(false)
    waterFlowSoundRate = TUNING.WATER_FLOW_MIN_RATE
    gameMusicRate = TUNING.MUSIC_NORMAL_RATE
    GameModes.stopGameplayMusic()
    crashReturnDelayElapsedMilliseconds = 0

    scoreTimer:reset()
    scoreTimer:pause()
    velocityIncreaseTimer:reset()
    velocityIncreaseTimer:pause()
    stopGameplayLoopSounds()

    playerSprite:setVisible(true)
    applyPlayerVessel(GameModes.active)
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

local function updateMainMenuBoatFloat(elapsedMilliseconds)
    menuBoatFloatElapsedMilliseconds += elapsedMilliseconds

    if GameModes.active ~= menuVesselSwap.targetMode then
        menuVesselSwap.targetMode = GameModes.active
        menuVesselSwap.elapsedMilliseconds = 0
        menuVesselSwap.active = true
    end

    local vesselScale = 1
    if menuVesselSwap.active then
        menuVesselSwap.elapsedMilliseconds = math.min(
            TUNING.MAIN_MENU_VESSEL_SWAP_DURATION_MS,
            menuVesselSwap.elapsedMilliseconds + elapsedMilliseconds
        )

        local swapProgress = menuVesselSwap.elapsedMilliseconds
            / TUNING.MAIN_MENU_VESSEL_SWAP_DURATION_MS

        if swapProgress < 0.5 then
            vesselScale = 1 - swapProgress * 2
        else
            if menuVesselSwap.displayedMode ~= menuVesselSwap.targetMode then
                applyPlayerVessel(menuVesselSwap.targetMode)
                menuVesselSwap.displayedMode = menuVesselSwap.targetMode
            end

            vesselScale = (swapProgress - 0.5) * 2
        end

        if swapProgress >= 1 then
            menuVesselSwap.active = false
            vesselScale = 1
        end
    end

    local verticalPhase = menuBoatFloatElapsedMilliseconds
        / TUNING.MAIN_MENU_BOAT_FLOAT_VERTICAL_PERIOD_MS * math.pi * 2
    local secondaryPhase = menuBoatFloatElapsedMilliseconds
        / TUNING.MAIN_MENU_BOAT_FLOAT_SECONDARY_PERIOD_MS * math.pi * 2
    local horizontalPhase = menuBoatFloatElapsedMilliseconds
        / TUNING.MAIN_MENU_BOAT_FLOAT_HORIZONTAL_PERIOD_MS * math.pi * 2

    local menuBoatX, menuBoatY = menuVesselSwap.displayedMode:getMainMenuBoatPosition()
    playerX = menuBoatX
        + math.sin(horizontalPhase) * TUNING.MAIN_MENU_BOAT_FLOAT_HORIZONTAL_AMPLITUDE
    playerY = menuBoatY
        + math.sin(verticalPhase) * TUNING.MAIN_MENU_BOAT_FLOAT_VERTICAL_AMPLITUDE
        + math.sin(secondaryPhase) * TUNING.MAIN_MENU_BOAT_FLOAT_SECONDARY_AMPLITUDE
    playerSprite:moveTo(playerX, playerY)
    playerSprite:setScale(vesselScale)
end

local function enterMainMenu()
    saveProgress()
    prepareNewRun()
    BoatGameState = GameState.MAIN_MENU
    MenuCrankNavigation.reset()
    presentationElapsedMilliseconds = 0
    menuBoatFloatElapsedMilliseconds = 0
    waitingCrankMovement = 0
    MainMenuHUDAnimation.show()
    lastUpdateTimeMilliseconds = pd.getCurrentTimeMilliseconds()

    mainMenuBackgroundSprite:setVisible(true)
    mainMenuBackgroundSprite:moveTo(200, TUNING.MAIN_MENU_BACKGROUND_CENTER_Y)
    setWaterTransform(waterScrollX, TUNING.MAIN_MENU_WATER_CENTER_Y)

    menuVesselSwap.displayedMode = GameModes.active
    menuVesselSwap.targetMode = menuVesselSwap.displayedMode
    menuVesselSwap.elapsedMilliseconds = TUNING.MAIN_MENU_VESSEL_SWAP_DURATION_MS
    menuVesselSwap.active = false
    playerX, playerY = menuVesselSwap.displayedMode:getMainMenuBoatPosition()
    playerSprite:setImage(playerImagetable:getImage(
        menuVesselSwap.displayedMode:getMainMenuBoatFrameIndex()
    ))
    playerSprite:moveTo(playerX, playerY)
    startMenuMusic()
end

local function startLaunchTransition()
    if menuVesselSwap.displayedMode ~= GameModes.active then
        applyPlayerVessel(GameModes.active)
        menuVesselSwap.displayedMode = GameModes.active
    end

    playerSprite:setScale(1)
    BoatGameState = GameState.LAUNCHING
    presentationElapsedMilliseconds = 0
    launchStartX = playerX
    launchStartY = playerY
    launchVisualAngle = 180
    resetCollectables()
    clearWakeLines()
    playSoundOneShot(startJourneySoundPlayer)
    resetBoatEngineSoundForCurrentMode()
    startBoatEngineSound()
    startWaterFlowSound()
    startMenuMusic()
end

local function beginWaitingForCrank()
    BoatGameState = GameState.WAITING_FOR_CRANK
    presentationElapsedMilliseconds = 0
    hudSlideProgress = 0
    waitingCrankMovement = 0
    GameplayProgress.waitingControlsExitStarted = false
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
    GameplayProgress.suspended = false
    scoreTimer:reset()
    scoreTimer:start()
    velocityIncreaseTimer:reset()
    velocityIncreaseTimer:start()

    for i = 1, TUNING.MAX_ROCKS do
        resetRockPosition(rockSprites[i])
    end

    GameModes.active:beginRun()

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
    playerSprite:setImage(playerImagetable:getImage(
        GameModes.active:getMainMenuBoatFrameIndex()
    ))
    playerSpeedMode = 1
    local menuBoatX, menuBoatY = GameModes.active:getMainMenuBoatPosition()
    playerX = menuBoatX
    playerY = TUNING.MAIN_MENU_BACKGROUND_OFFSCREEN_Y
        - TUNING.MAIN_MENU_BACKGROUND_CENTER_Y
        + menuBoatY
    playerSprite:moveTo(playerX, playerY)
    startMenuMusic()
end

local function smoothstep(progress)
    local clampedProgress = math.clamp(progress, 0, 1)
    return clampedProgress * clampedProgress * (3 - 2 * clampedProgress)
end

Steamboat.initialize(TUNING, sfxChannel, destroyRock, explosionImagetable)
OtherSide.initialize(
    TUNING,
    sfxChannel,
    explosionImagetable,
    function()
        playSoundOneShot(boatExplosionSoundPlayer)
    end,
    function(rock)
        if rock.active then
            destroyRock(rock, false)
            playerScore += rock.isBig
                and TUNING.OTHER_SIDE_BIG_ROCK_SCORE
                or TUNING.OTHER_SIDE_ROCK_SCORE
        end
    end
)
enterMainMenu()

function GameplayProgress.pause()
    GameplayProgress.suspended = true
    scoreTimer:pause()
    velocityIncreaseTimer:pause()
end

function GameplayProgress.resume()
    if BoatGameState ~= GameState.ALIVE or pd.isCrankDocked() then
        return
    end

    GameplayProgress.suspended = false
    scoreTimer:start()
    velocityIncreaseTimer:start()
end

function GameplayProgress.resumeAfterSystemInterruption()
    lastUpdateTimeMilliseconds = pd.getCurrentTimeMilliseconds()
    GameplayProgress.resume()

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

function playdate.crankDocked()
    GameplayProgress.pause()

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
        GameplayProgress.resume()
        startGameplayLoopSounds()
    end
end

function playdate.gameWillPause()
    saveProgress()
    GameplayProgress.pause()
    stopGameplayLoopSounds()
end

function playdate.gameWillResume()
    saveProgress()
    GameplayProgress.resumeAfterSystemInterruption()
end

function playdate.deviceWillLock()
    saveProgress()
    GameplayProgress.pause()
    stopGameplayLoopSounds()
end

function playdate.deviceDidUnlock()
    GameplayProgress.resumeAfterSystemInterruption()
end

function playdate.gameWillTerminate()
    saveProgress()
    stopGameplayLoopSounds()
end

function playdate.deviceWillSleep()
    saveProgress()
    GameplayProgress.pause()
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
    ScreenShake.update(elapsedMilliseconds)

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

    if BoatGameState == GameState.WAITING_FOR_CRANK then
        GameplayProgress.waitingControlsSlideProgress = math.min(
            1,
            GameplayProgress.waitingControlsSlideProgress
                + elapsedMilliseconds / TUNING.WAITING_CONTROLS_SLIDE_DURATION_MS
        )
    elseif BoatGameState == GameState.ALIGNING_TO_CRANK then
        if GameplayProgress.waitingControlsExitStarted == false then
            GameplayProgress.waitingControlsSlideProgress = math.min(
                1,
                GameplayProgress.waitingControlsSlideProgress
                    + elapsedMilliseconds / TUNING.WAITING_CONTROLS_SLIDE_DURATION_MS
            )

            if presentationElapsedMilliseconds >= TUNING.START_ROTATION_DURATION_MS
                and GameplayProgress.waitingControlsSlideProgress >= 1
            then
                GameplayProgress.waitingControlsExitStarted = true
            end
        else
            GameplayProgress.waitingControlsSlideProgress = math.max(
                0,
                GameplayProgress.waitingControlsSlideProgress
                    - elapsedMilliseconds / TUNING.WAITING_CONTROLS_SLIDE_DURATION_MS
            )
        end
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
            waterScrollX + getWaterVisualDisplacement(initialWorldDisplacement),
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
            local upgradeAbilities = UpgradeMenuUI.getAbilities(upgradeMenuState.isOtherSide)
            local selectionDelta = 0

            if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then
                MenuCrankNavigation.reset()
                selectionDelta = -1
            elseif pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then
                MenuCrankNavigation.reset()
                selectionDelta = 1
            else
                selectionDelta = MenuCrankNavigation.getSelectionDelta(
                    TUNING.MENU_CRANK_TICKS_PER_REVOLUTION
                )
            end

            if selectionDelta ~= 0 then
                upgradeMenuState.selectionIndex = (
                    upgradeMenuState.selectionIndex - 1 + selectionDelta
                ) % #upgradeAbilities + 1
                upgradeMenuState.message = nil
                playSoundOneShot(selectAbilitySoundPlayer)
            end

            local selectedAbility = upgradeAbilities[upgradeMenuState.selectionIndex]

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

        if UpgradeMenuUI.update(elapsedMilliseconds)
            and upgradeMenuState.pendingUpgradeSoundPlayer ~= nil
        then
            playSoundOneShot(upgradeMenuState.pendingUpgradeSoundPlayer)
            upgradeMenuState.pendingUpgradeSoundPlayer = nil
        end
        local upgradeMenuProgress = smoothstep(upgradeMenuState.progress)
        UpgradeMenuUI.draw(
            math.floor(-240 * (1 - upgradeMenuProgress)),
            upgradeMenuState.selectionIndex,
            AbilityProgression.getLevels(upgradeMenuState.isOtherSide),
            AbilityProgression.getCoins(upgradeMenuState.isOtherSide),
            upgradeMenuState.message,
            TUNING,
            upgradeMenuState.isOtherSide
        )

        if upgradeMenuState.closing and upgradeMenuState.progress <= 0 then
            saveProgress()
            BoatGameState = GameState.MAIN_MENU
            upgradeMenuState.closing = false
            MenuCrankNavigation.reset()
            MainMenuHUDAnimation.show()
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
            waterScrollX + getWaterVisualDisplacement(initialWorldDisplacement),
            TUNING.MAIN_MENU_WATER_CENTER_Y
        )
        updateMainMenuBoatFloat(elapsedMilliseconds)
        local completedMenuAction = MainMenuHUDAnimation.update(elapsedMilliseconds, TUNING)
        local leftHudOffsetX, rightHudOffsetX = MainMenuHUDAnimation.getOffsets(TUNING)

        pdg.sprite.update()
        mainMenuImages.hud:draw(rightHudOffsetX, 0)
        local previousFont = pdg.getFont()
        pdg.setFont(mainMenuActionFont)
        pdg.drawText(
            "Start",
            TUNING.MAIN_MENU_START_TEXT_X + rightHudOffsetX,
            TUNING.MAIN_MENU_START_TEXT_Y
        )
        pdg.drawText(
            "Upgrade",
            TUNING.MAIN_MENU_UPGRADE_TEXT_X + rightHudOffsetX,
            TUNING.MAIN_MENU_UPGRADE_TEXT_Y
        )
        pdg.setFont(previousFont)

        DifficultyMenuUI.draw(
            Difficulty.getSelectedMode(),
            Difficulty.getSelectedModeIndex(),
            Difficulty.getModeCount(),
            Difficulty.getSelectedHighScore(),
            Difficulty.isSelectedModeUnlocked(),
            TUNING,
            leftHudOffsetX
        )

        if completedMenuAction == "start" then
            startLaunchTransition()
        elseif completedMenuAction == "upgrade" then
            BoatGameState = GameState.UPGRADE_MENU
            upgradeMenuState.progress = 0
            upgradeMenuState.closing = false
            upgradeMenuState.message = nil
            upgradeMenuState.isOtherSide = GameModes.active:usesOtherSidePresentation()
            MenuCrankNavigation.reset()
            playSoundOneShot(openUpgradeMenuSoundPlayer)
        elseif MainMenuHUDAnimation.isInteractive() then
            local modeSelectionDelta = 0

            if pd.buttonJustPressed(pd.kButtonLeft) then
                MenuCrankNavigation.reset()
                modeSelectionDelta = -1
            elseif pd.buttonJustPressed(pd.kButtonRight) then
                MenuCrankNavigation.reset()
                modeSelectionDelta = 1
            else
                modeSelectionDelta = MenuCrankNavigation.getSelectionDelta(
                    TUNING.MENU_CRANK_TICKS_PER_REVOLUTION
                )
            end

            if modeSelectionDelta ~= 0 then
                Difficulty.select(modeSelectionDelta)
                GameModes.refreshActiveMode()
                markProgressChanged()
                playSoundOneShot(selectAbilitySoundPlayer)
            elseif pd.buttonJustPressed(pd.kButtonA) then
                if Difficulty.isSelectedModeUnlocked() then
                    MainMenuHUDAnimation.hide("start")
                else
                    playSoundOneShot(noUpgradeSoundPlayer)
                end
            elseif pd.buttonJustPressed(pd.kButtonB) then
                MainMenuHUDAnimation.hide("upgrade")
            end
        end

        return
    end

    if BoatGameState == GameState.LAUNCHING then
        startBoatEngineSound()
        startWaterFlowSound()
        presentationElapsedMilliseconds += elapsedMilliseconds
        local launchDurationMilliseconds =
            GameModes.active:getMenuLaunchDurationMilliseconds()
        local transitionProgress = smoothstep(
            presentationElapsedMilliseconds / launchDurationMilliseconds
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
        local curve = GameModes.active:getMenuLaunchCurve()
        local curveProgress
        local inverseCurveProgress
        local launchVelocityX
        local launchVelocityY

        if transitionProgress < curve.SPLIT then
            curveProgress = transitionProgress / curve.SPLIT
            inverseCurveProgress = 1 - curveProgress
            playerX = inverseCurveProgress ^ 3 * launchStartX
                + 3 * inverseCurveProgress ^ 2 * curveProgress * curve.FIRST_CONTROL_X
                + 3 * inverseCurveProgress * curveProgress ^ 2 * curve.TURN_CONTROL_X
                + curveProgress ^ 3 * curve.TURN_X
            playerY = inverseCurveProgress ^ 3 * launchStartY
                + 3 * inverseCurveProgress ^ 2 * curveProgress * curve.FIRST_CONTROL_Y
                + 3 * inverseCurveProgress * curveProgress ^ 2 * curve.TURN_CONTROL_Y
                + curveProgress ^ 3 * curve.TURN_Y
            launchVelocityX = 3 * inverseCurveProgress ^ 2
                    * (curve.FIRST_CONTROL_X - launchStartX)
                + 6 * inverseCurveProgress * curveProgress
                    * (curve.TURN_CONTROL_X - curve.FIRST_CONTROL_X)
                + 3 * curveProgress ^ 2 * (curve.TURN_X - curve.TURN_CONTROL_X)
            launchVelocityY = 3 * inverseCurveProgress ^ 2
                    * (curve.FIRST_CONTROL_Y - launchStartY)
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
            local finalRotationDelta = (GameModes.active:getGameplayEntryBoatAngle()
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
        setWaterTransform(
            waterScrollX + getWaterVisualDisplacement(initialWorldDisplacement),
            waterY
        )
        playerSprite:setImage(playerImagetable:getImage(launchFrameIndex))
        playerSprite:moveTo(playerX, playerY)
        updateWakeLines(
            launchVisualAngle,
            launchFrameIndex,
            false,
            initialWorldDisplacement
        )
        pdg.sprite.update()

        if presentationElapsedMilliseconds >= launchDurationMilliseconds then
            beginWaitingForCrank()
        end

        return
    end

    if BoatGameState == GameState.WAITING_FOR_CRANK then
        GameplayProgress.pause()
        startBoatEngineSound()
        startWaterFlowSound()
        startMenuMusic()
        local initialWorldDisplacement = math.max(
            TUNING.MINIMUM_WORLD_PIXEL_DISPLACEMENT,
            math.floor(TUNING.INITIAL_WORLD_VELOCITY + 0.5)
        )
        setWaterTransform(
            waterScrollX + getWaterVisualDisplacement(initialWorldDisplacement),
            TUNING.WATER_BACKGROUND_Y_OFFSET
        )
        waitingCrankMovement += math.abs(pd.getCrankChange())
        local waitingRotationDelta = (GameModes.active:getGameplayEntryBoatAngle()
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
        drawHud()
        WaitingControlsUI.draw(
            GameModes.active:usesOtherSidePresentation(),
            isAbilityPurchased(GameModes.active:getPrimaryAbilityType()),
            isAbilityPurchased(GameModes.active:getSecondaryAbilityType()),
            TUNING,
            GameplayProgress.waitingControlsSlideProgress
        )
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
        launchVisualAngle = currentRotationAngle
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
            waterScrollX + getWaterVisualDisplacement(initialWorldDisplacement),
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
        drawHud()
        WaitingControlsUI.draw(
            GameModes.active:usesOtherSidePresentation(),
            isAbilityPurchased(GameModes.active:getPrimaryAbilityType()),
            isAbilityPurchased(GameModes.active:getSecondaryAbilityType()),
            TUNING,
            GameplayProgress.waitingControlsSlideProgress
        )

        if presentationElapsedMilliseconds >= TUNING.START_ROTATION_DURATION_MS
            and GameplayProgress.waitingControlsSlideProgress <= 0
        then
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

        setWaterTransform(
            waterScrollX + getWaterVisualDisplacement(rewindDisplacement),
            TUNING.WATER_BACKGROUND_Y_OFFSET
        )
        ScreenShake.applyDrawOffset()
        pdg.sprite.update()
        updateExplosion()
        ScreenShake.clearDrawOffset()
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
        setWaterTransform(
            waterScrollX + getWaterVisualDisplacement(initialWorldDisplacement),
            waterY
        )
        local menuBoatX, menuBoatY = GameModes.active:getMainMenuBoatPosition()
        playerX = menuBoatX
        playerY = menuY - TUNING.MAIN_MENU_BACKGROUND_CENTER_Y + menuBoatY
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
        GameplayProgress.pause()
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
    setWaterTransform(
        waterScrollX + getWaterVisualDisplacement(worldDisplacement),
        TUNING.WATER_BACKGROUND_Y_OFFSET
    )

    for i = 1, TUNING.MAX_ROCKS do
        local rock = rockSprites[i]

        if rock.active then
            rock:moveBy(worldDisplacement, 0)
            updateRockAnimation(rock)

            if rock.x - rock.imageWidth / 2 > 400 then
                rock.active = false
                rock:setVisible(false)
            end
        end
    end

    GameModes.active:updateRamp(
        elapsedMilliseconds,
        worldDisplacement,
        rockSprites,
        interpolatedWorldVelocity,
        Difficulty.getMaxWorldVelocity()
    )

    if Ramp.consumeScreenEntry() then
        for i = 1, TUNING.MAX_ROCKS do
            local rock = rockSprites[i]

            if rock.active
                and Ramp.isProtectedRock(rock) == false
                and rock.x + rock.imageWidth / 2 < 0
            then
                rock.active = false
                rock:setVisible(false)
            end
        end
    end

    decorationManager:update(elapsedMilliseconds, worldDisplacement, interpolatedWorldVelocity)
    updateCollectables(elapsedMilliseconds, worldDisplacement)
    updateRockExplosions(elapsedMilliseconds, worldDisplacement)
    LandingSplash.update(elapsedMilliseconds, worldDisplacement)
    local reachedTrickScore = ScoreFlyEffect.update(elapsedMilliseconds)

    if reachedTrickScore ~= nil then
        playerScore += reachedTrickScore
    end

    -- Recycle rocks after collectables move/spawn so the shared overlap check sees
    -- every interactable object at its final position for this frame.
    if BoatJump.shouldPauseRockSpawning() == false
        and Ramp.shouldPauseRockSpawning() == false
    then
        local rockSpawnLimit = GameModes.active:getRockSpawnLimit()
        local activeRockCount = 0

        for i = 1, TUNING.MAX_ROCKS do
            if rockSprites[i].active then
                activeRockCount += 1
            end
        end

        for i = 1, TUNING.MAX_ROCKS do
            local rock = rockSprites[i]

            if activeRockCount >= rockSpawnLimit then
                break
            end

            if rock.active == false and resetRockPosition(rock) then
                activeRockCount += 1
            end
        end
    end

    GameModes.active:updateWorld(
        elapsedMilliseconds,
        worldDisplacement,
        interpolatedWorldVelocity,
        Difficulty.getMaxWorldVelocity(),
        playerX,
        playerY,
        launchVisualAngle,
        rockSprites
    )

    local didLand = BoatJump.update(elapsedMilliseconds)
    updatePlayerScale(elapsedMilliseconds)
    updateDashCooldown(elapsedMilliseconds)

    local crankPositionForVelocity = pd.getCrankPosition() - 90
    updateBButton(elapsedMilliseconds, crankPositionForVelocity)

    if pd.buttonJustPressed(pd.kButtonA) then
        GameModes.active:performSecondaryTap(GameplayProgress.startImpulse)
    end

    local activePlayerVelocity = GameModes.active:getPlayerVelocity(playerVelocity)
    local playerVelocityMultiplier = 1

    if playerSpeedMode == 2 then
        playerVelocityMultiplier = GameModes.active:getFastModeMultiplier(2.25)
    end

    if BoatJump.isAirborne() then
        playerVelocityMultiplier *= TUNING.RAMP_AIRBORNE_CONTROL_MULTIPLIER
    end

    targetXVelocity =
        math.cos(math.rad(crankPositionForVelocity))
            * activePlayerVelocity * playerVelocityMultiplier
    targetYVelocity =
        math.sin(math.rad(crankPositionForVelocity))
            * activePlayerVelocity * playerVelocityMultiplier

    local currentVelocityInterpolationSpeed =
        GameModes.active:getVelocityInterpolationSpeed(velocityInterpolationSpeed)

    xVelocity += (targetXVelocity - xVelocity) * currentVelocityInterpolationSpeed
    yVelocity += (targetYVelocity - yVelocity) * currentVelocityInterpolationSpeed

    local dashSpeed = math.sqrt(dashVelocityX * dashVelocityX + dashVelocityY * dashVelocityY)
    local whirlpoolPullX, whirlpoolPullY = GameModes.active:getWhirlpoolAttraction(
        elapsedMilliseconds,
        playerX,
        playerY,
        BoatJump.isAirborne(),
        playerSpeedMode == 2,
        dashSpeed
    )
    local movementVelocityX = xVelocity + dashVelocityX + whirlpoolPullX
    local movementVelocityY = yVelocity + dashVelocityY + whirlpoolPullY

    movementVelocityX, movementVelocityY = BoatJump.constrainTranslation(
        movementVelocityX,
        movementVelocityY
    )

    local movementSpeed = math.sqrt(
        movementVelocityX * movementVelocityX + movementVelocityY * movementVelocityY
    )
    local angleVelocityX, angleVelocityY = GameModes.active:getDesiredAngleVelocity(
        xVelocity,
        yVelocity,
        dashVelocityX,
        dashVelocityY
    )
    local desiredVelocityAngle = math.normalizeAngle(
        math.deg(math.atan2(angleVelocityY, angleVelocityX)) + 90
    )
    local currentVelocityAngle = GameModes.active:getVisualAngle(
        desiredVelocityAngle,
        launchVisualAngle,
        elapsedMilliseconds
    )
    launchVisualAngle = currentVelocityAngle
    local playerSpriteIndexFromAngle =
        math.clamp(math.ceil(currentVelocityAngle / 7.5), 1, playerImagetableSize)
    playerSprite:setImage(playerImagetable:getImage(playerSpriteIndexFromAngle))

    local isDashing = dashSpeed >= TUNING.DASH_WAKE_MINIMUM_VELOCITY
    updateSpeedometerNeedle(dashSpeed)
    updateBoatEngineSound(
        playerSpeedMode == 2,
        shrinkRemainingMilliseconds ~= nil,
        interpolatedWorldVelocity
    )
    updateWaterFlowSound(interpolatedWorldVelocity)
    updateGameMusic(interpolatedWorldVelocity)
    local currentWaterStreamVelocity = waterStreamVelocity

    if BoatJump.isAirborne() then
        currentWaterStreamVelocity *= TUNING.RAMP_AIRBORNE_WATER_STREAM_MULTIPLIER
    end

    playerX += movementVelocityX + currentWaterStreamVelocity
    playerY += movementVelocityY

    local actualX, actualY, collisions, length = playerSprite:moveWithCollisions(playerX, playerY)
    playerX = actualX
    playerY = actualY

    local whirlpoolCaptureX, whirlpoolCaptureY = Whirlpool.getCapturePosition()

    if whirlpoolCaptureX ~= nil then
        playerX = whirlpoolCaptureX
        playerY = whirlpoolCaptureY
    end

    local visualPlayerScale = currentPlayerScale
        * BoatJump.getScale()
        * Whirlpool.getPlayerScale()
    local scaledPlayerWidth = playerImageWidth * visualPlayerScale
    local scaledPlayerHeight = playerImageHeight * visualPlayerScale
    local playerMaximumX = 400 - scaledPlayerWidth / 1.5
    local capturedAtRightEdge = whirlpoolCaptureX ~= nil
        and whirlpoolCaptureX >= playerMaximumX
    playerX = math.clamp(playerX, scaledPlayerWidth / 2, playerMaximumX)
    playerY = math.clamp(
        playerY,
        TUNING.HUD_HEIGHT + playerImageHeight / 2,
        240 - scaledPlayerHeight / 3
    )
    playerSprite:moveTo(playerX, playerY)
    playerSprite:setScale(visualPlayerScale)
    FlightShadow.update(
        elapsedMilliseconds,
        playerX,
        playerY,
        BoatJump.isAirborne(),
        didLand,
        BoatJump.getScale(),
        currentPlayerScale
    )
    updateDashInertia(elapsedMilliseconds)

    if didLand then
        LandingSplash.start(playerX, playerY, currentPlayerScale)
        playSoundOneShot(rampSoundPlayers.landing)
    end

    local trickComboCount = Ramp.updateJumpChallenge(
        playerX,
        BoatJump.isAirborne() or didLand
    )

    if trickComboCount ~= nil then
        local trickScore = TUNING.RAMP_JUMP_SCORE_REWARD * trickComboCount
        ScoreFlyEffect.start(
            playerX,
            playerY - playerImageHeight * currentPlayerScale / 2,
            trickScore
        )
        playSoundOneShot(rampSoundPlayers.success)
    end

    local didCrash = Whirlpool.isCaptureComplete() or capturedAtRightEdge

    if Whirlpool.isCapturing() == false then
        didCrash = handlePlayerCollisions(
            collisions,
            length,
            interpolatedWorldVelocity + movementSpeed
        )
    end

    if didCrash then
        if Difficulty.recordScore(playerScore) then
            markProgressChanged()
        end

        BoatGameState = GameState.CRASH_REWIND
        presentationElapsedMilliseconds = 0
        crashReturnDelayElapsedMilliseconds = 0
        GameplayProgress.pause()
        stopGameplayLoopSounds()
        playerSprite:setScale(0)
        FlightShadow.reset()
        clearWakeLines()
        startExplosion(playerX, playerY)
        playSoundOneShot(boatExplosionSoundPlayer)
        ScreenShake.start(TUNING.DEATH_SCREEN_SHAKE)
    else
        updateWakeLines(
            currentVelocityAngle,
            playerSpriteIndexFromAngle,
            isDashing,
            worldDisplacement,
            BoatJump.isAirborne() == false and Whirlpool.isCapturing() == false
        )
    end

    ScreenShake.applyDrawOffset()
    pdg.sprite.update()

    if didCrash then
        updateExplosion()
    elseif selectedUiMode == UI_MODE_OPTIONS[2] or selectedUiMode == UI_MODE_OPTIONS[3] then
        drawDiegeticAbilities(currentVelocityAngle)
    end

    ScreenShake.clearDrawOffset()
    drawHud()
    ScoreFlyEffect.draw()

    pd.drawFPS(200, 0)
end
