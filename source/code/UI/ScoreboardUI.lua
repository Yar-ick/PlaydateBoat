local pdg <const> = playdate.graphics

local backgroundImage = pdg.image.new("images/ScoreboardMenu")
local boldFont = pdg.getFont(pdg.font.kVariantBold)

local mockNames <const> = {
    "Varick", "Marina", "Harbor", "Skipper", "Nautica", "Rudder",
    "Current", "Anchor", "Trawler", "Jetty", "Beacon", "Mariner",
    "Ferry", "Breeze", "Cutter", "Buoy", "Wake", "Channel",
    "Dory", "Sailor", "Tide", "Dockhand", "Voyager", "Captain"
}

local mockTopScores <const> = {
    casual = 1800000,
    normal = 2400000,
    hardcore = 3200000,
    otherSide = 2800000
}

local state = {
    modeIndex = 1,
    entries = {},
    playerRank = 1,
    windowStart = 1
}

ScoreboardUI = {}

local function getMockName(index, modeIndex)
    local nameIndex = (index * 7 + modeIndex * 5 - 1) % #mockNames + 1
    local suffix = math.floor((index - 1) / #mockNames)

    if suffix == 0 then
        return mockNames[nameIndex]
    end

    return mockNames[nameIndex] .. tostring(suffix + 1)
end

local function buildMockEntries(mode, modeIndex, playerScore)
    local entries = {}
    local topScore = mockTopScores[mode.ID] or 2000000
    local scoreStep = math.floor(topScore / 112)

    for index = 1, 99 do
        local jitter = (index * 7919 + modeIndex * 3571) % math.max(1, scoreStep)
        entries[index] = {
            name = getMockName(index, modeIndex),
            score = math.max(1, topScore - index * scoreStep - jitter),
            isPlayer = false
        }
    end

    entries[100] = {
        name = "YOU",
        score = math.max(0, math.floor(tonumber(playerScore) or 0)),
        isPlayer = true
    }

    table.sort(entries, function(left, right)
        if left.score == right.score then
            return left.isPlayer == true
        end

        return left.score > right.score
    end)

    local playerRank = 1
    for rank = 1, #entries do
        entries[rank].rank = rank
        if entries[rank].isPlayer then
            playerRank = rank
        end
    end

    return entries, playerRank
end

local function rebuildEntries()
    local mode = Difficulty.getMode(state.modeIndex)
    state.entries, state.playerRank = buildMockEntries(
        mode,
        state.modeIndex,
        Difficulty.getHighScore(mode.ID)
    )
    state.windowStart = 1
end

function ScoreboardUI.open(modeIndex)
    state.modeIndex = math.clamp(
        math.floor(tonumber(modeIndex) or 1),
        1,
        Difficulty.getModeCount()
    )
    rebuildEntries()
end

function ScoreboardUI.getModeIndex()
    return state.modeIndex
end

function ScoreboardUI.changeMode(direction)
    local modeCount = Difficulty.getModeCount()
    local targetIndex = state.modeIndex

    for _ = 1, modeCount - 1 do
        targetIndex = (targetIndex - 1 + direction) % modeCount + 1

        if Difficulty.isModeUnlockedAtIndex(targetIndex) then
            state.modeIndex = targetIndex
            rebuildEntries()
            return true
        end
    end

    return false
end

function ScoreboardUI.scroll(direction, tuning)
    local maximumStart = math.max(1, #state.entries - tuning.SCOREBOARD_VISIBLE_ROW_COUNT + 1)
    local previousStart = state.windowStart
    state.windowStart = math.clamp(
        state.windowStart + direction * tuning.SCOREBOARD_SCROLL_STEP,
        1,
        maximumStart
    )
    return previousStart ~= state.windowStart
end

local function drawEntry(entry, x, y, width, isHighlighted)
    local previousDrawMode = pdg.getImageDrawMode()
    local previousColor = pdg.getColor()

    if isHighlighted then
        pdg.setColor(pdg.kColorBlack)
        pdg.fillRect(x, y - 1, width, 17)
        pdg.setImageDrawMode(pdg.kDrawModeFillWhite)
    else
        pdg.setImageDrawMode(pdg.kDrawModeCopy)
    end

    pdg.drawTextAligned(
        tostring(entry.rank) .. ".",
        x + 25,
        y,
        kTextAlignment.right
    )
    pdg.drawText(entry.name, x + 31, y)
    pdg.drawTextAligned(
        tostring(entry.score),
        x + width - 4,
        y,
        kTextAlignment.right
    )

    pdg.setImageDrawMode(previousDrawMode)
    pdg.setColor(previousColor)
end

local function getVisibleEntry(slotIndex, playerIsInWindow, tuning)
    if playerIsInWindow then
        return state.entries[state.windowStart + slotIndex - 1]
    end

    if state.playerRank < state.windowStart then
        if slotIndex == 1 then
            return state.entries[state.playerRank]
        end

        return state.entries[state.windowStart + slotIndex - 2]
    end

    if slotIndex == tuning.SCOREBOARD_VISIBLE_ROW_COUNT then
        return state.entries[state.playerRank]
    end

    return state.entries[state.windowStart + slotIndex - 1]
end

function ScoreboardUI.draw(yOffset, tuning)
    local previousFont = pdg.getFont()
    local previousColor = pdg.getColor()
    local previousDrawMode = pdg.getImageDrawMode()
    local mode = Difficulty.getMode(state.modeIndex)
    local windowEnd = state.windowStart + tuning.SCOREBOARD_VISIBLE_ROW_COUNT - 1
    local playerIsInWindow = state.playerRank >= state.windowStart
        and state.playerRank <= windowEnd

    backgroundImage:draw(0, yOffset)
    pdg.setColor(pdg.kColorBlack)
    pdg.setImageDrawMode(pdg.kDrawModeCopy)
    pdg.setFont(boldFont)
    pdg.drawTextAligned(
        "TOP 100 IN " .. mode.TITLE .. " MODE",
        200,
        yOffset + tuning.SCOREBOARD_TITLE_Y,
        kTextAlignment.center
    )
    pdg.setFont(previousFont)
    pdg.drawLine(
        tuning.SCOREBOARD_CONTENT_LEFT_X,
        yOffset + tuning.SCOREBOARD_HEADER_SEPARATOR_Y,
        tuning.SCOREBOARD_CONTENT_RIGHT_X,
        yOffset + tuning.SCOREBOARD_HEADER_SEPARATOR_Y
    )
    pdg.drawLine(
        200,
        yOffset + tuning.SCOREBOARD_HEADER_SEPARATOR_Y + 3,
        200,
        yOffset + tuning.SCOREBOARD_CONTENT_BOTTOM_Y
    )

    local rowsPerColumn = tuning.SCOREBOARD_VISIBLE_ROW_COUNT / 2
    for slotIndex = 1, tuning.SCOREBOARD_VISIBLE_ROW_COUNT do
        local entry = getVisibleEntry(slotIndex, playerIsInWindow, tuning)

        if entry ~= nil then
            local columnIndex = math.floor((slotIndex - 1) / rowsPerColumn)
            local rowIndex = (slotIndex - 1) % rowsPerColumn
            local x = tuning.SCOREBOARD_FIRST_COLUMN_X
                + columnIndex * tuning.SCOREBOARD_COLUMN_SPACING
            local y = yOffset + tuning.SCOREBOARD_FIRST_ROW_Y
                + rowIndex * tuning.SCOREBOARD_ROW_HEIGHT
            drawEntry(
                entry,
                x,
                y,
                tuning.SCOREBOARD_COLUMN_WIDTH,
                entry.isPlayer
            )
        end
    end

    pdg.setFont(boldFont)
    pdg.drawText("Scroll", 44, yOffset + tuning.SCOREBOARD_CONTROLS_TEXT_Y)
    pdg.drawText("Change Mode", 153, yOffset + tuning.SCOREBOARD_CONTROLS_TEXT_Y)
    pdg.drawText("Back", 295, yOffset + tuning.SCOREBOARD_CONTROLS_TEXT_Y)

    pdg.setFont(previousFont)
    pdg.setImageDrawMode(previousDrawMode)
    pdg.setColor(previousColor)
end
