local pdg <const> = playdate.graphics

local starImage = pdg.image.new("images/Star")
local digitCellWidth = 0

for digit = 0, 9 do
    local digitWidth = pdg.getTextSize(tostring(digit))
    digitCellWidth = math.max(digitCellWidth, digitWidth)
end

DifficultyMenuUI = {}

local function drawPanel(x, y, width, height)
    pdg.setColor(pdg.kColorBlack)
    pdg.fillRect(x + 3, y + 3, width, height)
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

local function drawArrowButton(centerX, centerY, pointsRight)
    pdg.setColor(pdg.kColorWhite)
    pdg.fillCircleAtPoint(centerX, centerY, 13)
    pdg.setColor(pdg.kColorBlack)
    pdg.drawCircleAtPoint(centerX, centerY, 13)
    pdg.drawCircleAtPoint(centerX, centerY, 10)

    local direction = pointsRight and 1 or -1
    pdg.drawLine(centerX - direction * 3, centerY - 5, centerX + direction * 3, centerY)
    pdg.drawLine(centerX + direction * 3, centerY, centerX - direction * 3, centerY + 5)
end

local function drawLock(centerX, topY)
    pdg.setColor(pdg.kColorBlack)
    pdg.drawArc(centerX, topY + 6, 6, 180, 360)
    pdg.fillRect(centerX - 8, topY + 6, 16, 13)
    pdg.setColor(pdg.kColorWhite)
    pdg.fillCircleAtPoint(centerX, topY + 12, 2)
    pdg.fillRect(centerX - 1, topY + 12, 2, 4)
end

local function drawHighScore(centerX, y, score)
    local scoreText = string.format("%07d", score)
    local scoreWidth = string.len(scoreText) * (digitCellWidth + 1)
    local starWidth, starHeight = starImage:getSize()
    local groupWidth = starWidth + 4 + scoreWidth
    local startX = math.floor(centerX - groupWidth / 2)
    local digitCenterX = startX + starWidth + 4 + math.floor(digitCellWidth / 2)

    starImage:draw(startX, y)

    for digitIndex = 1, string.len(scoreText) do
        pdg.drawTextAligned(
            string.sub(scoreText, digitIndex, digitIndex),
            digitCenterX,
            y + math.floor((starHeight - 14) / 2),
            kTextAlignment.center
        )
        digitCenterX += digitCellWidth + 1
    end
end

function DifficultyMenuUI.draw(mode, modeIndex, modeCount, highScore, isUnlocked, tuning, xOffset)
    local x = tuning.DIFFICULTY_MENU_PANEL_X + (xOffset or 0)
    local y = tuning.DIFFICULTY_MENU_PANEL_Y
    local width = tuning.DIFFICULTY_MENU_PANEL_WIDTH
    local height = tuning.DIFFICULTY_MENU_PANEL_HEIGHT
    local centerX = x + math.floor(width / 2)
    local previousColor = pdg.getColor()

    drawPanel(x, y, width, height)
    drawHighScore(centerX, y + 14, highScore)

    pdg.drawLine(x + 8, y + 48, x + width - 8, y + 48)
    pdg.drawTextAligned(mode.TITLE, centerX, y + 58, kTextAlignment.center)

    if isUnlocked then
        for lineIndex = 1, #mode.DESCRIPTION_LINES do
            pdg.drawTextAligned(
                mode.DESCRIPTION_LINES[lineIndex],
                centerX,
                y + 88 + (lineIndex - 1) * 18,
                kTextAlignment.center
            )
        end
    else
        drawLock(centerX, y + 84)
        pdg.drawTextAligned("LOCKED", centerX, y + 108, kTextAlignment.center)
        pdg.drawTextAligned(
            "Reach " .. tostring(mode.UNLOCK_SCORE),
            centerX,
            y + 132,
            kTextAlignment.center
        )
        pdg.drawTextAligned(
            "in " .. mode.UNLOCK_MODE_TITLE .. " mode",
            centerX,
            y + 150,
            kTextAlignment.center
        )
    end

    pdg.drawLine(x + 8, y + height - 48, x + width - 8, y + height - 48)
    drawArrowButton(x + 24, y + height - 24, false)
    drawArrowButton(x + width - 24, y + height - 24, true)
    pdg.drawTextAligned(
        tostring(modeIndex) .. " / " .. tostring(modeCount),
        centerX,
        y + height - 31,
        kTextAlignment.center
    )

    pdg.setColor(previousColor)
end
