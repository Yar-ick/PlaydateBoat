local pdg <const> = playdate.graphics
local pds <const> = playdate.sound

local boldFont <const> = pdg.getFont(pdg.font.kVariantBold)
local starImage <const> = pdg.image.new("images/Star")
local coinImagetable <const> = pdg.imagetable.new("images/Coin")

local tuning = nil
local scoreSoundPlayer = nil
local coinSoundPlayer = nil
local openSoundPlayer = nil
local closeSoundPlayer = nil
local stage = "hidden"
local slideProgress = 0
local stageElapsedMilliseconds = 0
local soundElapsedMilliseconds = 0
local coinAnimationElapsedMilliseconds = 0
local targetScore = 0
local targetCoins = 0
local displayedScore = 0
local displayedCoins = 0
local previousDisplayedScore = 0
local previousDisplayedCoins = 0
local scoreNumber = FixedWidthNumber.new(7)
local coinNumber = FixedWidthNumber.new(3)

RunResultsUI = {}

local function smoothstep(progress)
    progress = math.clamp(progress, 0, 1)
    return progress * progress * (3 - 2 * progress)
end

local function exponentialEaseOut(progress)
    progress = math.clamp(progress, 0, 1)

    if progress >= 1 then
        return 1
    end

    local curve = tuning.RUN_RESULTS_COUNT_EXPONENTIAL_CURVE
    return (1 - math.exp(-curve * progress)) / (1 - math.exp(-curve))
end

local function playPitchedSound(soundPlayer, rate)
    if soundPlayer:isPlaying() then
        soundPlayer:stop()
    end

    soundPlayer:setOffset(0)
    soundPlayer:setRate(rate)
    soundPlayer:play()
end

local function updateCountingStage(
    elapsedMilliseconds,
    durationMilliseconds,
    targetValue,
    previousValue,
    soundIntervalMilliseconds,
    minimumSoundRate,
    maximumSoundRate,
    soundPlayer
)
    stageElapsedMilliseconds += elapsedMilliseconds
    soundElapsedMilliseconds += elapsedMilliseconds
    local progress = math.min(
        1,
        stageElapsedMilliseconds / durationMilliseconds
    )
    local displayedValue = math.floor(
        targetValue * exponentialEaseOut(progress) + 0.5
    )

    if displayedValue ~= previousValue
        and (soundElapsedMilliseconds >= soundIntervalMilliseconds or progress >= 1)
    then
        local rate = minimumSoundRate
            + (maximumSoundRate - minimumSoundRate) * progress
        playPitchedSound(soundPlayer, rate)
        soundElapsedMilliseconds = 0
    end

    return displayedValue, progress
end

local function drawPanel(x, y, width, height)
    local shadowOffset = tuning.RUN_RESULTS_FRAME_SHADOW_OFFSET
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

local function drawResultRow(image, number, centerX, y)
    local imageWidth, imageHeight = image:getSize()
    local rowWidth = imageWidth + tuning.RUN_RESULTS_ICON_NUMBER_GAP
        + number.width
    local x = math.floor(centerX - rowWidth / 2)
    image:draw(x, y)
    FixedWidthNumber.draw(
        number,
        x + imageWidth + tuning.RUN_RESULTS_ICON_NUMBER_GAP,
        y + math.floor((imageHeight - tuning.RUN_RESULTS_NUMBER_HEIGHT) / 2)
    )
end

function RunResultsUI.initialize(gameplayTuning, sfxChannel)
    tuning = gameplayTuning
    scoreSoundPlayer = pds.sampleplayer.new("sounds/AbilityUpgradeSuccess3")
    scoreSoundPlayer:setVolume(tuning.RAMP_SUCCESS_SOUND_VOLUME)
    coinSoundPlayer = pds.sampleplayer.new("sounds/CoinPickup")
    coinSoundPlayer:setVolume(tuning.RUN_RESULTS_COIN_SOUND_VOLUME)
    openSoundPlayer = pds.sampleplayer.new("sounds/ResultMenuOpen")
    openSoundPlayer:setVolume(tuning.RUN_RESULTS_MENU_SOUND_VOLUME)
    openSoundPlayer:setRate(tuning.RUN_RESULTS_OPEN_SOUND_RATE)
    closeSoundPlayer = pds.sampleplayer.new("sounds/ResultMenuClose")
    closeSoundPlayer:setVolume(tuning.RUN_RESULTS_MENU_SOUND_VOLUME)
    closeSoundPlayer:setRate(tuning.RUN_RESULTS_CLOSE_SOUND_RATE)
    sfxChannel:addSource(scoreSoundPlayer)
    sfxChannel:addSource(coinSoundPlayer)
    sfxChannel:addSource(openSoundPlayer)
    sfxChannel:addSource(closeSoundPlayer)
end

function RunResultsUI.show(score, coins)
    targetScore = math.max(0, math.floor(score or 0))
    targetCoins = math.max(0, math.floor(coins or 0))
    displayedScore = 0
    displayedCoins = 0
    previousDisplayedScore = 0
    previousDisplayedCoins = 0
    slideProgress = 0
    stageElapsedMilliseconds = 0
    soundElapsedMilliseconds = 0
    coinAnimationElapsedMilliseconds = 0
    stage = "entering"
    FixedWidthNumber.update(scoreNumber, 0)
    FixedWidthNumber.update(coinNumber, 0)
    openSoundPlayer:setOffset(0)
    openSoundPlayer:play()
end

function RunResultsUI.update(elapsedMilliseconds, confirmPressed)
    if stage == "hidden" then
        return false
    end

    coinAnimationElapsedMilliseconds += elapsedMilliseconds

    if stage == "entering" then
        slideProgress = math.min(
            1,
            slideProgress
                + elapsedMilliseconds / tuning.RUN_RESULTS_SLIDE_DURATION_MS
        )

        if slideProgress >= 1 then
            stage = "score"
            stageElapsedMilliseconds = 0
            soundElapsedMilliseconds = tuning.RUN_RESULTS_SCORE_SOUND_INTERVAL_MS
        end
    elseif stage == "score" then
        local scoreProgress
        displayedScore, scoreProgress = updateCountingStage(
            elapsedMilliseconds,
            tuning.RUN_RESULTS_SCORE_COUNT_DURATION_MS,
            targetScore,
            previousDisplayedScore,
            tuning.RUN_RESULTS_SCORE_SOUND_INTERVAL_MS,
            tuning.RUN_RESULTS_SCORE_MINIMUM_SOUND_RATE,
            tuning.RUN_RESULTS_SCORE_MAXIMUM_SOUND_RATE,
            scoreSoundPlayer
        )
        previousDisplayedScore = displayedScore
        FixedWidthNumber.update(scoreNumber, displayedScore)

        if scoreProgress >= 1 then
            displayedScore = targetScore
            FixedWidthNumber.update(scoreNumber, displayedScore)
            stage = "coins"
            stageElapsedMilliseconds = 0
            soundElapsedMilliseconds = tuning.RUN_RESULTS_COIN_SOUND_INTERVAL_MS
        end
    elseif stage == "coins" then
        local coinProgress
        displayedCoins, coinProgress = updateCountingStage(
            elapsedMilliseconds,
            tuning.RUN_RESULTS_COIN_COUNT_DURATION_MS,
            targetCoins,
            previousDisplayedCoins,
            tuning.RUN_RESULTS_COIN_SOUND_INTERVAL_MS,
            tuning.RUN_RESULTS_COIN_MINIMUM_SOUND_RATE,
            tuning.RUN_RESULTS_COIN_MAXIMUM_SOUND_RATE,
            coinSoundPlayer
        )
        previousDisplayedCoins = displayedCoins
        FixedWidthNumber.update(coinNumber, displayedCoins)

        if coinProgress >= 1 then
            displayedCoins = targetCoins
            FixedWidthNumber.update(coinNumber, displayedCoins)
            stage = "ready"
        end
    elseif stage == "ready" and confirmPressed then
        closeSoundPlayer:setOffset(0)
        closeSoundPlayer:play()
        stage = "exiting"
    elseif stage == "exiting" then
        slideProgress = math.max(
            0,
            slideProgress
                - elapsedMilliseconds / tuning.RUN_RESULTS_SLIDE_DURATION_MS
        )

        if slideProgress <= 0 then
            RunResultsUI.reset()
            return true
        end
    end

    return false
end

function RunResultsUI.draw()
    if stage == "hidden" then
        return
    end

    local previousColor = pdg.getColor()
    local previousFont = pdg.getFont()
    local previousDrawMode = pdg.getImageDrawMode()
    local frameWidth = tuning.RUN_RESULTS_FRAME_WIDTH
    local frameHeight = tuning.RUN_RESULTS_FRAME_HEIGHT
    local frameX = math.floor((400 - frameWidth) / 2)
    local targetY = math.floor((240 - frameHeight) / 2)
    local hiddenY = -frameHeight - tuning.RUN_RESULTS_FRAME_SHADOW_OFFSET
    local frameY = math.floor(
        hiddenY + (targetY - hiddenY) * smoothstep(slideProgress)
    )
    local centerX = frameX + frameWidth / 2

    drawPanel(frameX, frameY, frameWidth, frameHeight)
    pdg.drawLine(
        frameX + tuning.RUN_RESULTS_FRAME_SEPARATOR_INSET,
        frameY + tuning.RUN_RESULTS_FIRST_SEPARATOR_Y,
        frameX + frameWidth - tuning.RUN_RESULTS_FRAME_SEPARATOR_INSET,
        frameY + tuning.RUN_RESULTS_FIRST_SEPARATOR_Y
    )
    pdg.drawLine(
        frameX + tuning.RUN_RESULTS_FRAME_SEPARATOR_INSET,
        frameY + tuning.RUN_RESULTS_SECOND_SEPARATOR_Y,
        frameX + frameWidth - tuning.RUN_RESULTS_FRAME_SEPARATOR_INSET,
        frameY + tuning.RUN_RESULTS_SECOND_SEPARATOR_Y
    )

    pdg.setImageDrawMode(pdg.kDrawModeCopy)
    drawResultRow(
        starImage,
        scoreNumber,
        centerX,
        frameY + tuning.RUN_RESULTS_SCORE_ROW_Y
    )
    local coinFrame = math.floor(
        coinAnimationElapsedMilliseconds
            / tuning.RUN_RESULTS_COIN_FRAME_DURATION_MS
    ) % coinImagetable:getLength() + 1
    drawResultRow(
        coinImagetable:getImage(coinFrame),
        coinNumber,
        centerX,
        frameY + tuning.RUN_RESULTS_COIN_ROW_Y
    )

    pdg.setFont(boldFont)
    pdg.drawTextAligned(
        "Press A to return",
        centerX,
        frameY + tuning.RUN_RESULTS_PROMPT_Y,
        kTextAlignment.center
    )
    pdg.setImageDrawMode(previousDrawMode)
    pdg.setFont(previousFont)
    pdg.setColor(previousColor)
end

function RunResultsUI.isClosing()
    return stage == "exiting"
end

function RunResultsUI.reset()
    stage = "hidden"
    slideProgress = 0

    if scoreSoundPlayer ~= nil and scoreSoundPlayer:isPlaying() then
        scoreSoundPlayer:stop()
    end

    if coinSoundPlayer ~= nil and coinSoundPlayer:isPlaying() then
        coinSoundPlayer:stop()
    end

    if openSoundPlayer ~= nil and openSoundPlayer:isPlaying() then
        openSoundPlayer:stop()
    end

    if closeSoundPlayer ~= nil and closeSoundPlayer:isPlaying() then
        closeSoundPlayer:stop()
    end
end
