local pdg <const> = playdate.graphics

local tuning = nil
local scoreImage = nil
local scoreImageWidth = 0
local scoreImageHeight = 0
local active = false
local isShrinking = false
local elapsedMilliseconds = 0
local startX = 0
local startY = 0
local drawX = 0
local drawY = 0
local drawScale = 1

ScoreFlyEffect = {}

local function smoothStep(progress)
    return progress * progress * (3 - 2 * progress)
end

function ScoreFlyEffect.initialize(gameplayTuning)
    tuning = gameplayTuning

    local scoreText = "+" .. tostring(tuning.RAMP_JUMP_SCORE_REWARD)
    local textWidth, textHeight = pdg.getTextSize(scoreText)
    scoreImageWidth = textWidth + 5
    scoreImageHeight = textHeight + 4
    scoreImage = pdg.image.new(scoreImageWidth, scoreImageHeight)

    pdg.pushContext(scoreImage)
    pdg.setColor(pdg.kColorWhite)

    for offsetY = 0, 2 do
        for offsetX = 0, 2 do
            pdg.drawText(scoreText, 1 + offsetX, 1 + offsetY)
        end
    end

    pdg.setColor(pdg.kColorBlack)
    pdg.drawText(scoreText, 2, 2)
    pdg.drawText(scoreText, 3, 2)
    pdg.popContext()
end

function ScoreFlyEffect.start(x, y)
    active = true
    isShrinking = false
    elapsedMilliseconds = 0
    startX = x
    startY = y
    drawX = x
    drawY = y
    drawScale = 1
end

function ScoreFlyEffect.update(deltaMilliseconds)
    if active == false then
        return false
    end

    elapsedMilliseconds += deltaMilliseconds

    if isShrinking then
        local progress = math.min(
            elapsedMilliseconds / tuning.RAMP_SCORE_SHRINK_DURATION_MS,
            1
        )
        drawScale = 1 - smoothStep(progress)

        if progress >= 1 then
            active = false
        end

        return false
    end

    local progress = math.min(
        elapsedMilliseconds / tuning.RAMP_SCORE_FLY_DURATION_MS,
        1
    )
    local easedProgress = smoothStep(progress)
    drawX = startX
        + (tuning.RAMP_SCORE_FLY_TARGET_X - startX) * easedProgress
    drawY = startY
        + (tuning.RAMP_SCORE_FLY_TARGET_Y - startY) * easedProgress
        - math.sin(progress * math.pi) * tuning.RAMP_SCORE_FLY_ARC_HEIGHT

    if progress >= 1 then
        drawX = tuning.RAMP_SCORE_FLY_TARGET_X
        drawY = tuning.RAMP_SCORE_FLY_TARGET_Y
        isShrinking = true
        elapsedMilliseconds = 0
        return true
    end

    return false
end

function ScoreFlyEffect.draw()
    if active == false or drawScale <= 0 then
        return
    end

    scoreImage:drawScaled(
        drawX - scoreImageWidth * drawScale / 2,
        drawY - scoreImageHeight * drawScale / 2,
        drawScale
    )
end

function ScoreFlyEffect.reset()
    active = false
    isShrinking = false
    elapsedMilliseconds = 0
    drawScale = 1
end
