local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local tuning = nil
local smallBoatImagetable = pdg.imagetable.new("images/Boat")
local explosionImagetable = nil
local hornSoundPlayer = nil
local rockCollisionExplosionCallback = nil
local impulseRockCollisionCallback = nil
local boats = {}
local explosions = {}
local wakeLines = {}
local wakeLineCursor = 1
local spawnRemainingMilliseconds = 0
local hornRemainingMilliseconds = 0
local hornRadius = 0
local hornMaximumRadiusX = 0
local hornMaximumRadiusY = 0
local hornRadiusState = "idle"
local hornRadiusElapsedMilliseconds = 0
local hornCollapseStartRadius = 0
local hornSequence = 0
local impulseActive = false
local impulseX = 0
local impulseY = 0
local impulseAngle = 0
local impulseRadiusX = 0
local impulseRadiusY = 0
local impulseMaximumRadiusX = 0
local impulseMaximumRadiusY = 0
local impulseElapsedMilliseconds = 0
local impulseHitBoats = {}
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
    local progress = hornMaximumRadiusX > 0 and hornRadius / hornMaximumRadiusX or 0
    return hornRadius, hornMaximumRadiusY * progress
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
    boat.needsPathReplan = false
    boat.path = nil
    boat.pathIndex = 1
    boat.impulseVelocityX = 0
    boat.impulseVelocityY = 0
    boat.impulseRemainingMilliseconds = 0
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

local function getNavigationBounds(boat)
    local minimumY = tuning.HUD_HEIGHT + boat.imageHeight / 2
    local maximumY = 240 - boat.imageHeight / 2
    return minimumY, maximumY
end

local function isRockBlockingCell(boat, x, y, rocks)
    local boatHalfWidth = boat.collisionWidth / 2
    local boatHalfHeight = boat.collisionHeight / 2
    local padding = tuning.OTHER_SIDE_SMALL_BOAT_PATH_ROCK_PADDING

    for index = 1, #rocks do
        local rock = rocks[index]

        if rock.active then
            local clearanceX = rock.imageWidth / 2 + boatHalfWidth + padding
                + tuning.OTHER_SIDE_SMALL_BOAT_PATH_COLUMN_WIDTH / 2
            local clearanceY = rock.imageHeight / 2 + boatHalfHeight + padding
                + tuning.OTHER_SIDE_SMALL_BOAT_PATH_ROW_HEIGHT / 2

            if math.abs(x - rock.x) < clearanceX
                and math.abs(y - rock.y) < clearanceY
            then
                return true
            end
        end
    end

    return false
end

local function getHornPathRadii(boat)
    return hornMaximumRadiusX
            + boat.collisionWidth / 2
            + tuning.OTHER_SIDE_SMALL_BOAT_PATH_HORN_PADDING_X,
        hornMaximumRadiusY
            + boat.collisionHeight / 2
            + tuning.OTHER_SIDE_SMALL_BOAT_PATH_HORN_PADDING_Y
end

local function isHornBlockingCell(boat, x, y, playerX, playerY, playerAngle)
    if boat.warned == false or hornRemainingMilliseconds <= 0 then
        return false
    end

    local radiusX, radiusY = getHornPathRadii(boat)
    local localX, localY = toHornLocal(x - playerX, y - playerY, playerAngle)
    local normalizedDistance = localX * localX / (radiusX * radiusX)
        + localY * localY / (radiusY * radiusY)

    if normalizedDistance >= 1 then
        return false
    end

    -- A warned boat can begin inside the horn ellipse. Keep cells that lead
    -- outward open so A* can escape instead of starting inside a sealed wall.
    local boatLocalX, boatLocalY = toHornLocal(
        boat.x - playerX,
        boat.y - playerY,
        playerAngle
    )
    local boatDistance = boatLocalX * boatLocalX / (radiusX * radiusX)
        + boatLocalY * boatLocalY / (radiusY * radiusY)

    if boatDistance < 1 then
        local rowHeight = tuning.OTHER_SIDE_SMALL_BOAT_PATH_ROW_HEIGHT
        local isEscapeDirection = (
            boat.escapeToBottom and y >= boat.y - rowHeight / 2
        ) or (
            boat.escapeToBottom == false and y <= boat.y + rowHeight / 2
        )
        local escapeTolerance =
            tuning.OTHER_SIDE_SMALL_BOAT_PATH_HORN_ESCAPE_TOLERANCE

        if isEscapeDirection
            and normalizedDistance >= boatDistance - escapeTolerance
        then
            return false
        end
    end

    return true
end

local function isWarnedPlayerBlockingCell(boat, x, y, playerX, playerY)
    if boat.warned == false or hornRemainingMilliseconds > 0 then
        return false
    end

    local clearanceX = tuning.OTHER_SIDE_COLLISION_WIDTH / 2
        + boat.collisionWidth / 2
        + tuning.OTHER_SIDE_SMALL_BOAT_PATH_HORN_PADDING_X
    local clearanceY = tuning.OTHER_SIDE_COLLISION_HEIGHT / 2
        + boat.collisionHeight / 2
        + tuning.OTHER_SIDE_SMALL_BOAT_PATH_HORN_PADDING_Y
    return math.abs(x - playerX) < clearanceX
        and math.abs(y - playerY) < clearanceY
end

local function makeGoalRows(preferredRow, rowCount)
    local rows = {}

    for offset = 0, rowCount - 1 do
        local lowerRow = preferredRow - offset
        local upperRow = preferredRow + offset

        if lowerRow >= 1 then
            rows[#rows + 1] = lowerRow
        end

        if offset > 0 and upperRow <= rowCount then
            rows[#rows + 1] = upperRow
        end
    end

    return rows
end

local function compressPath(nodes, originX, minimumY)
    local waypoints = {}
    local columnWidth = tuning.OTHER_SIDE_SMALL_BOAT_PATH_COLUMN_WIDTH
    local rowHeight = tuning.OTHER_SIDE_SMALL_BOAT_PATH_ROW_HEIGHT

    for nodeIndex = 2, #nodes do
        local node = nodes[nodeIndex]
        local nextNode = nodes[nodeIndex + 1]
        local shouldAdd = nextNode == nil

        if nextNode ~= nil then
            local previousNode = nodes[nodeIndex - 1]
            local incomingX = node.x - previousNode.x
            local incomingY = node.y - previousNode.y
            local outgoingX = nextNode.x - node.x
            local outgoingY = nextNode.y - node.y
            shouldAdd = incomingX ~= outgoingX or incomingY ~= outgoingY
        end

        if shouldAdd then
            waypoints[#waypoints + 1] = {
                x = originX + (node.x - 1) * columnWidth,
                y = minimumY + (node.y - 1) * rowHeight
            }
        end
    end

    return waypoints
end

local function getNavigationGoalX(boat, playerX, playerAngle)
    if boat.warned and hornRemainingMilliseconds > 0 then
        local radiusX, radiusY = getHornPathRadii(boat)
        local majorX, _, minorX, _ = getHornAxes(playerAngle)
        local horizontalRadius = math.abs(majorX) * radiusX
            + math.abs(minorX) * radiusY
        return math.max(
            boat.x + tuning.OTHER_SIDE_SMALL_BOAT_PATH_HORN_MINIMUM_LOOKAHEAD,
            playerX + horizontalRadius
                + tuning.OTHER_SIDE_SMALL_BOAT_PATH_HORN_GOAL_CLEARANCE
        )
    end

    return math.max(
        tuning.OTHER_SIDE_SMALL_BOAT_PATH_GOAL_X,
        boat.x + tuning.OTHER_SIDE_SMALL_BOAT_PATH_MINIMUM_LOOKAHEAD
    )
end

local function planNavigationPath(
    boat,
    playerX,
    playerY,
    playerAngle,
    rocks
)
    local minimumY, maximumY = getNavigationBounds(boat)
    local columnWidth = tuning.OTHER_SIDE_SMALL_BOAT_PATH_COLUMN_WIDTH
    local rowHeight = tuning.OTHER_SIDE_SMALL_BOAT_PATH_ROW_HEIGHT
    local originX = boat.x
    local goalX = getNavigationGoalX(boat, playerX, playerAngle)
    local columnCount = math.max(2, math.ceil((goalX - originX) / columnWidth) + 1)
    local rowCount = math.max(2, math.floor((maximumY - minimumY) / rowHeight) + 1)
    local includedNodes = {}

    for row = 1, rowCount do
        local y = minimumY + (row - 1) * rowHeight

        for column = 1, columnCount do
            local x = originX + (column - 1) * columnWidth
            local isOppositeHornSide = boat.warned
                and (
                    (boat.escapeToBottom and y < playerY)
                    or (boat.escapeToBottom == false and y > playerY)
                )
            local isBlocked = isOppositeHornSide
                or isRockBlockingCell(boat, x, y, rocks)
                or isHornBlockingCell(
                    boat,
                    x,
                    y,
                    playerX,
                    playerY,
                    playerAngle
                )
                or isWarnedPlayerBlockingCell(boat, x, y, playerX, playerY)
            includedNodes[(row - 1) * columnCount + column] = isBlocked and 0 or 1
        end
    end

    local startRow = math.max(
        1,
        math.min(rowCount, math.floor((boat.y - minimumY) / rowHeight + 1.5))
    )
    local startIndex = (startRow - 1) * columnCount + 1
    includedNodes[startIndex] = 1

    local preferredY = playerY

    if boat.warned then
        local edgeInset = tuning.OTHER_SIDE_SMALL_BOAT_PATH_EDGE_INSET
        preferredY = boat.escapeToBottom
            and maximumY - edgeInset
            or minimumY + edgeInset
    end

    preferredY = math.max(minimumY, math.min(maximumY, preferredY))
    boat.targetY = preferredY
    local preferredRow = math.max(
        1,
        math.min(rowCount, math.floor((preferredY - minimumY) / rowHeight + 1.5))
    )
    local graph = playdate.pathfinder.graph.new2DGrid(
        columnCount,
        rowCount,
        true,
        includedNodes
    )
    local startNode = graph:nodeWithXY(1, startRow)
    local path = nil
    local selectedGoalRow = nil

    for _, goalRow in ipairs(makeGoalRows(preferredRow, rowCount)) do
        local goalIndex = (goalRow - 1) * columnCount + columnCount
        local goalY = minimumY + (goalRow - 1) * rowHeight
        local isOnEscapeSide = boat.warned == false
            or (boat.escapeToBottom and goalY >= playerY)
            or (boat.escapeToBottom == false and goalY <= playerY)

        if isOnEscapeSide and includedNodes[goalIndex] == 1 then
            selectedGoalRow = goalRow
            break
        end
    end

    if selectedGoalRow ~= nil then
        local goalNode = graph:nodeWithXY(columnCount, selectedGoalRow)
        path = graph:findPath(startNode, goalNode)

        if path ~= nil then
            boat.targetY = minimumY + (selectedGoalRow - 1) * rowHeight
        end
    end

    boat.path = path ~= nil and compressPath(path, originX, minimumY) or nil
    boat.pathIndex = 1
end

local function shiftNavigationPath(boat, displacement)
    if boat.path == nil then
        return
    end

    for index = boat.pathIndex, #boat.path do
        boat.path[index].x += displacement
    end
end

local function getNavigationTarget(boat)
    local waypointRadius = tuning.OTHER_SIDE_SMALL_BOAT_PATH_WAYPOINT_RADIUS

    while boat.path ~= nil and boat.pathIndex <= #boat.path do
        local waypoint = boat.path[boat.pathIndex]
        local distanceX = waypoint.x - boat.x
        local distanceY = waypoint.y - boat.y

        if distanceX * distanceX + distanceY * distanceY > waypointRadius ^ 2
            and distanceX >= -waypointRadius
        then
            return waypoint.x, waypoint.y
        end

        boat.pathIndex += 1
    end

    return boat.x + tuning.OTHER_SIDE_SMALL_BOAT_PATH_MINIMUM_LOOKAHEAD,
        boat.targetY
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
    boat.needsPathReplan = false
    boat.path = nil
    boat.pathIndex = 1
    boat.impulseVelocityX = 0
    boat.impulseVelocityY = 0
    boat.impulseRemainingMilliseconds = 0
    boat.movementAngle = 90
    boat.frameIndex = 12
    boat:setImage(smallBoatImagetable:getImage(12))
    boat:moveTo(tuning.OTHER_SIDE_SMALL_BOAT_SPAWN_X, playerY)
    planNavigationPath(boat, playerX, playerY, playerAngle, rocks)
    boat:setVisible(true)
    resetSpawnCountdown()
    return true
end

local function warnBoatsInHornRange(playerX, playerY, playerAngle)
    local radiusX, radiusY = getCurrentHornRadii()

    if radiusX <= 0 or radiusY <= 0 then
        return
    end

    for index = 1, #boats do
        local boat = boats[index]

        if boat.active then
            local localX, localY = toHornLocal(
                boat.x - playerX,
                boat.y - playerY,
                playerAngle
            )
            local normalizedDistance = localX * localX
                    / (radiusX ^ 2)
                + localY * localY
                    / (radiusY ^ 2)

            if boat.warned == false
                and normalizedDistance <= 1
            then
                boat.warned = true
                boat.escapeToBottom = boat.y >= playerY
                boat.path = nil
                boat.pathIndex = 1
                boat.needsPathReplan = true
            end
        end
    end
end

local function updateHorn(elapsedMilliseconds, playerX, playerY, playerAngle)
    local hornWasActive = hornRemainingMilliseconds > 0

    if hornRemainingMilliseconds > 0 then
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
        hornRadius = hornMaximumRadiusX * progress

        if progress >= 1 then
            hornRadius = hornMaximumRadiusX
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

    if hornWasActive then
        warnBoatsInHornRange(playerX, playerY, playerAngle)
    end
end

local function isInsideOrientedEllipse(
    x,
    y,
    halfWidth,
    halfHeight,
    centerX,
    centerY,
    angle,
    radiusX,
    radiusY
)
    local expandedRadiusX = radiusX + halfWidth
    local expandedRadiusY = radiusY + halfHeight

    if expandedRadiusX <= 0 or expandedRadiusY <= 0 then
        return false
    end

    local localX, localY = toHornLocal(x - centerX, y - centerY, angle)
    return localX * localX / (expandedRadiusX * expandedRadiusX)
        + localY * localY / (expandedRadiusY * expandedRadiusY) <= 1
end

local function throwBoatFromImpulse(boat)
    local directionX = boat.x - impulseX
    local directionY = boat.y - impulseY
    local directionLength = math.sqrt(
        directionX * directionX + directionY * directionY
    )

    if directionLength < 0.001 then
        directionX, directionY = getHornAxes(impulseAngle)
        directionLength = 1
    end

    local force = tuning.OTHER_SIDE_IMPULSE_BOAT_FORCE
    boat.impulseVelocityX = directionX / directionLength * force
    boat.impulseVelocityY = directionY / directionLength * force
    boat.impulseRemainingMilliseconds =
        tuning.OTHER_SIDE_IMPULSE_BOAT_FORCE_DURATION_MS
    boat.warned = true
    boat.escapeToBottom = directionY >= 0
    boat.path = nil
    boat.pathIndex = 1
    boat.needsPathReplan = false

    local minimumY, maximumY = getNavigationBounds(boat)
    local edgeInset = tuning.OTHER_SIDE_SMALL_BOAT_PATH_EDGE_INSET
    boat.targetY = boat.escapeToBottom
        and maximumY - edgeInset
        or minimumY + edgeInset
end

local function updateImpulse(
    elapsedMilliseconds,
    playerX,
    playerY,
    playerAngle,
    rocks
)
    if impulseActive == false then
        return
    end

    impulseElapsedMilliseconds += elapsedMilliseconds
    impulseX = playerX
    impulseY = playerY
    impulseAngle = playerAngle

    local expandDuration = tuning.OTHER_SIDE_IMPULSE_EXPAND_DURATION_MS
    local totalDuration = expandDuration + tuning.OTHER_SIDE_IMPULSE_HOLD_DURATION_MS

    if impulseElapsedMilliseconds > totalDuration then
        impulseActive = false
        impulseRadiusX = 0
        impulseRadiusY = 0
        WakeLayer.markDirty()
        return
    end

    local progress = smoothstep(impulseElapsedMilliseconds / expandDuration)
    impulseRadiusX = impulseMaximumRadiusX * progress
    impulseRadiusY = impulseMaximumRadiusY * progress

    for index = 1, #rocks do
        local rock = rocks[index]

        if rock.active and isInsideOrientedEllipse(
            rock.x,
            rock.y,
            rock.imageWidth / 2,
            rock.imageHeight / 2,
            impulseX,
            impulseY,
            impulseAngle,
            impulseRadiusX,
            impulseRadiusY
        ) then
            if impulseRockCollisionCallback ~= nil then
                impulseRockCollisionCallback(rock)
            end
        end
    end

    for index = 1, #boats do
        local boat = boats[index]

        if boat.active
            and impulseHitBoats[boat] ~= true
            and isInsideOrientedEllipse(
                boat.x,
                boat.y,
                boat.collisionWidth / 2,
                boat.collisionHeight / 2,
                impulseX,
                impulseY,
                impulseAngle,
                impulseRadiusX,
                impulseRadiusY
            )
        then
            impulseHitBoats[boat] = true
            throwBoatFromImpulse(boat)
        end
    end

    WakeLayer.markDirty()
end

function OtherSide.initialize(
    gameplayTuning,
    sfxChannel,
    sharedExplosionImagetable,
    onRockCollisionExplosion,
    onImpulseRockCollision
)
    tuning = gameplayTuning
    explosionImagetable = sharedExplosionImagetable
    rockCollisionExplosionCallback = onRockCollisionExplosion
    impulseRockCollisionCallback = onImpulseRockCollision
    hornMaximumRadiusX = tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X
    hornMaximumRadiusY = tuning.OTHER_SIDE_HORN_WARNING_RADIUS_Y
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
        boat.needsPathReplan = false
        boat.path = nil
        boat.pathIndex = 1
        boat.impulseVelocityX = 0
        boat.impulseVelocityY = 0
        boat.impulseRemainingMilliseconds = 0
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
    updateImpulse(elapsedMilliseconds, playerX, playerY, playerAngle, rocks)

    for index = 1, #boats do
        local boat = boats[index]

        if boat.active then
            updateBoatEngine(boat, currentWorldVelocity, maximumWorldVelocity)
            boat:moveBy(worldDisplacement, 0)
            shiftNavigationPath(boat, worldDisplacement)

            if boat.needsPathReplan then
                planNavigationPath(boat, playerX, playerY, playerAngle, rocks)
                boat.needsPathReplan = false
            end

            local targetSpeed = tuning.OTHER_SIDE_SMALL_BOAT_PLAYER_VELOCITY
                * tuning.OTHER_SIDE_SMALL_BOAT_FAST_MULTIPLIER
            local targetX, targetY = getNavigationTarget(boat)
            local directionX = targetX - boat.x
            local directionY = targetY - boat.y
            local directionLength = math.sqrt(
                directionX * directionX + directionY * directionY
            )
            local targetVelocityX = targetSpeed
            local targetVelocityY = 0

            if directionLength > 0 then
                targetVelocityX = directionX / directionLength * targetSpeed
                targetVelocityY = directionY / directionLength * targetSpeed
            end

            local interpolation = tuning.OTHER_SIDE_SMALL_BOAT_VELOCITY_INTERPOLATION_SPEED
            boat.velocityX += (targetVelocityX - boat.velocityX) * interpolation
            boat.velocityY += (targetVelocityY - boat.velocityY) * interpolation

            local impulseVelocityX = 0
            local impulseVelocityY = 0

            if boat.impulseRemainingMilliseconds > 0 then
                impulseVelocityX = boat.impulseVelocityX
                impulseVelocityY = boat.impulseVelocityY
                boat.impulseRemainingMilliseconds = math.max(
                    0,
                    boat.impulseRemainingMilliseconds - elapsedMilliseconds
                )

                local frameDurationMilliseconds <const> = 1000 / 30
                local retention =
                    tuning.OTHER_SIDE_IMPULSE_BOAT_FORCE_RETENTION_PER_FRAME
                        ^ (elapsedMilliseconds / frameDurationMilliseconds)
                boat.impulseVelocityX *= retention
                boat.impulseVelocityY *= retention
            end

            local minimumY, maximumY = getNavigationBounds(boat)
            local movementVelocityX = boat.velocityX + impulseVelocityX
            local movementVelocityY = boat.velocityY + impulseVelocityY
            local x = boat.x + movementVelocityX
            local unclampedY = boat.y + movementVelocityY
            local y = math.max(minimumY, math.min(maximumY, unclampedY))

            if y ~= unclampedY then
                boat.impulseVelocityY = 0
            end

            local movementAngle = (
                math.deg(math.atan2(movementVelocityY, movementVelocityX)) + 90
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

local function drawOrientedEllipse(
    centerX,
    centerY,
    angle,
    radiusX,
    radiusY,
    segmentCount
)
    local majorX, majorY, minorX, minorY = getHornAxes(angle)
    local previousX = centerX + majorX * radiusX
    local previousY = centerY + majorY * radiusX

    for segmentIndex = 1, segmentCount do
        local segmentAngle = segmentIndex * math.pi * 2 / segmentCount
        local x = centerX
            + majorX * math.cos(segmentAngle) * radiusX
            + minorX * math.sin(segmentAngle) * radiusY
        local y = centerY
            + majorY * math.cos(segmentAngle) * radiusX
            + minorY * math.sin(segmentAngle) * radiusY

        pdg.drawLine(previousX, previousY, x, y)
        previousX = x
        previousY = y
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
        drawOrientedEllipse(
            playerX,
            playerY,
            playerAngle,
            radiusX,
            radiusY,
            tuning.OTHER_SIDE_HORN_RADIUS_SEGMENT_COUNT
        )
    end

    if impulseActive and impulseRadiusX > 0 and impulseRadiusY > 0 then
        pdg.setLineWidth(tuning.OTHER_SIDE_IMPULSE_LINE_WIDTH)
        drawOrientedEllipse(
            impulseX,
            impulseY,
            impulseAngle,
            impulseRadiusX,
            impulseRadiusY,
            tuning.OTHER_SIDE_IMPULSE_SEGMENT_COUNT
        )
    end
end

function OtherSide.soundHorn(playerX, playerY, playerAngle, hornLevel)
    if running == false then
        return false
    end

    local level = math.max(
        0,
        math.min(
            tuning.MAX_ABILITY_UPGRADE_LEVEL,
            math.floor(tonumber(hornLevel) or 0)
        )
    )
    hornMaximumRadiusX = tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X
        + tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X_PER_LEVEL * level
    hornMaximumRadiusY = tuning.OTHER_SIDE_HORN_WARNING_RADIUS_Y
        + tuning.OTHER_SIDE_HORN_WARNING_RADIUS_Y_PER_LEVEL * level

    if hornSoundPlayer:isPlaying() then
        hornSoundPlayer:stop()
    end

    hornSoundPlayer:setOffset(0)
    hornSoundPlayer:setVolume(tuning.OTHER_SIDE_HORN_VOLUME)
    hornSoundPlayer:play(0)
    hornSequence += 1
    hornRemainingMilliseconds = tuning.OTHER_SIDE_HORN_DURATION_MS_BY_LEVEL[level + 1]
    hornRadius = 0
    hornRadiusState = "expanding"
    hornRadiusElapsedMilliseconds = 0
    hornCollapseStartRadius = 0

    return true
end

function OtherSide.startImpulse(playerX, playerY, playerAngle, abilityLevel)
    if running == false or impulseActive then
        return false
    end

    local level = math.max(
        0,
        math.min(
            tuning.MAX_ABILITY_UPGRADE_LEVEL,
            math.floor(tonumber(abilityLevel) or 0)
        )
    )
    local radiusMultiplier = tuning.OTHER_SIDE_IMPULSE_RADIUS_MULTIPLIER
    impulseMaximumRadiusX = (
        tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X
            + tuning.OTHER_SIDE_HORN_WARNING_RADIUS_X_PER_LEVEL * level
    ) * radiusMultiplier
    impulseMaximumRadiusY = (
        tuning.OTHER_SIDE_HORN_WARNING_RADIUS_Y
            + tuning.OTHER_SIDE_HORN_WARNING_RADIUS_Y_PER_LEVEL * level
    ) * radiusMultiplier
    impulseX = playerX
    impulseY = playerY
    impulseAngle = playerAngle
    impulseRadiusX = 0
    impulseRadiusY = 0
    impulseElapsedMilliseconds = 0
    impulseHitBoats = {}
    impulseActive = true
    WakeLayer.markDirty()
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

    if impulseActive then
        impulseX += displacement
        WakeLayer.markDirty()
    end

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
    impulseActive = false
    impulseRadiusX = 0
    impulseRadiusY = 0
    impulseElapsedMilliseconds = 0
    impulseHitBoats = {}
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
