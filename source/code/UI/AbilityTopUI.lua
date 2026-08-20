local pdg <const> = playdate.graphics

local abilityFrameImage = pdg.image.new("images/AbilityFrame")
local dashImage = pdg.image.new("images/Dash")
local shrinkImage = pdg.image.new("images/Srink")
local shieldStackImages = {
    pdg.image.new("images/ShieldNoStack"),
    pdg.image.new("images/Shield1Stack"),
    pdg.image.new("images/Shield2Stack")
}

AbilityTopUI = {}

local function drawFramedProgress(image, frameX, frameY, progress, canShowFull)
    local frameWidth, frameHeight = abilityFrameImage:getSize()
    local imageWidth, imageHeight = image:getSize()
    local imageX = frameX + math.floor((frameWidth - imageWidth) / 2)
    local imageY = frameY + math.floor((frameHeight - imageHeight) / 2)
    local filledHeight = math.floor(imageHeight * math.clamp(progress, 0, 1) + 0.5)

    if canShowFull == false then
        filledHeight = math.min(filledHeight, imageHeight - 1)
    end

    abilityFrameImage:draw(frameX, frameY)
    image:drawFaded(imageX, imageY, 0.25, pdg.image.kDitherTypeBayer8x8)

    if filledHeight > 0 then
        pdg.setClipRect(imageX, imageY + imageHeight - filledHeight, imageWidth, filledHeight)
        image:draw(imageX, imageY)
        pdg.clearClipRect()
    end
end

local function drawShieldStorage(shieldHits, shrinkIsPurchased, tuning, xOffset)
    if shieldHits <= 0 then
        return
    end

    local missingShrinkOffset = 0

    if shrinkIsPurchased == false then
        missingShrinkOffset = tuning.TOP_UI_SHRINK_FRAME_X - tuning.TOP_UI_DASH_FRAME_X
    end

    local firstShieldX = tuning.TOP_UI_SHIELD_FIRST_X - missingShrinkOffset + xOffset
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
    xOffset
)
    xOffset = xOffset or 0

    if dashIsPurchased then
        drawFramedProgress(
            dashImage,
            tuning.TOP_UI_DASH_FRAME_X + xOffset,
            tuning.TOP_UI_ABILITY_FRAME_Y,
            dashProgress,
            dashIsReady
        )
    end

    if shrinkIsPurchased then
        drawFramedProgress(
            shrinkImage,
            tuning.TOP_UI_SHRINK_FRAME_X + xOffset,
            tuning.TOP_UI_ABILITY_FRAME_Y,
            shrinkProgress,
            true
        )
    end

    drawShieldStorage(shieldHits, shrinkIsPurchased, tuning, xOffset)
end
