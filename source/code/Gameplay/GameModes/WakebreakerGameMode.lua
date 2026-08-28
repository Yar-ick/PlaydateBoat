class("WakebreakerGameMode").extends(GameMode)

function WakebreakerGameMode:init(tuning)
    WakebreakerGameMode.super.init(self, tuning, {
        profileIsOtherSide = false,
        playerImagePath = "images/Boat",
        musicPath = "sounds/Banners in the Wind",
        primaryAbilityType = "dash",
        secondaryAbilityType = "shrink",
        menuBoatX = tuning.MAIN_MENU_BOAT_X,
        menuBoatY = tuning.MAIN_MENU_BOAT_Y,
        menuBoatFrameIndex = tuning.MAIN_MENU_BOAT_FRAME_INDEX,
        gameplayEntryBoatAngle = tuning.GAMEPLAY_ENTRY_BOAT_ANGLE,
        menuLaunchDurationMilliseconds = tuning.MENU_LAUNCH_DURATION_MS,
        menuLaunchCurve = tuning.MENU_LAUNCH_CURVE,
        maximumShieldHits = tuning.MAX_SHIELD_HITS,
        playerClamp = tuning.WAKEBREAKER_PLAYER_CLAMP
    })
end

function WakebreakerGameMode:isCollectableAvailable(collectableType)
    return collectableType == "coin"
        or (collectableType ~= "growth" and self:isAbilityPurchased(collectableType))
end

function WakebreakerGameMode:getWakeParameters(
    playerSpriteIndex,
    isFast,
    isDefaultScale,
    regularEmitterOffsets
)
    local spawnCount
    local spawnInterval
    local speedMultiplier
    local angleSpread = self.tuning.WAKE_SHRUNK_ANGLE_SPREAD_DEGREES

    if isFast then
        spawnCount = self.tuning.WAKE_SHRUNK_FAST_SPAWN_COUNT
        spawnInterval = self.tuning.WAKE_SHRUNK_FAST_SPAWN_INTERVAL_FRAMES
        speedMultiplier = 1.6

        if isDefaultScale then
            spawnCount = self.tuning.WAKE_DEFAULT_SCALE_FAST_SPAWN_COUNT
            spawnInterval = self.tuning.WAKE_DEFAULT_SCALE_FAST_SPAWN_INTERVAL_FRAMES
        end
    else
        spawnCount = self.tuning.WAKE_SHRUNK_NORMAL_SPAWN_COUNT
        spawnInterval = self.tuning.WAKE_SHRUNK_NORMAL_SPAWN_INTERVAL_FRAMES
        speedMultiplier = 1

        if isDefaultScale then
            spawnCount = self.tuning.WAKE_DEFAULT_SCALE_NORMAL_SPAWN_COUNT
            spawnInterval = self.tuning.WAKE_DEFAULT_SCALE_NORMAL_SPAWN_INTERVAL_FRAMES
        end
    end

    if isDefaultScale then
        angleSpread = self.tuning.WAKE_DEFAULT_SCALE_ANGLE_SPREAD_DEGREES
    end

    return regularEmitterOffsets[playerSpriteIndex],
        spawnCount,
        spawnInterval,
        speedMultiplier,
        angleSpread,
        false,
        1
end

function WakebreakerGameMode:drawPrimaryIndicator(
    currentVelocityAngle,
    drawWhiteBackground,
    uiProgress,
    uiIsDraining,
    cooldownRemainingMilliseconds,
    cooldownDurationMilliseconds,
    drawDashIndicator,
    drawHornIndicator
)
    local visibleCount = self.tuning.DIEGETIC_DASH_CHEVRON_COUNT

    if cooldownRemainingMilliseconds > 0 then
        local chargeProgress = 1
            - cooldownRemainingMilliseconds / cooldownDurationMilliseconds
        visibleCount = math.min(
            self.tuning.DIEGETIC_DASH_CHEVRON_COUNT - 1,
            math.floor(
                math.clamp(chargeProgress, 0, 1)
                    * self.tuning.DIEGETIC_DASH_CHEVRON_COUNT
            )
        )
    end

    drawDashIndicator(currentVelocityAngle, visibleCount, drawWhiteBackground)
end

function WakebreakerGameMode:getPrimaryCooldownDuration()
    local level = math.max(0, self:getAbilityLevel("dash"))
    return self.tuning.DASH_COOLDOWN_MS_BY_LEVEL[level + 1]
end

function WakebreakerGameMode:updatePrimaryAbilityState(
    elapsedMilliseconds,
    cooldownRemainingMilliseconds,
    cooldownDurationMilliseconds,
    uiProgress,
    uiIsDraining,
    activeRemainingMilliseconds
)
    local drainDurationMilliseconds = self.tuning.DASH_UI_DRAIN_DURATION_MS

    if cooldownRemainingMilliseconds > 0 then
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
        local rechargeDurationMilliseconds = math.max(
            1,
            cooldownDurationMilliseconds - drainDurationMilliseconds
        )
        uiProgress = math.clamp(
            1 - cooldownRemainingMilliseconds / rechargeDurationMilliseconds,
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

function WakebreakerGameMode:performPrimaryTap(crankPositionForVelocity, startDash, startHorn)
    startDash(crankPositionForVelocity)
end

function WakebreakerGameMode:beginRun()
    OtherSide.reset()
    Steamboat.beginRun(Difficulty.getSelectedMode().STEAMBOAT_SPAWN_CONFIG)
    Whirlpool.beginRun(Difficulty.getSelectedMode().WHIRLPOOL_SPAWN_CONFIG)
end

function WakebreakerGameMode:updateRamp(
    elapsedMilliseconds,
    worldDisplacement,
    rockSprites,
    worldVelocity,
    maximumWorldVelocity
)
    Ramp.update(
        elapsedMilliseconds,
        worldDisplacement,
        rockSprites,
        worldVelocity,
        maximumWorldVelocity
    )
end

function WakebreakerGameMode:updateWorld(
    elapsedMilliseconds,
    worldDisplacement,
    worldVelocity,
    maximumWorldVelocity,
    playerX,
    playerY,
    playerAngle,
    rockSprites
)
    Steamboat.update(elapsedMilliseconds, worldDisplacement, rockSprites)
    Whirlpool.update(elapsedMilliseconds, worldDisplacement)
end

function WakebreakerGameMode:findRampCollision(collisions, length, playerSprite)
    if BoatJump.isAirborne() then
        return nil
    end

    for index = 1, length do
        local other = collisions[index].other

        if other ~= nil
            and other.active
            and other.objectType == "ramp"
            and other.used == false
            and playerSprite:alphaCollision(other)
        then
            return other
        end
    end

    return nil
end

function WakebreakerGameMode:getWhirlpoolAttraction(
    elapsedMilliseconds,
    playerX,
    playerY,
    isAirborne,
    isFast,
    dashSpeed
)
    return Whirlpool.getAttraction(
        elapsedMilliseconds,
        playerX,
        playerY,
        isAirborne,
        isFast,
        dashSpeed,
        1,
        true
    )
end

function WakebreakerGameMode:resolveCollision(collision, playerSprite, shieldHitsRemaining)
    local other = collision.other

    if other.objectType == "rock" and self:isPixelPerfectCollision(collision, playerSprite) then
        if shieldHitsRemaining > 0 then
            return "destroyRock", shieldHitsRemaining - 1
        end

        return "crash", shieldHitsRemaining
    end

    if other.objectType == "steamboat"
        and self:isPixelPerfectCollision(collision, playerSprite)
    then
        if shieldHitsRemaining > 0 and Steamboat.explode() then
            return "explodeSteamboat", 0
        end

        return "crash", shieldHitsRemaining
    end

    return nil, shieldHitsRemaining
end
