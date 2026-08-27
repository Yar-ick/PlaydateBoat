local tuning = nil
local airborne = false
local elapsedMilliseconds = 0
local durationMilliseconds = 1
local rockSpawnPauseRemainingMilliseconds = 0
local scale = 1
local launchDirectionAngle = 0

BoatJump = {}

function BoatJump.initialize(gameplayTuning)
    tuning = gameplayTuning
    BoatJump.reset()
end

function BoatJump.start(
    takeoffSpeed,
    isFastMode,
    launchVelocityX,
    launchVelocityY,
    fallbackVisualAngle
)
    if airborne then
        return false
    end

    airborne = true
    elapsedMilliseconds = 0
    durationMilliseconds = tuning.RAMP_JUMP_BASE_DURATION_MS
        + math.max(0, takeoffSpeed) * tuning.RAMP_JUMP_DURATION_PER_SPEED_MS

    if isFastMode then
        durationMilliseconds *= tuning.RAMP_JUMP_FAST_MODE_DURATION_MULTIPLIER
    end

    durationMilliseconds = math.min(
        tuning.RAMP_JUMP_MAX_DURATION_MS,
        durationMilliseconds
    )

    if math.abs(launchVelocityX) + math.abs(launchVelocityY) > 0.001 then
        launchDirectionAngle = math.atan2(launchVelocityY, launchVelocityX)
    else
        launchDirectionAngle = math.rad((fallbackVisualAngle or 0) - 90)
    end

    scale = 1
    return true
end

function BoatJump.constrainTranslation(velocityX, velocityY)
    if airborne == false then
        return velocityX, velocityY
    end

    local speed = math.sqrt(velocityX * velocityX + velocityY * velocityY)

    if speed <= 0.001 then
        return 0, 0
    end

    local requestedAngle = math.atan2(velocityY, velocityX)
    local angleDelta = (requestedAngle - launchDirectionAngle + math.pi)
        % (math.pi * 2) - math.pi
    local maximumDeviation = math.rad(
        tuning.RAMP_AIRBORNE_TRANSLATION_MAX_DEVIATION_DEGREES
    )
    local constrainedAngle = launchDirectionAngle
        + math.max(-maximumDeviation, math.min(maximumDeviation, angleDelta))

    return math.cos(constrainedAngle) * speed,
        math.sin(constrainedAngle) * speed
end

function BoatJump.update(frameElapsedMilliseconds)
    if airborne == false then
        scale = 1

        if rockSpawnPauseRemainingMilliseconds > 0 then
            rockSpawnPauseRemainingMilliseconds = math.max(
                0,
                rockSpawnPauseRemainingMilliseconds - frameElapsedMilliseconds
            )
        end

        return false
    end

    elapsedMilliseconds += frameElapsedMilliseconds
    local progress = math.min(1, elapsedMilliseconds / durationMilliseconds)
    scale = 1 + math.sin(progress * math.pi) * tuning.RAMP_JUMP_SCALE_INCREASE

    if progress >= 1 then
        airborne = false
        elapsedMilliseconds = 0
        rockSpawnPauseRemainingMilliseconds = tuning.RAMP_LANDING_ROCK_SPAWN_PAUSE_MS
        scale = 1
        return true
    end

    return false
end

function BoatJump.reset()
    airborne = false
    elapsedMilliseconds = 0
    durationMilliseconds = 1
    rockSpawnPauseRemainingMilliseconds = 0
    scale = 1
    launchDirectionAngle = 0
end

function BoatJump.isAirborne()
    return airborne
end

function BoatJump.shouldPauseRockSpawning()
    return airborne or rockSpawnPauseRemainingMilliseconds > 0
end

function BoatJump.getScale()
    return scale
end
