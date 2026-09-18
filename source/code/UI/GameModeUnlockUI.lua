local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local tuning = nil
local soundPlayer = nil
local presented = {}
local pending = {}
local activeUnlock = nil
local elapsedMilliseconds = 0
local titleFont = pdg.getFont(pdg.font.kVariantBold)

GameModeUnlockUI = {}

local function smoothstep(progress)
    local clamped = math.max(0, math.min(1, progress))
    return clamped * clamped * (3 - 2 * clamped)
end

local function isQueued(modeId)
    for index = 1, #pending do
        if pending[index].id == modeId then
            return true
        end
    end

    return false
end

function GameModeUnlockUI.initialize(gameplayTuning, savedUnlocks, sfxChannel)
    tuning = gameplayTuning
    savedUnlocks = type(savedUnlocks) == "table" and savedUnlocks or {}
    presented = {
        normal = savedUnlocks.normal == true,
        hardcore = savedUnlocks.hardcore == true,
        otherSide = savedUnlocks.otherSide == true
    }
    pending = {}
    activeUnlock = nil
    elapsedMilliseconds = 0
    soundPlayer = pds.sampleplayer.new("sounds/GameModeUnlock")
    soundPlayer:setVolume(tuning.MODE_UNLOCK_SOUND_VOLUME)
    sfxChannel:addSource(soundPlayer)
end

function GameModeUnlockUI.queue(modeId, title)
    if presented[modeId] == true
        or (activeUnlock ~= nil and activeUnlock.id == modeId)
        or isQueued(modeId)
    then
        return false
    end

    pending[#pending + 1] = { id = modeId, title = title }
    return true
end

function GameModeUnlockUI.peekNext()
    return pending[1]
end

function GameModeUnlockUI.beginNext()
    if activeUnlock ~= nil or #pending == 0 then
        return false
    end

    activeUnlock = table.remove(pending, 1)
    presented[activeUnlock.id] = true
    elapsedMilliseconds = 0

    if soundPlayer:isPlaying() then
        soundPlayer:stop()
    end

    soundPlayer:setOffset(0)
    soundPlayer:play()
    return true
end

function GameModeUnlockUI.isActive()
    return activeUnlock ~= nil
end

function GameModeUnlockUI.update(frameElapsedMilliseconds)
    if activeUnlock == nil then
        return false
    end

    elapsedMilliseconds += frameElapsedMilliseconds

    if elapsedMilliseconds < tuning.MODE_UNLOCK_DURATION_MS then
        return false
    end

    activeUnlock = nil
    elapsedMilliseconds = 0
    return true
end

function GameModeUnlockUI.draw()
    if activeUnlock == nil then
        return
    end

    local progress = math.min(1, elapsedMilliseconds / tuning.MODE_UNLOCK_DURATION_MS)
    local revealProgress = smoothstep(
        elapsedMilliseconds / tuning.MODE_UNLOCK_REVEAL_DURATION_MS
    )
    local pulse = (math.sin(elapsedMilliseconds * math.pi * 2 / 260) + 1) / 2
    local centerX = 200
    local centerY = 120
    local previousColor = pdg.getColor()
    local previousLineWidth = pdg.getLineWidth()
    local previousFont = pdg.getFont()
    local previousDrawMode = pdg.getImageDrawMode()

    pdg.setColor(pdg.kColorBlack)
    pdg.setDitherPattern(
        tuning.MODE_UNLOCK_BACKDROP_DITHER_ALPHA * revealProgress,
        pdg.image.kDitherTypeBayer8x8
    )
    pdg.fillRect(0, 0, 400, 240)

    pdg.setColor(pdg.kColorBlack)
    pdg.setLineWidth(2)

    for ringIndex = 1, tuning.MODE_UNLOCK_RING_COUNT do
        local ringProgress = math.max(
            0,
            math.min(1, progress * 2.2 - (ringIndex - 1) * 0.16)
        )

        if ringProgress > 0 and ringProgress < 1 then
            local ringWidth = 36 + ringProgress * 430
            local ringHeight = 20 + ringProgress * 245
            pdg.drawEllipseInRect(
                centerX - ringWidth / 2,
                centerY - ringHeight / 2,
                ringWidth,
                ringHeight,
                0,
                360
            )
        end
    end

    local rayInnerRadius = 54 + pulse * 5
    local rayOuterRadius = 78 + pulse * 12
    for rayIndex = 1, tuning.MODE_UNLOCK_RAY_COUNT do
        local angle = rayIndex / tuning.MODE_UNLOCK_RAY_COUNT * math.pi * 2
            + elapsedMilliseconds / 850
        pdg.drawLine(
            centerX + math.cos(angle) * rayInnerRadius,
            centerY + math.sin(angle) * rayInnerRadius,
            centerX + math.cos(angle) * rayOuterRadius,
            centerY + math.sin(angle) * rayOuterRadius
        )
    end

    local panelWidth = math.floor(tuning.MODE_UNLOCK_PANEL_WIDTH * revealProgress)
    local panelHeight = tuning.MODE_UNLOCK_PANEL_HEIGHT
    local panelX = math.floor(centerX - panelWidth / 2)
    local panelY = math.floor(centerY - panelHeight / 2)

    if panelWidth > 8 then
        pdg.setColor(pdg.kColorBlack)
        pdg.fillRoundRect(panelX, panelY, panelWidth, panelHeight, 8)
        pdg.setColor(pdg.kColorWhite)
        pdg.setLineWidth(2)
        pdg.drawRoundRect(panelX + 4, panelY + 4, panelWidth - 8, panelHeight - 8, 5)

        if revealProgress >= 0.72 then
            pdg.setImageDrawMode(pdg.kDrawModeFillWhite)
            pdg.setFont(titleFont)
            pdg.drawTextAligned(
                activeUnlock.title,
                centerX,
                panelY + 22,
                kTextAlignment.center
            )
            pdg.setFont(previousFont)
            pdg.drawTextAligned(
                "MODE UNLOCKED",
                centerX,
                panelY + 51,
                kTextAlignment.center
            )
        end
    end

    local flashCycle = elapsedMilliseconds % tuning.MODE_UNLOCK_FLASH_INTERVAL_MS
    if elapsedMilliseconds < tuning.MODE_UNLOCK_INITIAL_FLASH_MS
        or flashCycle < tuning.MODE_UNLOCK_FLASH_DURATION_MS * (1 - progress)
    then
        pdg.setColor(pdg.kColorXOR)
        pdg.fillRect(0, 0, 400, 240)
    end

    pdg.setFont(previousFont)
    pdg.setImageDrawMode(previousDrawMode)
    pdg.setLineWidth(previousLineWidth)
    pdg.setColor(previousColor)
end

function GameModeUnlockUI.getSaveData()
    return {
        normal = presented.normal == true,
        hardcore = presented.hardcore == true,
        otherSide = presented.otherSide == true
    }
end
