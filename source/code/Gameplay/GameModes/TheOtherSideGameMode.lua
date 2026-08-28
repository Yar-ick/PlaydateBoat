class("TheOtherSideGameMode").extends(GameMode)

function TheOtherSideGameMode:init(tuning)
    TheOtherSideGameMode.super.init(self, tuning, {
        profileIsOtherSide = true,
        playerImagePath = "images/Steamboat",
        musicPath = "sounds/Hymn of Valor",
        primaryAbilityType = "horn",
        secondaryAbilityType = "growth",
        menuBoatX = tuning.OTHER_SIDE_MAIN_MENU_BOAT_X,
        menuBoatY = tuning.OTHER_SIDE_MAIN_MENU_BOAT_Y,
        menuBoatFrameIndex = tuning.OTHER_SIDE_MAIN_MENU_BOAT_FRAME_INDEX,
        gameplayEntryBoatAngle = tuning.OTHER_SIDE_GAMEPLAY_ENTRY_BOAT_ANGLE,
        menuLaunchDurationMilliseconds = tuning.OTHER_SIDE_MENU_LAUNCH_DURATION_MS,
        menuLaunchCurve = tuning.OTHER_SIDE_MENU_LAUNCH_CURVE,
        maximumShieldHits = tuning.OTHER_SIDE_MAX_SHIELD_HITS
    })
end

function TheOtherSideGameMode:isCollectableAvailable(collectableType)
    return collectableType == "coin"
        or (collectableType ~= "shrink" and self:isAbilityPurchased(collectableType))
end

function TheOtherSideGameMode:getSecondaryAbilityProgress(shrinkProgress, impulseCharge)
    return impulseCharge
end

function TheOtherSideGameMode:getSecondaryArcConfiguration()
    return self.tuning.OTHER_SIDE_DIEGETIC_IMPULSE_ARC_MAJOR_RADIUS,
        self.tuning.OTHER_SIDE_DIEGETIC_IMPULSE_ARC_MINOR_RADIUS,
        self.tuning.OTHER_SIDE_DIEGETIC_IMPULSE_ARC_FORWARD_OFFSET,
        self.tuning.OTHER_SIDE_DIEGETIC_IMPULSE_ARC_RIGHT_OFFSET
end

function TheOtherSideGameMode:getShieldArcConfiguration()
    return self.tuning.OTHER_SIDE_DIEGETIC_SHIELD_ARC_MAJOR_RADIUS,
        self.tuning.OTHER_SIDE_DIEGETIC_SHIELD_ARC_MINOR_RADIUS,
        self.tuning.OTHER_SIDE_DIEGETIC_SHIELD_ARC_FORWARD_OFFSET,
        self.tuning.OTHER_SIDE_DIEGETIC_SHIELD_ARC_RIGHT_OFFSET,
        self.tuning.OTHER_SIDE_DIEGETIC_SHIELD_ARC_SEGMENT_COUNT
end

function TheOtherSideGameMode:getWakeParameters(
    playerSpriteIndex,
    isFast,
    isDefaultScale,
    regularEmitterOffsets
)
    local spawnCount = self.tuning.OTHER_SIDE_WAKE_NORMAL_SPAWN_COUNT
    local speedMultiplier = self.tuning.OTHER_SIDE_WAKE_NORMAL_SPEED_MULTIPLIER
    local lengthMultiplier = 1

    if isFast then
        spawnCount = self.tuning.OTHER_SIDE_WAKE_FAST_SPAWN_COUNT
        speedMultiplier = self.tuning.OTHER_SIDE_WAKE_FAST_SPEED_MULTIPLIER
        lengthMultiplier = self.tuning.OTHER_SIDE_WAKE_FAST_LENGTH_MULTIPLIER
    end

    return self.tuning.STEAMBOAT_WAKE_EMITTER_OFFSETS[playerSpriteIndex],
        spawnCount,
        self.tuning.OTHER_SIDE_WAKE_SPAWN_INTERVAL_FRAMES,
        speedMultiplier,
        self.tuning.OTHER_SIDE_WAKE_ANGLE_SPREAD_DEGREES,
        true,
        lengthMultiplier
end

function TheOtherSideGameMode:drawPrimaryIndicator(
    currentVelocityAngle,
    drawWhiteBackground,
    uiProgress,
    uiIsDraining,
    cooldownRemainingMilliseconds,
    cooldownDurationMilliseconds,
    drawDashIndicator,
    drawHornIndicator
)
    local chargeProgress = math.clamp(uiProgress, 0, 1)
    local visibleCount

    if uiIsDraining then
        visibleCount = math.ceil(
            chargeProgress * self.tuning.DIEGETIC_DASH_CHEVRON_COUNT
        )
    elseif chargeProgress >= 1 then
        visibleCount = self.tuning.DIEGETIC_DASH_CHEVRON_COUNT
    else
        visibleCount = math.min(
            self.tuning.DIEGETIC_DASH_CHEVRON_COUNT - 1,
            math.floor(chargeProgress * self.tuning.DIEGETIC_DASH_CHEVRON_COUNT)
        )
    end

    drawHornIndicator(currentVelocityAngle, visibleCount, drawWhiteBackground)
end

function TheOtherSideGameMode:getPrimaryCooldownDuration()
    local level = math.max(0, self:getAbilityLevel("horn"))
    return self.tuning.HORN_COOLDOWN_MS_BY_LEVEL[level + 1]
end

function TheOtherSideGameMode:updatePrimaryAbilityState(
    elapsedMilliseconds,
    cooldownRemainingMilliseconds,
    cooldownDurationMilliseconds,
    uiProgress,
    uiIsDraining,
    activeRemainingMilliseconds
)
    local hornLevel = math.max(0, self:getAbilityLevel("horn"))
    local drainDurationMilliseconds =
        self.tuning.OTHER_SIDE_HORN_DURATION_MS_BY_LEVEL[hornLevel + 1]

    if activeRemainingMilliseconds > 0 then
        activeRemainingMilliseconds = math.max(
            0,
            activeRemainingMilliseconds - elapsedMilliseconds
        )

        if activeRemainingMilliseconds == 0 then
            cooldownRemainingMilliseconds = cooldownDurationMilliseconds
        end
    elseif cooldownRemainingMilliseconds > 0 then
        cooldownRemainingMilliseconds = math.max(
            0,
            cooldownRemainingMilliseconds - elapsedMilliseconds
        )
    end

    if uiIsDraining then
        uiProgress = math.max(
            0,
            uiProgress - elapsedMilliseconds / drainDurationMilliseconds
        )

        if uiProgress == 0 then
            uiIsDraining = false
        end
    elseif cooldownRemainingMilliseconds > 0 then
        uiProgress = math.clamp(
            1 - cooldownRemainingMilliseconds / cooldownDurationMilliseconds,
            0,
            1
        )
    else
        uiProgress = 1
    end

    return cooldownRemainingMilliseconds,
        uiProgress,
        uiIsDraining,
        activeRemainingMilliseconds
end

function TheOtherSideGameMode:shouldAwardSurvivalScore()
    return false
end

function TheOtherSideGameMode:getPlayerVelocity(defaultVelocity)
    return self.tuning.OTHER_SIDE_PLAYER_VELOCITY
end

function TheOtherSideGameMode:getFastModeMultiplier(defaultMultiplier)
    return self.tuning.OTHER_SIDE_FAST_MODE_MULTIPLIER
end

function TheOtherSideGameMode:getVelocityInterpolationSpeed(defaultSpeed)
    return self.tuning.OTHER_SIDE_VELOCITY_INTERPOLATION_SPEED
end

function TheOtherSideGameMode:getVisualAngle(desiredAngle, previousAngle, elapsedMilliseconds)
    local rotationDelta = (desiredAngle - previousAngle + 180) % 360 - 180
    local rotationInterpolation = 1 - math.exp(
        -self.tuning.OTHER_SIDE_ROTATION_RESPONSE_PER_SECOND * elapsedMilliseconds / 1000
    )
    return math.normalizeAngle(previousAngle + rotationDelta * rotationInterpolation)
end

function TheOtherSideGameMode:getDesiredAngleVelocity(
    velocityX,
    velocityY,
    impulseVelocityX,
    impulseVelocityY
)
    return velocityX, velocityY
end

function TheOtherSideGameMode:getEngineInitialRate()
    return self.tuning.OTHER_SIDE_ENGINE_RATE
end

function TheOtherSideGameMode:getEngineVolume(isFast)
    return self.tuning.OTHER_SIDE_ENGINE_VOLUME
end

function TheOtherSideGameMode:getEngineTargetRate(isFast, isShrunk, currentWorldVelocity)
    local targetRate = self.tuning.OTHER_SIDE_ENGINE_RATE

    if isFast then
        targetRate *= self.tuning.OTHER_SIDE_ENGINE_FAST_RATE_MULTIPLIER
    end

    return targetRate
end

function TheOtherSideGameMode:getCollisionRect(imageWidth, imageHeight)
    return self.tuning.OTHER_SIDE_COLLISION_X,
        self.tuning.OTHER_SIDE_COLLISION_Y,
        self.tuning.OTHER_SIDE_COLLISION_WIDTH,
        self.tuning.OTHER_SIDE_COLLISION_HEIGHT
end

function TheOtherSideGameMode:performPrimaryTap(crankPositionForVelocity, startDash, startHorn)
    startHorn()
end

function TheOtherSideGameMode:performSecondaryTap(startImpulse)
    startImpulse()
end

function TheOtherSideGameMode:beginRun()
    Ramp.reset()
    Steamboat.reset()
    Whirlpool.reset()
    OtherSide.beginRun()
end

function TheOtherSideGameMode:getRockSpawnLimit()
    return OtherSide.getRockSpawnLimit() or self.tuning.MAX_ROCKS
end

function TheOtherSideGameMode:getRockSpawnYRange(rock, minimumY, maximumY)
    if rock.isBig == false then
        return minimumY, maximumY
    end

    if rock.bigRockSpawnEdge == nil then
        rock.bigRockSpawnEdge = math.random(2)
    end

    local edgeY
    if rock.bigRockSpawnEdge == 1 then
        edgeY = minimumY + self.tuning.OTHER_SIDE_BIG_ROCK_EDGE_INSET
    else
        edgeY = maximumY - self.tuning.OTHER_SIDE_BIG_ROCK_EDGE_INSET
    end

    return edgeY, edgeY
end

function TheOtherSideGameMode:updateWorld(
    elapsedMilliseconds,
    worldDisplacement,
    worldVelocity,
    maximumWorldVelocity,
    playerX,
    playerY,
    playerAngle,
    rockSprites
)
    OtherSide.update(
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

function TheOtherSideGameMode:consumeTouchedDecoration(
    decorationSprites,
    playerSprite,
    decorationManager
)
    for index = 1, #decorationSprites do
        local decoration = decorationSprites[index]

        if decoration.active
            and decoration.decorationType == "bottle"
            and playerSprite:alphaCollision(decoration)
        then
            decorationManager:clearDecoration(decoration)
        end
    end
end

function TheOtherSideGameMode:resolveCollision(collision, playerSprite, shieldHitsRemaining)
    local other = collision.other

    if other.objectType == "rock" and self:isPixelPerfectCollision(collision, playerSprite) then
        if other.isBig then
            local currentTimeMilliseconds = playdate.getCurrentTimeMilliseconds()

            if currentTimeMilliseconds >= (other.nextPlayerBounceTimeMilliseconds or 0) then
                other.nextPlayerBounceTimeMilliseconds = currentTimeMilliseconds
                    + self.tuning.OTHER_SIDE_BIG_ROCK_BOUNCE_COOLDOWN_MS
                ScreenShake.start(self.tuning.OTHER_SIDE_BIG_ROCK_BOUNCE_SCREEN_SHAKE)
                return "bounceFromBigRock", shieldHitsRemaining
            end

            return nil, shieldHitsRemaining
        end

        return "destroyRockForScore", shieldHitsRemaining
    end

    if other.objectType == "otherSideSmallBoat"
        and self:isPixelPerfectCollision(collision, playerSprite)
    then
        if shieldHitsRemaining > 0 then
            local remainingShields = shieldHitsRemaining - 1

            if OtherSide.destroySmallBoat(other) then
                return "destroySmallBoat", remainingShields
            end

            return nil, remainingShields
        end

        return "crash", shieldHitsRemaining
    end

    return nil, shieldHitsRemaining
end

function TheOtherSideGameMode:getBigRockBounceResponse(
    rock,
    playerX,
    playerY,
    velocityX,
    velocityY
)
    local normalX = playerX - rock.x
    local normalY = playerY - rock.y
    local normalLength = math.sqrt(normalX * normalX + normalY * normalY)

    if normalLength < 0.001 then
        normalX = -velocityX
        normalY = -velocityY
        normalLength = math.sqrt(normalX * normalX + normalY * normalY)

        if normalLength < 0.001 then
            normalX = -1
            normalY = 0
            normalLength = 1
        end
    end

    normalX /= normalLength
    normalY /= normalLength

    local bounceForce = self.tuning.OTHER_SIDE_BIG_ROCK_BOUNCE_FORCE
    local bounceVelocityX = normalX * bounceForce
    local bounceVelocityY = normalY * bounceForce
    local verticalSeparationDirection = normalY
    local minimumVerticalForce =
        self.tuning.OTHER_SIDE_BIG_ROCK_MINIMUM_VERTICAL_BOUNCE_FORCE

    if math.abs(bounceVelocityY) < minimumVerticalForce then
        verticalSeparationDirection = playerY
                < self.tuning.OTHER_SIDE_BIG_ROCK_VERTICAL_BOUNCE_CENTER_Y
            and 1
            or -1
        bounceVelocityY = verticalSeparationDirection * minimumVerticalForce
    end

    local separation = self.tuning.OTHER_SIDE_BIG_ROCK_BOUNCE_SEPARATION

    return velocityX,
        velocityY,
        bounceVelocityX,
        bounceVelocityY,
        playerX + normalX * separation,
        playerY + verticalSeparationDirection * separation
end
