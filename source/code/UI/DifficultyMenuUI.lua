local pdg <const> = playdate.graphics

local difficultyMenuImage = pdg.image.new("images/DifficultyMenu")
local lockImage = pdg.image.new("images/LockIcon")
local starImage = pdg.image.new("images/Star")
local modeTitleFont = pdg.getFont(pdg.font.kVariantBold)
local lockImageWidth = lockImage:getSize()
local highScoreNumber = FixedWidthNumber.new(7)
local descriptionLineSpacing = 30
local lockedDescriptionLineSpacing = 18
local lockedIconYOffset = 82
local lockedLabelYOffset = 118
local lockedDescriptionYOffset = 140

DifficultyMenuUI = {}

local function drawHighScore(centerX, y, score)
    FixedWidthNumber.update(highScoreNumber, score)
    local starWidth, starHeight = starImage:getSize()
    local groupWidth = starWidth + 4 + highScoreNumber.width
    local startX = math.floor(centerX - groupWidth / 2)

    starImage:draw(startX, y)
    FixedWidthNumber.draw(
        highScoreNumber,
        startX + starWidth + 4,
        y + math.floor((starHeight - 14) / 2)
    )
end

function DifficultyMenuUI.draw(mode, modeIndex, modeCount, highScore, isUnlocked, tuning, xOffset)
    local x = tuning.DIFFICULTY_MENU_PANEL_X + (xOffset or 0)
    local y = tuning.DIFFICULTY_MENU_PANEL_Y
    local width = tuning.DIFFICULTY_MENU_PANEL_WIDTH
    local height = tuning.DIFFICULTY_MENU_PANEL_HEIGHT
    local centerX = x + math.floor(width / 2)
    local previousColor = pdg.getColor()

    difficultyMenuImage:draw(x, y)
    pdg.setColor(pdg.kColorBlack)
    drawHighScore(centerX, y + 14, highScore)

    local title = isUnlocked and mode.TITLE or mode.LOCKED_TITLE or mode.TITLE
    local previousFont = pdg.getFont()
    pdg.setFont(modeTitleFont)
    pdg.drawTextAligned(title, centerX, y + 58, kTextAlignment.center)
    pdg.setFont(previousFont)

    if isUnlocked then
        for lineIndex = 1, #mode.DESCRIPTION_LINES do
            pdg.drawTextAligned(
                mode.DESCRIPTION_LINES[lineIndex],
                centerX,
                y + 88 + (lineIndex - 1) * descriptionLineSpacing,
                kTextAlignment.center
            )
        end
    elseif mode.LOCKED_DESCRIPTION_LINES ~= nil then
        lockImage:draw(math.floor(centerX - lockImageWidth / 2), y + lockedIconYOffset)
        pdg.drawTextAligned("LOCKED", centerX, y + lockedLabelYOffset, kTextAlignment.center)

        for lineIndex = 1, #mode.LOCKED_DESCRIPTION_LINES do
            pdg.drawTextAligned(
                mode.LOCKED_DESCRIPTION_LINES[lineIndex],
                centerX,
                y + lockedDescriptionYOffset + (lineIndex - 1) * lockedDescriptionLineSpacing,
                kTextAlignment.center
            )
        end
    else
        lockImage:draw(math.floor(centerX - lockImageWidth / 2), y + lockedIconYOffset)
        pdg.drawTextAligned("LOCKED", centerX, y + lockedLabelYOffset, kTextAlignment.center)
        pdg.drawTextAligned(
            "Reach " .. tostring(mode.UNLOCK_SCORE),
            centerX,
            y + lockedDescriptionYOffset,
            kTextAlignment.center
        )
        pdg.drawTextAligned(
            "in " .. mode.UNLOCK_MODE_TITLE .. " mode",
            centerX,
            y + lockedDescriptionYOffset + lockedDescriptionLineSpacing,
            kTextAlignment.center
        )
    end

    pdg.drawTextAligned(
        tostring(modeIndex) .. " / " .. tostring(modeCount),
        centerX,
        y + height - 34,
        kTextAlignment.center
    )

    pdg.setColor(previousColor)
end
