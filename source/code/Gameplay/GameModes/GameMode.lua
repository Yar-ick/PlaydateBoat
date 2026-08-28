local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

class("GameMode").extends()

function GameMode:init(tuning, configuration)
    self.tuning = tuning
    self.profileIsOtherSide = configuration.profileIsOtherSide == true
    self.playerImagetable = pdg.imagetable.new(configuration.playerImagePath)
    self.gameplayMusicPlayer = pds.fileplayer.new(configuration.musicPath)
    self.primaryAbilityType = configuration.primaryAbilityType
    self.secondaryAbilityType = configuration.secondaryAbilityType
    self.menuBoatX = configuration.menuBoatX
    self.menuBoatY = configuration.menuBoatY
    self.menuBoatFrameIndex = configuration.menuBoatFrameIndex
    self.gameplayEntryBoatAngle = configuration.gameplayEntryBoatAngle
    self.menuLaunchDurationMilliseconds = configuration.menuLaunchDurationMilliseconds
    self.menuLaunchCurve = configuration.menuLaunchCurve
    self.maximumShieldHits = configuration.maximumShieldHits
end

function GameMode:getPlayerImagetable()
    return self.playerImagetable
end

function GameMode:getGameplayMusicPlayer()
    return self.gameplayMusicPlayer
end

function GameMode:getMainMenuBoatPosition()
    return self.menuBoatX, self.menuBoatY
end

function GameMode:getMainMenuBoatFrameIndex()
    return self.menuBoatFrameIndex
end

function GameMode:getGameplayEntryBoatAngle()
    return self.gameplayEntryBoatAngle
end

function GameMode:getMenuLaunchDurationMilliseconds()
    return self.menuLaunchDurationMilliseconds
end

function GameMode:getMenuLaunchCurve()
    return self.menuLaunchCurve
end

function GameMode:getPrimaryAbilityType()
    return self.primaryAbilityType
end

function GameMode:getSecondaryAbilityType()
    return self.secondaryAbilityType
end

function GameMode:getSecondaryAbilityProgress(shrinkProgress, impulseCharge)
    return shrinkProgress
end

function GameMode:drawPrimaryIndicator(
    currentVelocityAngle,
    drawWhiteBackground,
    uiProgress,
    uiIsDraining,
    cooldownRemainingMilliseconds,
    cooldownDurationMilliseconds,
    drawDashIndicator,
    drawHornIndicator
)
end

function GameMode:getAbilityLevel(abilityType)
    return AbilityProgression.getLevel(abilityType, self.profileIsOtherSide)
end

function GameMode:getAbilityLevels()
    return AbilityProgression.getLevels(self.profileIsOtherSide)
end

function GameMode:isAbilityPurchased(abilityType)
    return AbilityProgression.isPurchased(abilityType, self.profileIsOtherSide)
end

function GameMode:getCoins()
    return AbilityProgression.getCoins(self.profileIsOtherSide)
end

function GameMode:addCoins(amount)
    return AbilityProgression.addCoins(amount, self.profileIsOtherSide)
end

function GameMode:tryPurchaseAbility(abilityType)
    return AbilityProgression.tryPurchase(abilityType, self.profileIsOtherSide)
end

function GameMode:getMaximumShieldHits()
    return self.maximumShieldHits
end

function GameMode:getShieldPickupAmount()
    return self.tuning.SHIELD_HITS_BY_LEVEL[self:getAbilityLevel("shield") + 1]
end

function GameMode:getSpeedReductionAmount()
    return self.tuning.SPEED_REDUCTION_BY_LEVEL[self:getAbilityLevel("speedReduction") + 1]
end

function GameMode:isCollectableAvailable(collectableType)
    return collectableType == "coin" or self:isAbilityPurchased(collectableType)
end

function GameMode:getCoinReward()
    return Difficulty.getCoinReward()
end

function GameMode:getPlayerVelocity(defaultVelocity)
    return defaultVelocity
end

function GameMode:getFastModeMultiplier(defaultMultiplier)
    return defaultMultiplier
end

function GameMode:getVelocityInterpolationSpeed(defaultSpeed)
    return defaultSpeed
end

function GameMode:getVisualAngle(desiredAngle, previousAngle, elapsedMilliseconds)
    return desiredAngle
end

function GameMode:getDesiredAngleVelocity(velocityX, velocityY, impulseVelocityX, impulseVelocityY)
    return velocityX + impulseVelocityX, velocityY + impulseVelocityY
end

function GameMode:getEngineInitialRate()
    return self.tuning.ENGINE_MIN_WORLD_RATE
end

function GameMode:getEngineVolume(isFast)
    return isFast and self.tuning.ENGINE_FAST_VOLUME or self.tuning.ENGINE_NORMAL_VOLUME
end

function GameMode:getEngineTargetRate(isFast, isShrunk, currentWorldVelocity)
    local velocityRange = Difficulty.getMaxWorldVelocity() - self.tuning.INITIAL_WORLD_VELOCITY
    local velocityProgress = 0

    if velocityRange > 0 then
        velocityProgress = math.clamp(
            (currentWorldVelocity - self.tuning.INITIAL_WORLD_VELOCITY) / velocityRange,
            0,
            1
        )
    end

    local targetRate = self.tuning.ENGINE_MIN_WORLD_RATE
        + (self.tuning.ENGINE_MAX_WORLD_RATE - self.tuning.ENGINE_MIN_WORLD_RATE)
            * velocityProgress

    if isFast then
        targetRate *= self.tuning.ENGINE_FAST_RATE_MULTIPLIER
    end

    if isShrunk then
        targetRate *= self.tuning.ENGINE_SHRINK_RATE_MULTIPLIER
    end

    return math.min(targetRate, self.tuning.ENGINE_MAX_RATE)
end

function GameMode:getCollisionRect(imageWidth, imageHeight)
    return imageWidth / 3, imageHeight / 2, imageWidth / 3, imageHeight / 5
end

function GameMode:shouldAwardSurvivalScore()
    return true
end

function GameMode:getRockSpawnLimit()
    return self.tuning.MAX_ROCKS
end

function GameMode:getRockSpawnYRange(rock, minimumY, maximumY)
    return minimumY, maximumY
end

function GameMode:getSecondaryArcConfiguration()
    return self.tuning.DIEGETIC_SHRINK_ARC_MAJOR_RADIUS,
        self.tuning.DIEGETIC_SHRINK_ARC_MINOR_RADIUS,
        0,
        0
end

function GameMode:getShieldArcConfiguration()
    return self.tuning.DIEGETIC_SHIELD_ARC_MAJOR_RADIUS,
        self.tuning.DIEGETIC_SHIELD_ARC_MINOR_RADIUS,
        0,
        0,
        self.tuning.DIEGETIC_SHIELD_ARC_SEGMENT_COUNT
end

function GameMode:findRampCollision(collisions, length, playerSprite)
    return nil
end

function GameMode:consumeTouchedDecoration(decorationSprites, playerSprite, decorationManager)
end

function GameMode:getWhirlpoolAttraction(
    elapsedMilliseconds,
    playerX,
    playerY,
    isAirborne,
    isFast,
    dashSpeed
)
    return 0, 0
end

function GameMode:performPrimaryTap(crankPositionForVelocity, startDash, startHorn)
end

function GameMode:performSecondaryTap(startImpulse)
end

function GameMode:beginRun()
end

function GameMode:updateRamp(
    elapsedMilliseconds,
    worldDisplacement,
    rockSprites,
    worldVelocity,
    maximumWorldVelocity
)
end

function GameMode:updateWorld(
    elapsedMilliseconds,
    worldDisplacement,
    worldVelocity,
    maximumWorldVelocity,
    playerX,
    playerY,
    playerAngle,
    rockSprites
)
end

function GameMode:isPixelPerfectCollision(collision, playerSprite)
    local other = collision and collision.other
    return other ~= nil
        and other.active == true
        and playerSprite:alphaCollision(other)
end

function GameMode:resolveCollision(collision, playerSprite, shieldHitsRemaining)
    return nil, shieldHitsRemaining
end

function GameMode:getBigRockBounceResponse(
    rock,
    playerX,
    playerY,
    velocityX,
    velocityY
)
    return velocityX, velocityY, 0, 0, playerX, playerY
end

function GameMode:usesOtherSidePresentation()
    return self.profileIsOtherSide
end
