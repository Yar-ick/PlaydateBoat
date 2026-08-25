local pdg <const> = playdate.graphics

local abilityFrameImage = pdg.image.new("images/AbilityFrame")
local dashImage = pdg.image.new("images/Dash")
local hornImage = pdg.image.new("images/Horn")
local shrinkImage = pdg.image.new("images/Srink")
local growthImage = pdg.image.new("images/Growth")
local shieldStackImages = {
    pdg.image.new("images/ShieldNoStack"),
    pdg.image.new("images/Shield1Stack"),
    pdg.image.new("images/Shield2Stack")
}

local function makeFadedImage(image)
    local width, height = image:getSize()
    local fadedImage = pdg.image.new(width, height, pdg.kColorClear)

    pdg.pushContext(fadedImage)
    image:drawFaded(0, 0, 0.25, pdg.image.kDitherTypeBayer8x8)
    pdg.popContext()
    return fadedImage
end

local fadedAbilityImages = {
    [dashImage] = makeFadedImage(dashImage),
    [hornImage] = makeFadedImage(hornImage),
    [shrinkImage] = makeFadedImage(shrinkImage),
    [growthImage] = makeFadedImage(growthImage)
}

AbilityTopUI = {}

local function drawFramedProgress(image, frameX, frameY, progress, canShowFull, imageYOffset)
    local frameWidth, frameHeight = abilityFrameImage:getSize()
    local imageWidth, imageHeight = image:getSize()
    local imageX = frameX + math.floor((frameWidth - imageWidth) / 2)
    local imageY = frameY + math.floor((frameHeight - imageHeight) / 2)
        + (imageYOffset or 0)
    local filledHeight = math.floor(imageHeight * math.clamp(progress, 0, 1) + 0.5)

    if canShowFull == false then
        filledHeight = math.min(filledHeight, imageHeight - 1)
    end

    abilityFrameImage:draw(frameX, frameY)
    fadedAbilityImages[image]:draw(imageX, imageY)

    if filledHeight > 0 then
        pdg.setClipRect(imageX, imageY + imageHeight - filledHeight, imageWidth, filledHeight)
        image:draw(imageX, imageY)
        pdg.clearClipRect()
    end
end

local function drawShieldStorage(shieldHits, firstShieldX, tuning, xOffset)
    if shieldHits <= 0 then
        return
    end

    firstShieldX += xOffset
    local remainingShieldHits = math.min(shieldHits, tuning.MAX_SHIELD_HITS)
    local stackCount = math.ceil(remainingShieldHits / 3)
    local previousDrawMode = pdg.getImageDrawMode()

    pdg.setImageDrawMode(pdg.kDrawModeCopy)

    for stackIndex = 1, stackCount do
        local hitsInStack = math.min(3, remainingShieldHits)
        local stackImage = shieldStackImages[hitsInStack]
        local imageWidth, imageHeight = stackImage:getSize()
        local centerX = firstShieldX
            + (stackIndex - 1) * tuning.TOP_UI_SHIELD_STACK_SPACING
        local centerY = tuning.TOP_UI_SHIELD_CENTER_Y

        stackImage:draw(
            math.floor(centerX - imageWidth / 2 + 0.5),
            math.floor(centerY - imageHeight / 2 + 0.5)
        )
        remainingShieldHits -= hitsInStack
    end

    pdg.setImageDrawMode(previousDrawMode)
end

function AbilityTopUI.draw(
    dashProgress,
    dashIsReady,
    shrinkProgress,
    shieldHits,
    dashIsPurchased,
    shrinkIsPurchased,
    tuning,
    xOffset,
    isOtherSide
)
    xOffset = xOffset or 0
    local primaryImage = isOtherSide and hornImage or dashImage
    local scaleImage = isOtherSide and growthImage or shrinkImage
    local abilitySpacing = tuning.TOP_UI_SHRINK_FRAME_X - tuning.TOP_UI_DASH_FRAME_X
    local nextAbilityFrameX = tuning.TOP_UI_DASH_FRAME_X
    local firstShieldX = tuning.TOP_UI_SHIELD_FIRST_X - abilitySpacing * 2

    if dashIsPurchased then
        drawFramedProgress(
            primaryImage,
            nextAbilityFrameX + xOffset,
            tuning.TOP_UI_ABILITY_FRAME_Y,
            dashProgress,
            dashIsReady
        )
        nextAbilityFrameX += abilitySpacing
        firstShieldX += abilitySpacing
    end

    if shrinkIsPurchased then
        drawFramedProgress(
            scaleImage,
            nextAbilityFrameX + xOffset,
            tuning.TOP_UI_ABILITY_FRAME_Y,
            shrinkProgress,
            true,
            isOtherSide and 1 or 0
        )
        firstShieldX += abilitySpacing
    end

    drawShieldStorage(shieldHits, firstShieldX, tuning, xOffset)
end
