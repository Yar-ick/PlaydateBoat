local pdg <const> = playdate.graphics

local buttonImages = {
    a = pdg.image.new("images/A_Button"),
    b = pdg.image.new("images/B_Button")
}

WaitingControlsUI = {}

local function drawPanel(x, y, width, height, shadowOffset)
    pdg.setColor(pdg.kColorBlack)
    pdg.fillRect(x + shadowOffset, y + shadowOffset, width, height)
    pdg.setColor(pdg.kColorWhite)
    pdg.fillRect(x, y, width, height)
    pdg.setColor(pdg.kColorBlack)
    pdg.drawRect(x, y, width, height)
    pdg.drawRect(x + 2, y + 2, width - 4, height - 4)

    pdg.fillRect(x, y, 5, 2)
    pdg.fillRect(x, y, 2, 5)
    pdg.fillRect(x + width - 5, y, 5, 2)
    pdg.fillRect(x + width - 2, y, 2, 5)
    pdg.fillRect(x, y + height - 2, 5, 2)
    pdg.fillRect(x, y + height - 5, 2, 5)
    pdg.fillRect(x + width - 5, y + height - 2, 5, 2)
    pdg.fillRect(x + width - 2, y + height - 5, 2, 5)
end

local function getControlRowWidth(beforeText, buttonImage, afterText, tuning)
    local beforeWidth = pdg.getTextSize(beforeText)
    local afterWidth = pdg.getTextSize(afterText)
    local buttonWidth = buttonImage:getSize()
    return beforeWidth + buttonWidth + afterWidth
        + tuning.WAITING_CONTROLS_BUTTON_GAP * 2
end

local function drawControlRow(
    beforeText,
    buttonImage,
    afterText,
    rightX,
    y,
    tuning,
    buttonYOffset
)
    local beforeWidth, beforeHeight = pdg.getTextSize(beforeText)
    local afterWidth, afterHeight = pdg.getTextSize(afterText)
    local buttonWidth, buttonHeight = buttonImage:getSize()
    local gap = tuning.WAITING_CONTROLS_BUTTON_GAP
    local totalWidth = beforeWidth + buttonWidth + afterWidth + gap * 2
    local x = rightX - totalWidth
    local textY = y + math.floor(
        (tuning.WAITING_CONTROLS_ROW_HEIGHT - math.max(beforeHeight, afterHeight)) / 2
    )
    local buttonY = y + math.floor(
        (tuning.WAITING_CONTROLS_ROW_HEIGHT - buttonHeight) / 2
    ) + (buttonYOffset or tuning.WAITING_CONTROLS_BUTTON_Y_OFFSET)

    pdg.drawText(beforeText, x, textY)
    x += beforeWidth + gap
    buttonImage:draw(x, buttonY)
    x += buttonWidth + gap
    pdg.drawText(afterText, x, textY)
end

function WaitingControlsUI.draw(
    isOtherSide,
    primaryAbilityPurchased,
    impulsePurchased,
    tuning,
    slideProgress
)
    local rowCount = 1
        + (primaryAbilityPurchased and 1 or 0)
        + (isOtherSide and impulsePurchased and 1 or 0)
    local maximumRowWidth = getControlRowWidth(
        "Hold",
        buttonImages.b,
        "to speed up",
        tuning
    )

    if primaryAbilityPurchased then
        maximumRowWidth = math.max(
            maximumRowWidth,
            getControlRowWidth(
                "Tap",
                buttonImages.b,
                isOtherSide and "to horn" or "to dash",
                tuning
            )
        )
    end

    if isOtherSide and impulsePurchased then
        maximumRowWidth = math.max(
            maximumRowWidth,
            getControlRowWidth("Tap", buttonImages.a, "to use impulse", tuning)
        )
    end

    local frameWidth = maximumRowWidth
        + tuning.WAITING_CONTROLS_FRAME_HORIZONTAL_PADDING * 2
    local frameHeight = rowCount * tuning.WAITING_CONTROLS_ROW_HEIGHT
        + (rowCount - 1) * tuning.WAITING_CONTROLS_ROW_SEPARATOR_HEIGHT
        + tuning.WAITING_CONTROLS_FRAME_VERTICAL_PADDING * 2
    slideProgress = math.max(0, math.min(1, slideProgress or 1))
    local easedSlideProgress = slideProgress * slideProgress * (3 - 2 * slideProgress)
    local slideOffsetX = math.floor(
        tuning.WAITING_CONTROLS_HIDDEN_OFFSET_X * (1 - easedSlideProgress) + 0.5
    )
    local frameX = tuning.WAITING_CONTROLS_RIGHT_X - frameWidth + slideOffsetX
    local frameY = tuning.WAITING_CONTROLS_BOTTOM_Y - frameHeight
    local contentRightX = tuning.WAITING_CONTROLS_RIGHT_X
        - tuning.WAITING_CONTROLS_FRAME_HORIZONTAL_PADDING
        + slideOffsetX
    local currentY = frameY + tuning.WAITING_CONTROLS_FRAME_VERTICAL_PADDING
    local previousColor = pdg.getColor()
    local previousDrawMode = pdg.getImageDrawMode()

    drawPanel(
        frameX,
        frameY,
        frameWidth,
        frameHeight,
        tuning.WAITING_CONTROLS_FRAME_SHADOW_OFFSET
    )

    for separatorIndex = 1, rowCount - 1 do
        local separatorY = frameY
            + tuning.WAITING_CONTROLS_FRAME_VERTICAL_PADDING
            + separatorIndex * tuning.WAITING_CONTROLS_ROW_HEIGHT
            + (separatorIndex - 1) * tuning.WAITING_CONTROLS_ROW_SEPARATOR_HEIGHT
            + math.floor(tuning.WAITING_CONTROLS_ROW_SEPARATOR_HEIGHT / 2)
        pdg.drawLine(
            frameX + tuning.WAITING_CONTROLS_FRAME_SEPARATOR_INSET,
            separatorY,
            frameX + frameWidth - tuning.WAITING_CONTROLS_FRAME_SEPARATOR_INSET,
            separatorY
        )
    end

    pdg.setImageDrawMode(pdg.kDrawModeCopy)

    drawControlRow(
        "Hold",
        buttonImages.b,
        "to speed up",
        contentRightX,
        currentY,
        tuning,
        tuning.WAITING_CONTROLS_HOLD_BUTTON_Y_OFFSET
    )
    currentY += tuning.WAITING_CONTROLS_ROW_HEIGHT
        + tuning.WAITING_CONTROLS_ROW_SEPARATOR_HEIGHT

    if primaryAbilityPurchased then
        drawControlRow(
            "Tap",
            buttonImages.b,
            isOtherSide and "to horn" or "to dash",
            contentRightX,
            currentY,
            tuning
        )
        currentY += tuning.WAITING_CONTROLS_ROW_HEIGHT
            + tuning.WAITING_CONTROLS_ROW_SEPARATOR_HEIGHT
    end

    if isOtherSide and impulsePurchased then
        drawControlRow(
            "Tap",
            buttonImages.a,
            "to use impulse",
            contentRightX,
            currentY,
            tuning
        )
    end

    pdg.setImageDrawMode(previousDrawMode)
    pdg.setColor(previousColor)
end
