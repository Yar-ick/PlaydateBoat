local pdg <const> = playdate.graphics

local rampImage = pdg.image.new("images/Ramp")
local rampSprite = nil
local approachReservation = nil
local tuning = nil
local interactableObjectGroups = nil
local spawnRemainingMilliseconds = 0
local rampWidth, rampHeight = rampImage:getSize()
local protectedRocks = {}
local formationRocks = {}
local formationLineX = 0
local hasEnteredScreen = false
local screenEntryPending = false
local challengeStarted = false
local previousPlayerRelativeX = nil
local rewardAwarded = false

Ramp = {}

local function resetSpawnCountdown()
    spawnRemainingMilliseconds = math.random(
        tuning.RAMP_MINIMUM_INTERVAL_MS,
        tuning.RAMP_MAXIMUM_INTERVAL_MS
    )
end

local function clearChallenge()
    protectedRocks = {}
    formationRocks = {}
    formationLineX = 0
    challengeStarted = false
    previousPlayerRelativeX = nil
    rewardAwarded = false
end

local function positionOverlapsInteractable(x, y, width, height, excludedObjects)
    for groupIndex = 1, #interactableObjectGroups do
        local objects = interactableObjectGroups[groupIndex]

        for objectIndex = 1, #objects do
            local object = objects[objectIndex]

            if object ~= rampSprite
                and object ~= approachReservation
                and object.active == true
                and excludedObjects[object] ~= true
            then
                local horizontalDistance = math.abs(x - object.x)
                local verticalDistance = math.abs(y - object.y)
                local minimumHorizontalDistance = (width + object.imageWidth) / 2
                    + tuning.INTERACTIVE_SPAWN_PADDING
                local minimumVerticalDistance = (height + object.imageHeight) / 2
                    + tuning.INTERACTIVE_SPAWN_PADDING

                if horizontalDistance < minimumHorizontalDistance
                    and verticalDistance < minimumVerticalDistance
                then
                    return true
                end
            end
        end
    end

    return false
end

local function getApproachX(rampX)
    return rampX + rampWidth / 2 + tuning.RAMP_APPROACH_GAP
        + tuning.RAMP_APPROACH_WIDTH / 2
end

local function updateApproachReservationPosition()
    approachReservation.x = getApproachX(rampSprite.x)
    approachReservation.y = rampSprite.y
end

local function getOffscreenRocks(rockSprites)
    local rocks = {}

    for index = 1, #rockSprites do
        local rock = rockSprites[index]

        if rock.active and rock.x + rock.imageWidth / 2 < 0 then
            rocks[#rocks + 1] = rock
        end
    end

    return rocks
end

local function chooseFormationRocks(availableRocks)
    local selected = {}
    local excludedIndexes = {}

    while #selected < tuning.RAMP_FORMATION_ROCK_COUNT do
        local index = math.random(#availableRocks)

        if excludedIndexes[index] ~= true then
            excludedIndexes[index] = true
            selected[#selected + 1] = availableRocks[index]
        end
    end

    return selected
end

local function tryBuildFormation(availableRocks)
    for _ = 1, tuning.RAMP_FORMATION_PLACEMENT_ATTEMPTS do
        local selectedRocks = chooseFormationRocks(availableRocks)
        local excludedObjects = {}
        local maximumRockWidth = 0
        local lineX = selectedRocks[1].x
        local centerY = math.random(
            tuning.RAMP_FORMATION_MINIMUM_CENTER_Y,
            tuning.RAMP_FORMATION_MAXIMUM_CENTER_Y
        )
        local rampY = math.random(
            tuning.RAMP_SPAWN_MINIMUM_Y,
            tuning.RAMP_SPAWN_MAXIMUM_Y
        )
        local firstY = centerY
            - (tuning.RAMP_FORMATION_ROCK_COUNT - 1)
                * tuning.RAMP_FORMATION_VERTICAL_SPACING / 2

        for index = 1, #selectedRocks do
            local rock = selectedRocks[index]
            excludedObjects[rock] = true
            maximumRockWidth = math.max(maximumRockWidth, rock.imageWidth)
        end

        local rampX = lineX + maximumRockWidth / 2 + rampWidth / 2
            + tuning.RAMP_ROCK_GAP
        local approachX = getApproachX(rampX)
        local isValid = rampX >= tuning.RAMP_SPAWN_MINIMUM_X
            and rampX + rampWidth / 2 <= tuning.RAMP_SPAWN_MAXIMUM_X
            and positionOverlapsInteractable(
                rampX,
                rampY,
                rampWidth,
                rampHeight,
                excludedObjects
            ) == false
            and positionOverlapsInteractable(
                approachX,
                rampY,
                tuning.RAMP_APPROACH_WIDTH,
                tuning.RAMP_APPROACH_HEIGHT,
                excludedObjects
            ) == false

        if isValid then
            for index = 1, #selectedRocks do
                local rock = selectedRocks[index]
                local y = firstY + (index - 1) * tuning.RAMP_FORMATION_VERTICAL_SPACING

                if positionOverlapsInteractable(
                    lineX,
                    y,
                    rock.imageWidth,
                    rock.imageHeight,
                    excludedObjects
                ) then
                    isValid = false
                    break
                end
            end
        end

        if isValid then
            return {
                rocks = selectedRocks,
                lineX = lineX,
                firstY = firstY,
                rampX = rampX,
                rampY = rampY
            }
        end
    end

    return nil
end

local function activateFormation(formation)
    clearChallenge()
    formationRocks = formation.rocks
    formationLineX = formation.lineX

    for index = 1, #formationRocks do
        local rock = formationRocks[index]
        local y = formation.firstY
            + (index - 1) * tuning.RAMP_FORMATION_VERTICAL_SPACING

        rock:moveTo(formationLineX, y)
        rock.active = true
        rock:setVisible(true)
        protectedRocks[rock] = true
    end

    rampSprite:moveTo(formation.rampX, formation.rampY)
    rampSprite.active = true
    rampSprite.used = false
    rampSprite:setVisible(true)
    hasEnteredScreen = false
    screenEntryPending = false
    approachReservation.active = true
    updateApproachReservationPosition()
end

local function trySpawn(rockSprites)
    local availableRocks = getOffscreenRocks(rockSprites)

    if #availableRocks < tuning.RAMP_FORMATION_ROCK_COUNT then
        spawnRemainingMilliseconds = tuning.RAMP_RETRY_INTERVAL_MS
        return false
    end

    if math.random() * 100 > tuning.RAMP_SPAWN_CHANCE_PERCENT then
        resetSpawnCountdown()
        return false
    end

    local formation = tryBuildFormation(availableRocks)

    if formation == nil then
        spawnRemainingMilliseconds = tuning.RAMP_RETRY_INTERVAL_MS
        return false
    end

    activateFormation(formation)
    return true
end

function Ramp.initialize(gameplayTuning, objectGroups)
    tuning = gameplayTuning
    interactableObjectGroups = objectGroups

    rampSprite = pdg.sprite.new(rampImage)
    rampSprite.objectType = "ramp"
    rampSprite.collisionResponse = pdg.sprite.kCollisionTypeOverlap
    rampSprite.imageWidth = rampWidth
    rampSprite.imageHeight = rampHeight
    rampSprite.active = false
    rampSprite.used = false
    rampSprite:setCollideRect(0, 0, rampWidth, rampHeight)
    rampSprite:setZIndex(tuning.RAMP_Z_INDEX)
    rampSprite:moveTo(-rampWidth, -rampHeight)
    rampSprite:setVisible(false)
    rampSprite:add()

    approachReservation = {
        active = false,
        x = rampSprite.x,
        y = rampSprite.y,
        imageWidth = tuning.RAMP_APPROACH_WIDTH,
        imageHeight = tuning.RAMP_APPROACH_HEIGHT
    }

    objectGroups[#objectGroups + 1] = { rampSprite, approachReservation }
    clearChallenge()
    resetSpawnCountdown()
end

function Ramp.update(
    elapsedMilliseconds,
    worldDisplacement,
    rockSprites,
    currentWorldVelocity,
    maximumWorldVelocity
)
    if rampSprite.active then
        rampSprite:moveBy(worldDisplacement, 0)
        formationLineX += worldDisplacement
        updateApproachReservationPosition()

        if hasEnteredScreen == false
            and rampSprite.x + rampWidth / 2
                >= tuning.RAMP_ROCK_SPAWN_PAUSE_START_X
        then
            hasEnteredScreen = true
            screenEntryPending = true
        end

        if rampSprite.x - rampWidth / 2 > 400 then
            rampSprite.active = false
            rampSprite.used = false
            rampSprite:setVisible(false)
            approachReservation.active = false
            clearChallenge()
            resetSpawnCountdown()
        end

        return
    end

    local minimumRampVelocity = maximumWorldVelocity
        * tuning.RAMP_MINIMUM_MAX_SPEED_FRACTION

    if currentWorldVelocity < minimumRampVelocity then
        return
    end

    spawnRemainingMilliseconds -= elapsedMilliseconds

    if spawnRemainingMilliseconds <= 0 then
        trySpawn(rockSprites)
    end
end

function Ramp.shouldPauseRockSpawning()
    return rampSprite.active
        and rampSprite.x + rampWidth / 2 >= tuning.RAMP_ROCK_SPAWN_PAUSE_START_X
end

function Ramp.consumeScreenEntry()
    if screenEntryPending == false then
        return false
    end

    screenEntryPending = false
    return true
end

function Ramp.isProtectedRock(rock)
    return protectedRocks[rock] == true
end

function Ramp.markUsed(sprite, playerX)
    if sprite == rampSprite then
        rampSprite.used = true
        approachReservation.active = false
        challengeStarted = true
        previousPlayerRelativeX = playerX - formationLineX
    end
end

function Ramp.updateJumpChallenge(playerX, isJumpActive)
    if challengeStarted == false or rewardAwarded or isJumpActive == false then
        return false
    end

    local relativeX = playerX - formationLineX

    if previousPlayerRelativeX ~= nil
        and previousPlayerRelativeX > 0
        and relativeX <= 0
    then
        rewardAwarded = true
        challengeStarted = false
        return true
    end

    previousPlayerRelativeX = relativeX
    return false
end

function Ramp.reset()
    if rampSprite == nil then
        return
    end

    rampSprite.active = false
    rampSprite.used = false
    rampSprite:setVisible(false)
    rampSprite:moveTo(-rampWidth, -rampHeight)
    approachReservation.active = false
    updateApproachReservationPosition()
    clearChallenge()
    hasEnteredScreen = false
    screenEntryPending = false
    resetSpawnCountdown()
end

function Ramp.rewind(displacement)
    if rampSprite.active == false then
        return 0
    end

    rampSprite:moveBy(displacement, 0)
    formationLineX += displacement
    updateApproachReservationPosition()

    if rampSprite.x + rampWidth / 2 < 0 then
        rampSprite.active = false
        rampSprite.used = false
        rampSprite:setVisible(false)
        approachReservation.active = false
        clearChallenge()
        hasEnteredScreen = false
        screenEntryPending = false
        resetSpawnCountdown()
        return 0
    end

    return 1
end
