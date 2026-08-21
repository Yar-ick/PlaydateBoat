local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local tuning = nil
local smallBoatImagetable = pdg.imagetable.new("images/Boat")
local explosionImagetable = nil
local hornSoundPlayer = nil
local rockCollisionExplosionCallback = nil
local boats = {}
local explosions = {}
local wakeLines = {}
local wakeLineCursor = 1
local spawnRemainingMilliseconds = 0
local hornRemainingMilliseconds = 0
local hornRadius = 0
local hornRadiusState = "idle"
local hornRadiusElapsedMilliseconds = 0
local hornCollapseStartRadius = 0
local hornSequence = 0
local activeRockLimit = nil
local spawnPending = false
local running = false

OtherSide = {}

local function smoothstep(progress)
    progress = math.max(0, math.min(1, progress))
    return progress * progress * (3 - 2 * progress)
end

local function getHornAxes(playerAngle)
    local angleRadians = math.rad(playerAngle)
    return math.sin(angleRadians), -math.cos(angleRadians),
        math.cos(angleRadians), math.sin(angleRadians)
end

local function toHornLocal(deltaX, deltaY, playerAngle)
    local majorX, majorY, minorX, minorY = getHornAxes(playerAngle)
    return deltaX * majorX + deltaY * majorY,
        deltaX * minorX + deltaY * minorY
end

local function getCurrentHornRadii()
    local progress = hornRadius / tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X
    return hornRadius, tuning.OTHER_SIDE_HORN_WARNING_RADIUS_Y * progress
end

local function clearWakeLines()
    for index = 1, #wakeLines do
        wakeLines[index].active = false
    end

    WakeLayer.markDirty()
end

local function spawnWakeLine(engineX, engineY, wakeAngle)
    local line = wakeLines[wakeLineCursor]
    wakeLineCursor = wakeLineCursor % #wakeLines + 1

    local angle = wakeAngle + math.random(
        -tuning.OTHER_SIDE_SMALL_BOAT_WAKE_ANGLE_SPREAD_DEGREES,
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_ANGLE_SPREAD_DEGREES
    )
    local perpendicularAngle = angle + 90
    local sideOffset = math.random(
        -tuning.OTHER_SIDE_SMALL_BOAT_WAKE_SIDE_OFFSET,
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_SIDE_OFFSET
    )

    line.active = true
    line.x = engineX + math.sin(math.rad(perpendicularAngle)) * sideOffset
    line.y = engineY - math.cos(math.rad(perpendicularAngle)) * sideOffset
    line.dx = math.sin(math.rad(angle))
    line.dy = -math.cos(math.rad(angle))
    line.speed = math.random(
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_MINIMUM_SPEED_TENTHS,
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_MAXIMUM_SPEED_TENTHS
    ) / 10
    line.length = math.random(
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_MINIMUM_LENGTH,
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_MAXIMUM_LENGTH
    )
    line.age = 0
    line.lifetime = math.random(
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_MINIMUM_LIFETIME_FRAMES,
        tuning.OTHER_SIDE_SMALL_BOAT_WAKE_MAXIMUM_LIFETIME_FRAMES
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

local function emitWake(boat)
    boat.wakeSpawnCounter += 1

    if boat.wakeSpawnCounter < tuning.OTHER_SIDE_SMALL_BOAT_WAKE_SPAWN_INTERVAL_FRAMES then
        return
    end

    local wakeAngle = (boat.movementAngle + 180) % 360
    local emitterOffset = tuning.PLAYER_WAKE_EMITTER_OFFSETS[boat.frameIndex]
    local engineX = boat.x + emitterOffset.x
    local engineY = boat.y + emitterOffset.y

    for _ = 1, tuning.OTHER_SIDE_SMALL_BOAT_WAKE_SPAWN_COUNT do
        spawnWakeLine(engineX, engineY, wakeAngle)
    end

    boat.wakeSpawnCounter = 0
end

local function resetSpawnCountdown()
    spawnRemainingMilliseconds = math.random(
        tuning.OTHER_SIDE_SMALL_BOAT_MINIMUM_INTERVAL_MS,
        tuning.OTHER_SIDE_SMALL_BOAT_MAXIMUM_INTERVAL_MS
    )
end

local function hasActiveBoat()
    for index = 1, #boats do
        if boats[index].active then
            return true
        end
    end

    return false
end

local function prepareRockField(rocks)
    local visibleRockCount = 0

    for index = 1, #rocks do
        local rock = rocks[index]

        if rock.active then
            local halfWidth = rock.imageWidth / 2
            local isFullyOffscreen = rock.x + halfWidth < 0
                or rock.x - halfWidth > 400

            if isFullyOffscreen then
                rock.active = false
                rock:setVisible(false)
            else
                visibleRockCount += 1
            end
        end
    end

    return visibleRockCount <= activeRockLimit
end

local function deactivateBoat(boat)
    boat.active = false
    boat.warned = false
    boat:setVisible(false)

    if boat.engineSoundPlayer ~= nil and boat.engineSoundPlayer:isPlaying() then
        boat.engineSoundPlayer:stop()
    end
end

local function updateBoatEngine(boat, currentWorldVelocity, maximumWorldVelocity)
    local velocityRange = maximumWorldVelocity - tuning.MIN_WORLD_VELOCITY
    local velocityProgress = 0

    if velocityRange > 0 then
        velocityProgress = math.max(
            0,
            math.min(
                1,
                (currentWorldVelocity - tuning.MIN_WORLD_VELOCITY) / velocityRange
            )
        )
    end

    local rate = tuning.ENGINE_MIN_WORLD_RATE
        + (tuning.ENGINE_MAX_WORLD_RATE - tuning.ENGINE_MIN_WORLD_RATE)
            * velocityProgress
    rate = math.min(
        tuning.ENGINE_MAX_RATE,
        rate * tuning.ENGINE_FAST_RATE_MULTIPLIER
    )
    boat.engineSoundPlayer:setRate(rate)
    boat.engineSoundPlayer:setVolume(tuning.OTHER_SIDE_SMALL_BOAT_ENGINE_VOLUME)

    if boat.engineSoundPlayer:isPlaying() == false then
        boat.engineSoundPlayer:setOffset(0)
        boat.engineSoundPlayer:play(0)
    end
end

local function startExplosion(x, y)
    local animation = pdg.animation.loop.new(
        tuning.OTHER_SIDE_SMALL_BOAT_EXPLOSION_FRAME_DELAY_MS,
        explosionImagetable,
        false
    )
    local sprite = pdg.sprite.new(animation:image())
    sprite:setZIndex(tuning.OTHER_SIDE_SMALL_BOAT_EXPLOSION_Z_INDEX)
    sprite:setScale(tuning.OTHER_SIDE_SMALL_BOAT_EXPLOSION_SCALE)
    sprite:moveTo(x, y)
    sprite:add()

    explosions[#explosions + 1] = {
        animation = animation,
        frame = animation.frame,
        sprite = sprite
    }
end

local function updateExplosions(worldDisplacement)
    for index = #explosions, 1, -1 do
        local explosion = explosions[index]
        explosion.sprite:moveBy(worldDisplacement, 0)

        if explosion.animation:isValid() == false then
            explosion.sprite:remove()
            table.remove(explosions, index)
        else
            local frame = explosion.animation.frame

            if frame ~= explosion.frame then
                explosion.frame = frame
                explosion.sprite:setImage(explosion.animation:image())
            end
        end
    end
end

local function laneScore(
    boat,
    candidateY,
    targetY,
    playerX,
    playerY,
    playerAngle,
    rocks
)
    local score = math.abs(candidateY - targetY)
    local boatHalfHeight = boat.imageHeight / 2
    local boatCollisionHalfHeight = boat.collisionHeight / 2

    for index = 1, #rocks do
        local rock = rocks[index]

        if rock.active then
            local distanceX = rock.x - boat.x

            if distanceX >= -rock.imageWidth / 2
                and distanceX <= tuning.OTHER_SIDE_SMALL_BOAT_ROCK_LOOKAHEAD
            then
                local clearance = boatHalfHeight + rock.imageHeight / 2
                    + tuning.OTHER_SIDE_SMALL_BOAT_ROCK_PADDING
                local relativeSpeed = tuning.OTHER_SIDE_SMALL_BOAT_PLAYER_VELOCITY
                    * tuning.OTHER_SIDE_SMALL_BOAT_FAST_MULTIPLIER
                local framesToRock = math.max(distanceX, 0) / relativeSpeed
                local maximumVerticalTravel = framesToRock * relativeSpeed
                local predictedY = boat.y + math.max(
                    -maximumVerticalTravel,
                    math.min(maximumVerticalTravel, candidateY - boat.y)
                )
                local distanceY = math.abs(predictedY - rock.y)

                if distanceY < clearance then
                    local proximity = 1 - math.max(distanceX, 0)
                        / tuning.OTHER_SIDE_SMALL_BOAT_ROCK_LOOKAHEAD
                    score += tuning.OTHER_SIDE_SMALL_BOAT_ROCK_PENALTY
                        * (1 + proximity)
                        * (1 - distanceY / clearance)
                end
            end
        end
    end

    if hornRemainingMilliseconds > 0 and hornRadius > 0 then
        local radiusX, radiusY = getCurrentHornRadii()
        radiusX += boat.collisionWidth / 2 + tuning.OTHER_SIDE_HORN_AVOIDANCE_PADDING
        radiusY += boatCollisionHalfHeight + tuning.OTHER_SIDE_HORN_AVOIDANCE_PADDING
        local boatLocalX, boatLocalY = toHornLocal(
            boat.x - playerX,
            boat.y - playerY,
            playerAngle
        )
        local pathX, pathY = toHornLocal(
            tuning.OTHER_SIDE_SMALL_BOAT_ROCK_LOOKAHEAD,
            candidateY - boat.y,
            playerAngle
        )
        local pathLengthSquared = pathX * pathX + pathY * pathY
        local projection = math.max(
            0,
            math.min(
                1,
                -(boatLocalX * pathX + boatLocalY * pathY) / pathLengthSquared
            )
        )
        local closestX = boatLocalX + pathX * projection
        local closestY = boatLocalY + pathY * projection
        local distance = math.sqrt(
            closestX * closestX / (radiusX * radiusX)
                + closestY * closestY / (radiusY * radiusY)
        )

        if distance < 1 then
            score += tuning.OTHER_SIDE_HORN_AVOIDANCE_PENALTY
                * (1 - distance)
        end
    end

    if boat.warned then
        local playerDistanceX = playerX - boat.x

        if playerDistanceX >= -boat.imageWidth
            and playerDistanceX <= tuning.OTHER_SIDE_SMALL_BOAT_PLAYER_LOOKAHEAD
        then
            local clearance = boatCollisionHalfHeight
                + tuning.OTHER_SIDE_PLAYER_AVOIDANCE_HALF_HEIGHT
            local distanceY = math.abs(candidateY - playerY)

            if distanceY < clearance then
                score += tuning.OTHER_SIDE_SMALL_BOAT_PLAYER_PENALTY
                    * (1 - distanceY / clearance)
            end
        end
    end

    return score
end

local function chooseLane(boat, playerX, playerY, playerAngle, rocks)
    local minimumY = tuning.HUD_HEIGHT + boat.imageHeight / 2
    local maximumY = 240 - boat.imageHeight / 2
    local targetY = playerY

    if boat.warned then
        targetY = boat.escapeToBottom and maximumY or minimumY
    end

    local bestY = math.max(minimumY, math.min(maximumY, targetY))
    local bestScore = laneScore(
        boat,
        bestY,
        targetY,
        playerX,
        playerY,
        playerAngle,
        rocks
    )

    for candidateY = minimumY, maximumY, tuning.OTHER_SIDE_SMALL_BOAT_LANE_STEP do
        local score = laneScore(
            boat,
            candidateY,
            targetY,
            playerX,
            playerY,
            playerAngle,
            rocks
        )

        if score < bestScore then
            bestScore = score
            bestY = candidateY
        end
    end

    boat.targetY = bestY
end

local function findBlockingRock(boat, rocks)
    local blockingRock = nil
    local closestDistanceX = nil

    for index = 1, #rocks do
        local rock = rocks[index]

        if rock.active then
            local distanceX = rock.x - boat.x

            if distanceX >= 0
                and distanceX <= tuning.OTHER_SIDE_SMALL_BOAT_BRAKE_LOOKAHEAD
            then
                local predictedY = boat.y + math.max(
                    -distanceX,
                    math.min(distanceX, boat.targetY - boat.y)
                )
                local clearance = boat.imageHeight / 2 + rock.imageHeight / 2
                    + tuning.OTHER_SIDE_SMALL_BOAT_COLLISION_PADDING

                if math.abs(predictedY - rock.y) < clearance
                    and (closestDistanceX == nil or distanceX < closestDistanceX)
                then
                    blockingRock = rock
                    closestDistanceX = distanceX
                end
            end
        end
    end

    return blockingRock
end

local function applyHornAvoidance(
    boat,
    playerX,
    playerY,
    playerAngle,
    targetSpeed,
    targetVelocityX,
    targetVelocityY
)
    if hornRemainingMilliseconds <= 0 or hornRadius <= 0 then
        return targetVelocityX, targetVelocityY
    end

    local localX, localY = toHornLocal(
        boat.x - playerX,
        boat.y - playerY,
        playerAngle
    )
    local radiusX, radiusY = getCurrentHornRadii()
    radiusX += boat.collisionWidth / 2 + tuning.OTHER_SIDE_HORN_AVOIDANCE_PADDING
    radiusY += boat.collisionHeight / 2 + tuning.OTHER_SIDE_HORN_AVOIDANCE_PADDING
    local responseRadiusX = radiusX + tuning.OTHER_SIDE_HORN_EMERGENCY_MARGIN
    local responseRadiusY = radiusY + tuning.OTHER_SIDE_HORN_EMERGENCY_MARGIN
    local directionAngle = math.atan2(localY, localX)
    local directionX = math.cos(directionAngle)
    local directionY = math.sin(directionAngle)
    local distance = math.sqrt(localX * localX + localY * localY)
    local avoidanceBoundary = 1 / math.sqrt(
        directionX * directionX / (radiusX * radiusX)
            + directionY * directionY / (radiusY * radiusY)
    )
    local responseBoundary = 1 / math.sqrt(
        directionX * directionX / (responseRadiusX * responseRadiusX)
            + directionY * directionY / (responseRadiusY * responseRadiusY)
    )

    if distance >= responseBoundary then
        return targetVelocityX, targetVelocityY
    end

    if boat.hornAvoidanceSequence ~= hornSequence then
        boat.hornAvoidanceSequence = hornSequence
        boat.hornAvoidanceToBottom = boat.y >= playerY
        boat.warned = true
        boat.escapeToBottom = boat.hornAvoidanceToBottom
    end

    local proximity = 1 - math.max(0, distance - avoidanceBoundary)
        / math.max(1, responseBoundary - avoidanceBoundary)
    proximity = math.max(0, math.min(1, proximity))
    local forwardMultiplier = 1 - proximity
        * (1 - tuning.OTHER_SIDE_HORN_FORWARD_SPEED_MULTIPLIER)
    local escapeMultiplier = 1 + proximity
        * (tuning.OTHER_SIDE_HORN_ESCAPE_SPEED_MULTIPLIER - 1)

    targetVelocityX *= forwardMultiplier
    targetVelocityY = (boat.hornAvoidanceToBottom and 1 or -1)
        * targetSpeed * escapeMultiplier
    return targetVelocityX, targetVelocityY
end

local function handleRockCollision(boat, rocks)
    for index = 1, #rocks do
        local rock = rocks[index]

        if rock.active
            and math.abs(boat.x - rock.x) < (boat.imageWidth + rock.imageWidth) / 2
            and math.abs(boat.y - rock.y) < (boat.imageHeight + rock.imageHeight) / 2
            and boat:alphaCollision(rock)
        then
            startExplosion(boat.x, boat.y)
            deactivateBoat(boat)

            if rockCollisionExplosionCallback ~= nil then
                rockCollisionExplosionCallback()
            end

            return true
        end
    end

    return false
end

local function spawn(playerY, rocks, playerX, playerAngle)
    local boat = nil

    for index = 1, #boats do
        if boats[index].active == false then
            boat = boats[index]
            break
        end
    end

    if boat == nil then
        resetSpawnCountdown()
        return false
    end

    boat.active = true
    boat.warned = false
    boat.escapeToBottom = false
    boat.targetY = playerY
    boat.velocityX = 0
    boat.velocityY = 0
    boat.wakeSpawnCounter = 0
    boat.replanRemainingMilliseconds = 0
    boat.movementAngle = 90
    boat.frameIndex = 12
    boat.hornAvoidanceSequence = 0
    boat.hornAvoidanceToBottom = false
    boat:setImage(smallBoatImagetable:getImage(12))
    boat:moveTo(tuning.OTHER_SIDE_SMALL_BOAT_SPAWN_X, playerY)
    chooseLane(boat, playerX, playerY, playerAngle, rocks)
    boat:setVisible(true)
    resetSpawnCountdown()
    return true
end

local function warnBoatsInHornRange(playerX, playerY, playerAngle)
    for index = 1, #boats do
        local boat = boats[index]

        if boat.active then
            local localX, localY = toHornLocal(
                boat.x - playerX,
                boat.y - playerY,
                playerAngle
            )
            local normalizedDistance = localX * localX
                    / (tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X ^ 2)
                + localY * localY
                    / (tuning.OTHER_SIDE_HORN_WARNING_RADIUS_Y ^ 2)

            if boat.warned == false
                and normalizedDistance <= 1
            then
                boat.warned = true
                boat.escapeToBottom = boat.y >= playerY
                boat.replanRemainingMilliseconds = 0
            end
        end
    end
end

local function updateHorn(elapsedMilliseconds, playerX, playerY, playerAngle)
    if hornRemainingMilliseconds > 0 then
        warnBoatsInHornRange(playerX, playerY, playerAngle)
        hornRemainingMilliseconds = math.max(
            0,
            hornRemainingMilliseconds - elapsedMilliseconds
        )

        if hornRemainingMilliseconds == 0 then
            if hornSoundPlayer:isPlaying() then
                hornSoundPlayer:stop()
            end

            hornRadiusState = "collapsing"
            hornRadiusElapsedMilliseconds = 0
            hornCollapseStartRadius = hornRadius
        end
    end

    if hornRadiusState == "expanding" then
        hornRadiusElapsedMilliseconds += elapsedMilliseconds
        local progress = smoothstep(
            hornRadiusElapsedMilliseconds
                / tuning.OTHER_SIDE_HORN_RADIUS_EXPAND_DURATION_MS
        )
        hornRadius = tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X * progress

        if progress >= 1 then
            hornRadius = tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X
            hornRadiusState = "active"
        end
    elseif hornRadiusState == "collapsing" then
        hornRadiusElapsedMilliseconds += elapsedMilliseconds
        local progress = smoothstep(
            hornRadiusElapsedMilliseconds
                / tuning.OTHER_SIDE_HORN_RADIUS_COLLAPSE_DURATION_MS
        )
        hornRadius = hornCollapseStartRadius * (1 - progress)

        if progress >= 1 then
            hornRadius = 0
            hornRadiusState = "idle"
        end
    end
end

function OtherSide.initialize(
    gameplayTuning,
    sfxChannel,
    sharedExplosionImagetable,
    onRockCollisionExplosion
)
    tuning = gameplayTuning
    explosionImagetable = sharedExplosionImagetable
    rockCollisionExplosionCallback = onRockCollisionExplosion
    hornSoundPlayer = pds.sampleplayer.new("sounds/ShipHorn")
    sfxChannel:addSource(hornSoundPlayer)

    local imageWidth, imageHeight = smallBoatImagetable:getImage(1):getSize()

    for index = 1, tuning.OTHER_SIDE_SMALL_BOAT_POOL_SIZE do
        local boat = pdg.sprite.new(smallBoatImagetable:getImage(1))
        boat.objectType = "otherSideSmallBoat"
        boat.collisionResponse = pdg.sprite.kCollisionTypeOverlap
        boat.imageWidth = imageWidth
        boat.imageHeight = imageHeight
        boat.collisionWidth = imageWidth / 3
        boat.collisionHeight = imageHeight / 5
        boat.active = false
        boat.warned = false
        boat.wakeSpawnCounter = 0
        boat.frameIndex = 1
        boat.hornAvoidanceSequence = 0
        boat.hornAvoidanceToBottom = false
        boat.engineSoundPlayer = pds.sampleplayer.new("sounds/BoatEngine")
        sfxChannel:addSource(boat.engineSoundPlayer)
        boat:setCollideRect(
            imageWidth / 3,
            imageHeight / 2,
            boat.collisionWidth,
            boat.collisionHeight
        )
        boat:setZIndex(tuning.OTHER_SIDE_SMALL_BOAT_Z_INDEX)
        boat:setVisible(false)
        boat:add()
        boats[index] = boat
    end

    for index = 1, tuning.OTHER_SIDE_SMALL_BOAT_WAKE_POOL_SIZE do
        wakeLines[index] = { active = false }
    end
end

function OtherSide.beginRun()
    OtherSide.reset()
    running = true
    resetSpawnCountdown()
end

function OtherSide.update(
    elapsedMilliseconds,
    worldDisplacement,
    currentWorldVelocity,
    maximumWorldVelocity,
    playerX,
    playerY,
    playerAngle,
    rocks
)
    updateExplosions(worldDisplacement)
    updateWakeLines(worldDisplacement, running)

    if running == false then
        return
    end

    spawnRemainingMilliseconds -= elapsedMilliseconds
    if spawnRemainingMilliseconds <= 0 then
        if spawnPending == false then
            spawnPending = true

            if hasActiveBoat() == false then
                activeRockLimit = math.random(
                    tuning.OTHER_SIDE_SMALL_BOAT_MINIMUM_ROCK_COUNT,
                    tuning.OTHER_SIDE_SMALL_BOAT_MAXIMUM_ROCK_COUNT
                )
            end
        end

        if prepareRockField(rocks) then
            spawn(playerY, rocks, playerX, playerAngle)
            spawnPending = false
        end
    end

    updateHorn(elapsedMilliseconds, playerX, playerY, playerAngle)

    for index = 1, #boats do
        local boat = boats[index]

        if boat.active then
            updateBoatEngine(boat, currentWorldVelocity, maximumWorldVelocity)
            boat.replanRemainingMilliseconds -= elapsedMilliseconds

            if boat.replanRemainingMilliseconds <= 0 then
                chooseLane(boat, playerX, playerY, playerAngle, rocks)
                boat.replanRemainingMilliseconds =
                    tuning.OTHER_SIDE_SMALL_BOAT_REPLAN_INTERVAL_MS
            end

            local targetSpeed = tuning.OTHER_SIDE_SMALL_BOAT_PLAYER_VELOCITY
                * tuning.OTHER_SIDE_SMALL_BOAT_FAST_MULTIPLIER
            local directionX = tuning.OTHER_SIDE_SMALL_BOAT_ROCK_LOOKAHEAD
            local directionY = boat.targetY - boat.y
            local directionLength = math.sqrt(
                directionX * directionX + directionY * directionY
            )
            local targetVelocityX = directionX / directionLength * targetSpeed
            local targetVelocityY = directionY / directionLength * targetSpeed
            local blockingRock = findBlockingRock(boat, rocks)

            if blockingRock ~= nil then
                local escapeDirection = boat.targetY < blockingRock.y and -1 or 1

                if math.abs(boat.targetY - blockingRock.y) < 1 then
                    escapeDirection = boat.y < blockingRock.y and -1 or 1
                end

                targetVelocityX = 0
                targetVelocityY = escapeDirection * targetSpeed
            end

            targetVelocityX, targetVelocityY = applyHornAvoidance(
                boat,
                playerX,
                playerY,
                playerAngle,
                targetSpeed,
                targetVelocityX,
                targetVelocityY
            )

            local interpolation = tuning.OTHER_SIDE_SMALL_BOAT_VELOCITY_INTERPOLATION_SPEED
            boat.velocityX += (targetVelocityX - boat.velocityX) * interpolation
            boat.velocityY += (targetVelocityY - boat.velocityY) * interpolation

            local minimumY = tuning.HUD_HEIGHT + boat.imageHeight / 2
            local maximumY = 240 - boat.imageHeight / 2
            local x = boat.x + worldDisplacement + boat.velocityX
            local y = math.max(minimumY, math.min(maximumY, boat.y + boat.velocityY))
            local movementAngle = (
                math.deg(math.atan2(boat.velocityY, boat.velocityX)) + 90
            ) % 360
            local frame = math.max(
                1,
                math.min(
                    smallBoatImagetable:getLength(),
                    math.ceil(movementAngle / (360 / smallBoatImagetable:getLength()))
                )
            )

            boat.movementAngle = movementAngle
            boat.frameIndex = frame
            boat:setImage(smallBoatImagetable:getImage(frame))
            boat:moveTo(x, y)

            if handleRockCollision(boat, rocks) == false then
                emitWake(boat)
            end

            if boat.active and boat.x - boat.imageWidth / 2 > 400 then
                deactivateBoat(boat)
            end
        end
    end
end

function OtherSide.drawWakeLines(playerX, playerY, playerAngle)
    for index = 1, #wakeLines do
        local line = wakeLines[index]

        if line.active then
            local lifeProgress = line.age / line.lifetime
            local lineLength = line.length * (1 - lifeProgress)

            pdg.setLineWidth(1)
            pdg.drawLine(
                line.x,
                line.y,
                line.x + line.dx * lineLength,
                line.y + line.dy * lineLength
            )
        end
    end

    if hornRadius > 0 then
        pdg.setLineWidth(tuning.OTHER_SIDE_HORN_RADIUS_LINE_WIDTH)
        local radiusX, radiusY = getCurrentHornRadii()
        local majorX, majorY, minorX, minorY = getHornAxes(playerAngle)
        local previousX = playerX + majorX * radiusX
        local previousY = playerY + majorY * radiusX

        for segmentIndex = 1, tuning.OTHER_SIDE_HORN_RADIUS_SEGMENT_COUNT do
            local angle = segmentIndex * math.pi * 2
                / tuning.OTHER_SIDE_HORN_RADIUS_SEGMENT_COUNT
            local x = playerX
                + majorX * math.cos(angle) * radiusX
                + minorX * math.sin(angle) * radiusY
            local y = playerY
                + majorY * math.cos(angle) * radiusX
                + minorY * math.sin(angle) * radiusY

            pdg.drawLine(previousX, previousY, x, y)
            previousX = x
            previousY = y
        end
    end
end

function OtherSide.soundHorn(playerX, playerY, playerAngle)
    if running == false then
        return false
    end

    if hornSoundPlayer:isPlaying() then
        hornSoundPlayer:stop()
    end

    hornSoundPlayer:setOffset(0)
    hornSoundPlayer:setVolume(tuning.OTHER_SIDE_HORN_VOLUME)
    hornSoundPlayer:play()
    hornSequence += 1
    hornRemainingMilliseconds = tuning.OTHER_SIDE_HORN_DURATION_MS
    hornRadius = 0
    hornRadiusState = "expanding"
    hornRadiusElapsedMilliseconds = 0
    hornCollapseStartRadius = 0
    warnBoatsInHornRange(playerX, playerY, playerAngle)

    return true
end

function OtherSide.getRockSpawnLimit()
    if running == false then
        return nil
    end

    if spawnPending then
        return 0
    end

    if hasActiveBoat() then
        return activeRockLimit
    end

    return nil
end

function OtherSide.destroySmallBoat(boat)
    if boat == nil or boat.objectType ~= "otherSideSmallBoat" or boat.active == false then
        return false
    end

    startExplosion(boat.x, boat.y)
    deactivateBoat(boat)
    return true
end

function OtherSide.rewind(displacement)
    local remaining = 0

    for index = 1, #boats do
        local boat = boats[index]

        if boat.active then
            boat:moveBy(displacement, 0)

            if boat.x + boat.imageWidth / 2 < 0 then
                deactivateBoat(boat)
            else
                remaining += 1
            end
        end
    end

    updateExplosions(displacement)
    updateWakeLines(displacement, false)
    return remaining
end

function OtherSide.stopSounds()
    hornRemainingMilliseconds = 0
    hornRadius = 0
    hornRadiusState = "idle"
    hornRadiusElapsedMilliseconds = 0
    hornCollapseStartRadius = 0

    if hornSoundPlayer ~= nil and hornSoundPlayer:isPlaying() then
        hornSoundPlayer:stop()
    end

    for index = 1, #boats do
        local engineSoundPlayer = boats[index].engineSoundPlayer

        if engineSoundPlayer ~= nil and engineSoundPlayer:isPlaying() then
            engineSoundPlayer:stop()
        end
    end
end

function OtherSide.reset()
    running = false
    spawnRemainingMilliseconds = 0
    activeRockLimit = nil
    spawnPending = false
    OtherSide.stopSounds()

    for index = 1, #boats do
        deactivateBoat(boats[index])
    end

    for index = 1, #explosions do
        explosions[index].sprite:remove()
    end

    explosions = {}
    clearWakeLines()
end
