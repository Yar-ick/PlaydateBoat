local pdg <const> = playdate.graphics

local abilityFrameImage = pdg.image.new("images/AbilityFrame")
local dashImage = pdg.image.new("images/Dash")
local shrinkImage = pdg.image.new("images/Srink")
local shieldImage = pdg.image.new("images/ShieldNoFrame")

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

local function getShieldRingCount(extraRingCharges, iconIndex)
    local ringCount = math.floor(extraRingCharges / 3)
    local partialRingCount = extraRingCharges % 3

    if partialRingCount >= 1 and iconIndex == 2 then
        ringCount += 1
    elseif partialRingCount >= 2 and iconIndex == 1 then
        ringCount += 1
    end

    return ringCount
end

local function drawShieldStorage(shieldHits, shrinkIsPurchased, tuning, xOffset)
    local iconCount = math.min(shieldHits, 3)

    if iconCount <= 0 then
        return
    end

    local extraRingCharges = math.max(0, math.min(shieldHits, 9) - 3)
    local iconSpacing = tuning.DIEGETIC_SHIELD_ICON_SPACING
    local missingShrinkOffset = 0

    if shrinkIsPurchased == false then
        missingShrinkOffset = tuning.TOP_UI_SHRINK_FRAME_X - tuning.TOP_UI_DASH_FRAME_X
    end

    local firstShieldX = tuning.TOP_UI_SHIELD_FIRST_X - missingShrinkOffset + xOffset
    local shieldWidth, shieldHeight = shieldImage:getSize()
    local previousDrawMode = pdg.getImageDrawMode()
    local previousLineWidth = pdg.getLineWidth()
    local previousColor = pdg.getColor()

    if shieldHits >= 7 then
        iconSpacing = tuning.TOP_UI_SHIELD_DOUBLE_RING_SPACING
    end

    if shieldHits >= tuning.MAX_SHIELD_HITS then
        firstShieldX = tuning.TOP_UI_SHIELD_FULL_FIRST_X - missingShrinkOffset + xOffset
    end

    pdg.setImageDrawMode(pdg.kDrawModeCopy)

    for iconIndex = 1, iconCount do
        local centerX

        if shieldHits >= tuning.MAX_SHIELD_HITS and iconIndex > 1 then
            centerX = firstShieldX
                + tuning.TOP_UI_SHIELD_FULL_FIRST_GAP
                + (iconIndex - 2) * iconSpacing
        else
            centerX = firstShieldX + (iconIndex - 1) * iconSpacing
        end

        local centerY = tuning.TOP_UI_SHIELD_CENTER_Y
        local iconScale = tuning.TOP_UI_SHIELD_ICON_SCALE

        -- The first shield is the full-storage marker in the top HUD.
        if shieldHits >= tuning.MAX_SHIELD_HITS and iconIndex == 1 then
            iconScale = tuning.TOP_UI_SHIELD_FULL_FIRST_ICON_SCALE
        end

        local ringCount = getShieldRingCount(extraRingCharges, iconIndex)

        if ringCount > 0 then
            local outerRingRadius = shieldWidth * iconScale / 2
                + tuning.DIEGETIC_SHIELD_RING_GAP
                + (ringCount - 1) * tuning.DIEGETIC_SHIELD_RING_SPACING

            pdg.setColor(pdg.kColorWhite)
            pdg.fillCircleAtPoint(centerX, centerY, outerRingRadius)
        end

        for ringIndex = 1, ringCount do
            local ringRadius = shieldWidth * iconScale / 2
                + tuning.DIEGETIC_SHIELD_RING_GAP
                + (ringIndex - 1) * tuning.DIEGETIC_SHIELD_RING_SPACING

            pdg.setColor(pdg.kColorWhite)
            pdg.setLineWidth(3)
            pdg.drawCircleAtPoint(centerX, centerY, ringRadius)
            pdg.setColor(pdg.kColorBlack)
            pdg.setLineWidth(1)
            pdg.drawCircleAtPoint(centerX, centerY, ringRadius)
        end

        shieldImage:drawScaled(
            math.floor(centerX - shieldWidth * iconScale / 2 + 0.5),
            math.floor(centerY - shieldHeight * iconScale / 2 + 0.5)
                + tuning.DIEGETIC_SHIELD_IMAGE_Y_OFFSET,
            iconScale
        )
    end

    pdg.setImageDrawMode(previousDrawMode)
    pdg.setLineWidth(previousLineWidth)
    pdg.setColor(previousColor)
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
