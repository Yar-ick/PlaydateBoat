local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local oilStainAssetImages <const> = {
    pdg.image.new("images/OilStain1"),
    pdg.image.new("images/OilStain2"),
    pdg.image.new("images/OilStain3")
}
local oilStainVariants = {}

local tuning = nil
local interactableObjectGroups = nil
local cleanSoundPlayers = {}
local cleanSoundPlayerCursor = 1
local currentCleanSoundPlayer = nil
local cleanSoundQueued = false
local cleanedCallback = nil
local stains = {}
local spawnRemainingMilliseconds = 0
local running = false
local pendingScoreValue = 0
local pendingScoreDelayMilliseconds = 0
local pendingScoreX = 0
local pendingScoreY = 0

OilStains = {}

local function makeTrimmedOilStainImage(assetImage)
    local assetWidth, assetHeight = assetImage:getSize()
    local minimumX = assetWidth
    local minimumY = assetHeight
    local maximumX = -1
    local maximumY = -1

    for y = 0, assetHeight - 1 do
        for x = 0, assetWidth - 1 do
            if assetImage:sample(x, y) ~= pdg.kColorClear then
                minimumX = math.min(minimumX, x)
                minimumY = math.min(minimumY, y)
                maximumX = math.max(maximumX, x)
                maximumY = math.max(maximumY, y)
            end
        end
    end

    if maximumX < minimumX or maximumY < minimumY then
        return assetImage:copy()
    end

    local padding <const> = 1
    local imageWidth = maximumX - minimumX + 1 + padding * 2
    local imageHeight = maximumY - minimumY + 1 + padding * 2
    local image = pdg.image.new(imageWidth, imageHeight)

    pdg.pushContext(image)
    assetImage:draw(padding - minimumX, padding - minimumY)
    pdg.popContext()
    return image
end

local function smoothstep(progress)
    progress = math.max(0, math.min(1, progress))
    return progress * progress * (3 - 2 * progress)
end

local function resetSpawnCountdown()
    spawnRemainingMilliseconds = math.random(
        tuning.OTHER_SIDE_OIL_MINIMUM_SPAWN_INTERVAL_MS,
        tuning.OTHER_SIDE_OIL_MAXIMUM_SPAWN_INTERVAL_MS
    )
end

local function resetCoverage(stain)
    stain.remainingCoverageCount = #stain.coveragePoints
    stain.awardedScoreSteps = 0

    for index = 1, #stain.coveragePoints do
        stain.coverageCleaned[index] = false
    end
end

local function deactivate(stain)
    stain.active = false
    stain.isAppearing = false
    stain.appearElapsedMilliseconds = 0
    stain.cleanedOnPreviousFrame = false
    stain.lastCleanLocalX = nil
    stain.lastCleanLocalY = nil
    stain:setScale(1)
    stain:setVisible(false)

    if stain.oilAdded then
        stain:remove()
        stain.oilAdded = false
    end
end

local function startCleanSound()
    local soundPlayer = cleanSoundPlayers[cleanSoundPlayerCursor]
    cleanSoundPlayerCursor = cleanSoundPlayerCursor % #cleanSoundPlayers + 1

    if soundPlayer:isPlaying() then
        soundPlayer:stop()
    end

    cleanSoundQueued = false
    soundPlayer:setOffset(0)
    soundPlayer:play()
    currentCleanSoundPlayer = soundPlayer
end

local function playCleanSound()
    if currentCleanSoundPlayer ~= nil
        and currentCleanSoundPlayer:isPlaying()
    then
        cleanSoundQueued = true
        return
    end

    startCleanSound()
end

local function updateCleanSound()
    if cleanSoundQueued == false or currentCleanSoundPlayer == nil then
        return
    end

    local canStartNext = currentCleanSoundPlayer:isPlaying() == false

    if canStartNext == false then
        local soundProgress = currentCleanSoundPlayer:getOffset()
            / math.max(0.001, currentCleanSoundPlayer:getLength())
        canStartNext = soundProgress
            >= tuning.OTHER_SIDE_OIL_CLEAN_SOUND_RETRIGGER_PROGRESS
    end

    if canStartNext then
        startCleanSound()
    end
end

local function queueCleanScore(x, y, scoreValue)
    pendingScoreValue += scoreValue
    pendingScoreDelayMilliseconds = tuning.OTHER_SIDE_OIL_SCORE_DELAY_MS
    pendingScoreX = x
    pendingScoreY = y
end

local function updatePendingScore(elapsedMilliseconds)
    if pendingScoreValue <= 0 then
        return
    end

    pendingScoreDelayMilliseconds = math.max(
        0,
        pendingScoreDelayMilliseconds - elapsedMilliseconds
    )

    if pendingScoreDelayMilliseconds == 0 then
        if cleanedCallback ~= nil then
            cleanedCallback(pendingScoreX, pendingScoreY, pendingScoreValue)
        end

        pendingScoreValue = 0
    end
end

local function findInactiveStain()
    for index = 1, #stains do
        if stains[index].active == false then
            return stains[index]
        end
    end

    return nil
end

local function hasActiveStain()
    for index = 1, #stains do
        if stains[index].active then
            return true
        end
    end

    return false
end

local function activateStain(
    stain,
    x,
    y,
    shouldAnimateAppearance,
    variantIndex
)
    variantIndex = variantIndex or math.random(1, #oilStainVariants)
    local variant = oilStainVariants[variantIndex]
    stain.image = stain.variantImages[variantIndex]
    stain.image:setMaskImage(variant.sourceMask)
    stain.mask = stain.image:getMaskImage()
    stain.coveragePoints = variant.coveragePoints
    stain.imageWidth = variant.imageWidth
    stain.imageHeight = variant.imageHeight
    stain.active = true
    stain.isAppearing = shouldAnimateAppearance == true
    stain.appearElapsedMilliseconds = 0
    stain.cleanedOnPreviousFrame = false
    stain.lastCleanLocalX = nil
    stain.lastCleanLocalY = nil
    resetCoverage(stain)
    stain:setImage(stain.image)
    local cleaningReach = tuning.OTHER_SIDE_OIL_CLEAN_BRUSH_RADIUS
    stain:setCollideRect(
        -cleaningReach,
        -cleaningReach,
        stain.imageWidth + cleaningReach * 2,
        stain.imageHeight + cleaningReach * 2
    )
    stain:setScale(stain.isAppearing and 0 or 1)
    stain:moveTo(x, y)
    stain:setVisible(true)
    stain:markDirty()

    if stain.oilAdded == false then
        stain:add()
        stain.oilAdded = true
    end
end

local function spawnAtAvailableStain(x, y, shouldAnimateAppearance)
    local stain = findInactiveStain()

    if stain == nil then
        return false
    end

    activateStain(stain, x, y, shouldAnimateAppearance)
    return true
end

local function spawnWorldStain()
    local stain = findInactiveStain()

    if stain == nil then
        return false
    end

    local variantIndex = math.random(1, #oilStainVariants)
    local variant = oilStainVariants[variantIndex]
    local x, y = InteractiveSpawn.findPosition(
        interactableObjectGroups,
        stain,
        variant.imageWidth,
        variant.imageHeight,
        tuning.OTHER_SIDE_OIL_SPAWN_MINIMUM_X,
        -variant.imageWidth / 2,
        tuning.WORLD_SPAWN_MINIMUM_Y + variant.imageHeight / 2,
        tuning.WORLD_SPAWN_MAXIMUM_Y - variant.imageHeight / 2,
        tuning.INTERACTIVE_SPAWN_PADDING,
        tuning.INTERACTIVE_SPAWN_ATTEMPTS
    )

    if x == nil then
        return false
    end

    activateStain(stain, x, y, false, variantIndex)
    return true
end

local function squaredDistanceToSegment(
    pointX,
    pointY,
    startX,
    startY,
    endX,
    endY
)
    local segmentX = endX - startX
    local segmentY = endY - startY
    local segmentLengthSquared = segmentX * segmentX + segmentY * segmentY

    if segmentLengthSquared <= 0 then
        local distanceX = pointX - endX
        local distanceY = pointY - endY
        return distanceX * distanceX + distanceY * distanceY
    end

    local progress = ((pointX - startX) * segmentX
        + (pointY - startY) * segmentY) / segmentLengthSquared
    progress = math.max(0, math.min(1, progress))
    local closestX = startX + segmentX * progress
    local closestY = startY + segmentY * progress
    local distanceX = pointX - closestX
    local distanceY = pointY - closestY
    return distanceX * distanceX + distanceY * distanceY
end

local function eraseMaskPath(stain, startX, startY, endX, endY)
    local brushRadius = tuning.OTHER_SIDE_OIL_CLEAN_BRUSH_RADIUS

    pdg.pushContext(stain.mask)
    pdg.setColor(pdg.kColorBlack)
    pdg.setLineWidth(brushRadius * 2)
    pdg.drawLine(startX, startY, endX, endY)
    pdg.fillCircleAtPoint(startX, startY, brushRadius)
    pdg.fillCircleAtPoint(endX, endY, brushRadius)
    pdg.popContext()
    stain:markDirty()
end

local function updateCleanedCoverage(stain, startX, startY, endX, endY)
    local brushRadiusSquared = tuning.OTHER_SIDE_OIL_CLEAN_BRUSH_RADIUS ^ 2
    local newlyCleanedCount = 0

    for index = 1, #stain.coveragePoints do
        if stain.coverageCleaned[index] == false then
            local point = stain.coveragePoints[index]

            if squaredDistanceToSegment(
                point.x,
                point.y,
                startX,
                startY,
                endX,
                endY
            ) <= brushRadiusSquared
            then
                stain.coverageCleaned[index] = true
                stain.remainingCoverageCount -= 1
                newlyCleanedCount += 1
            end
        end
    end

    return newlyCleanedCount
end

local function updateCleaningRewards(stain, scoreX, scoreY)
    local cleanedProgress = 1
        - stain.remainingCoverageCount
            / math.max(1, #stain.coveragePoints)
    local reachedScoreSteps = math.floor(
        cleanedProgress * tuning.OTHER_SIDE_OIL_SCORE_STEPS
    )

    if reachedScoreSteps > stain.awardedScoreSteps then
        local gainedSteps = reachedScoreSteps - stain.awardedScoreSteps
        stain.awardedScoreSteps = reachedScoreSteps
        queueCleanScore(
            scoreX,
            scoreY,
            gainedSteps * tuning.OTHER_SIDE_OIL_SCORE
        )
    end

    if stain.remainingCoverageCount == 0 then
        return true
    end

    return false
end

local function makeCoveragePoints(image)
    local imageWidth, imageHeight = image:getSize()
    local sampleStep = tuning.OTHER_SIDE_OIL_COVERAGE_SAMPLE_STEP
    local points = {}

    for tileY = 0, imageHeight - 1, sampleStep do
        for tileX = 0, imageWidth - 1, sampleStep do
            local visiblePixelCount = 0
            local visiblePixelXSum = 0
            local visiblePixelYSum = 0

            for y = tileY,
                math.min(tileY + sampleStep - 1, imageHeight - 1)
            do
                for x = tileX,
                    math.min(tileX + sampleStep - 1, imageWidth - 1)
                do
                    if image:sample(x, y) ~= pdg.kColorClear then
                        visiblePixelCount += 1
                        visiblePixelXSum += x
                        visiblePixelYSum += y
                    end
                end
            end

            if visiblePixelCount > 0 then
                points[#points + 1] = {
                    x = visiblePixelXSum / visiblePixelCount,
                    y = visiblePixelYSum / visiblePixelCount
                }
            end
        end
    end

    return points
end

function OilStains.initialize(
    gameplayTuning,
    sfxChannel,
    objectGroups,
    onCleaned
)
    tuning = gameplayTuning
    interactableObjectGroups = objectGroups
    cleanedCallback = onCleaned

    for index = 1, tuning.OTHER_SIDE_OIL_CLEAN_SOUND_POOL_SIZE do
        local soundPlayer = pds.sampleplayer.new("sounds/OilClean")
        soundPlayer:setVolume(tuning.OTHER_SIDE_OIL_CLEAN_SOUND_VOLUME)
        sfxChannel:addSource(soundPlayer)
        cleanSoundPlayers[index] = soundPlayer
    end

    oilStainVariants = {}

    for index = 1, #oilStainAssetImages do
        local sourceImage = makeTrimmedOilStainImage(
            oilStainAssetImages[index]
        )
        local imageWidth, imageHeight = sourceImage:getSize()
        local variantSourceMask = sourceImage:getMaskImage()

        if variantSourceMask == nil then
            sourceImage:addMask(true)
            variantSourceMask = sourceImage:getMaskImage()
        end

        oilStainVariants[index] = {
            sourceImage = sourceImage,
            sourceMask = variantSourceMask,
            coveragePoints = makeCoveragePoints(sourceImage),
            imageWidth = imageWidth,
            imageHeight = imageHeight
        }
    end

    local initialVariant = oilStainVariants[1]

    for stainIndex = 1, tuning.OTHER_SIDE_OIL_STAIN_POOL_SIZE do
        local variantImages = {}

        for variantIndex = 1, #oilStainVariants do
            variantImages[variantIndex] =
                oilStainVariants[variantIndex].sourceImage:copy()
        end

        local image = variantImages[1]
        local stain = pdg.sprite.new(image)
        stain.objectType = "otherSideOil"
        stain.collisionResponse = pdg.sprite.kCollisionTypeOverlap
        stain.active = false
        stain.oilAdded = false
        stain.isAppearing = false
        stain.appearElapsedMilliseconds = 0
        stain.cleanedOnPreviousFrame = false
        stain.lastCleanLocalX = nil
        stain.lastCleanLocalY = nil
        stain.image = image
        stain.mask = image:getMaskImage()
        stain.variantImages = variantImages
        stain.coveragePoints = initialVariant.coveragePoints
        stain.imageWidth = initialVariant.imageWidth
        stain.imageHeight = initialVariant.imageHeight
        stain.coverageCleaned = {}
        stain.remainingCoverageCount = #stain.coveragePoints
        stain.awardedScoreSteps = 0
        local cleaningReach = tuning.OTHER_SIDE_OIL_CLEAN_BRUSH_RADIUS
        stain:setCollideRect(
            -cleaningReach,
            -cleaningReach,
            stain.imageWidth + cleaningReach * 2,
            stain.imageHeight + cleaningReach * 2
        )
        stain:setZIndex(tuning.OTHER_SIDE_OIL_Z_INDEX)
        stain:setVisible(false)
        stains[stainIndex] = stain
    end

    interactableObjectGroups[#interactableObjectGroups + 1] = stains
end

function OilStains.beginRun()
    running = true
    resetSpawnCountdown()
end

function OilStains.spawn(x, y)
    return spawnAtAvailableStain(x, y, true)
end

function OilStains.startCleaning(stain, playerSprite)
    if stain == nil
        or playerSprite == nil
        or stain.active == false
        or stain.isAppearing
    then
        return false
    end

    local localX = playerSprite.x - (stain.x - stain.imageWidth / 2)
    local localY = playerSprite.y - (stain.y - stain.imageHeight / 2)
    local startX = stain.lastCleanLocalX or localX
    local startY = stain.lastCleanLocalY or localY

    local newlyCleanedCount = updateCleanedCoverage(
        stain,
        startX,
        startY,
        localX,
        localY
    )

    if newlyCleanedCount <= 0 then
        stain.cleanedOnPreviousFrame = false
        return false
    end

    eraseMaskPath(stain, startX, startY, localX, localY)
    stain.lastCleanLocalX = localX
    stain.lastCleanLocalY = localY
    stain.cleanedOnPreviousFrame = true
    playCleanSound()

    if updateCleaningRewards(stain, playerSprite.x, playerSprite.y) then
        deactivate(stain)
    end

    return true
end

function OilStains.update(elapsedMilliseconds, worldDisplacement)
    for index = 1, #stains do
        local stain = stains[index]

        if stain.active then
            stain:moveBy(worldDisplacement, 0)

            if stain.cleanedOnPreviousFrame == false then
                stain.lastCleanLocalX = nil
                stain.lastCleanLocalY = nil
            end

            stain.cleanedOnPreviousFrame = false

            if stain.isAppearing then
                stain.appearElapsedMilliseconds += elapsedMilliseconds
                local progress = math.min(
                    stain.appearElapsedMilliseconds
                        / tuning.OTHER_SIDE_OIL_APPEAR_DURATION_MS,
                    1
                )
                stain:setScale(smoothstep(progress))

                if progress >= 1 then
                    stain.isAppearing = false
                end
            end

            if stain.active and stain.x - stain.imageWidth / 2 > 400 then
                deactivate(stain)
            end
        end
    end

    updatePendingScore(elapsedMilliseconds)
    updateCleanSound()

    if running == false or hasActiveStain() then
        return
    end

    spawnRemainingMilliseconds -= elapsedMilliseconds

    if spawnRemainingMilliseconds <= 0 then
        resetSpawnCountdown()

        if math.random(100) <= tuning.OTHER_SIDE_OIL_SPAWN_CHANCE_PERCENT then
            spawnWorldStain()
        end
    end
end

function OilStains.rewind(displacement)
    for index = 1, #stains do
        local stain = stains[index]

        if stain.active then
            stain:moveBy(displacement, 0)

            if stain.x + stain.imageWidth / 2 < 0 then
                deactivate(stain)
            end
        end
    end
end

function OilStains.stopSounds()
    cleanSoundQueued = false
    currentCleanSoundPlayer = nil

    for index = 1, #cleanSoundPlayers do
        if cleanSoundPlayers[index]:isPlaying() then
            cleanSoundPlayers[index]:stop()
        end
    end
end

function OilStains.reset()
    running = false
    spawnRemainingMilliseconds = 0
    cleanSoundPlayerCursor = 1
    pendingScoreValue = 0
    pendingScoreDelayMilliseconds = 0
    pendingScoreX = 0
    pendingScoreY = 0
    OilStains.stopSounds()

    for index = 1, #stains do
        deactivate(stains[index])
    end
end
