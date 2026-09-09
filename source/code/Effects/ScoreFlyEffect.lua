local pdg <const> = playdate.graphics

local tuning = nil
local effects = {}
local scoreImageCache = {}

ScoreFlyEffect = {}

local function smoothStep(progress)
    return progress * progress * (3 - 2 * progress)
end

local function getScoreImage(scoreValue)
    local cachedImage = scoreImageCache[scoreValue]

    if cachedImage ~= nil then
        return cachedImage
    end

    local scoreText = "+" .. tostring(scoreValue)
    local textWidth, textHeight = pdg.getTextSize(scoreText)
    local imageWidth = textWidth + 5
    local imageHeight = textHeight + 4
    local image = pdg.image.new(imageWidth, imageHeight)

    pdg.pushContext(image)
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

    cachedImage = {
        image = image,
        width = imageWidth,
        height = imageHeight
    }
    scoreImageCache[scoreValue] = cachedImage
    return cachedImage
end

function ScoreFlyEffect.initialize(gameplayTuning)
    tuning = gameplayTuning
    getScoreImage(tuning.RAMP_JUMP_SCORE_REWARD)
    getScoreImage(tuning.OTHER_SIDE_OIL_SCORE)
end

function ScoreFlyEffect.start(x, y, scoreValue)
    effects[#effects + 1] = {
        scoreValue = scoreValue,
        imageData = getScoreImage(scoreValue),
        isShrinking = false,
        elapsedMilliseconds = 0,
        startX = x,
        startY = y,
        drawX = x,
        drawY = y,
        drawScale = 1
    }
end

function ScoreFlyEffect.update(deltaMilliseconds)
    local reachedScoreValue = 0

    for index = #effects, 1, -1 do
        local effect = effects[index]
        effect.elapsedMilliseconds += deltaMilliseconds

        if effect.isShrinking then
            local progress = math.min(
                effect.elapsedMilliseconds / tuning.RAMP_SCORE_SHRINK_DURATION_MS,
                1
            )
            effect.drawScale = 1 - smoothStep(progress)

            if progress >= 1 then
                table.remove(effects, index)
            end
        else
            local progress = math.min(
                effect.elapsedMilliseconds / tuning.RAMP_SCORE_FLY_DURATION_MS,
                1
            )
            local easedProgress = smoothStep(progress)
            effect.drawX = effect.startX
                + (tuning.RAMP_SCORE_FLY_TARGET_X - effect.startX) * easedProgress
            effect.drawY = effect.startY
                + (tuning.RAMP_SCORE_FLY_TARGET_Y - effect.startY) * easedProgress
                - math.sin(progress * math.pi) * tuning.RAMP_SCORE_FLY_ARC_HEIGHT

            if progress >= 1 then
                effect.drawX = tuning.RAMP_SCORE_FLY_TARGET_X
                effect.drawY = tuning.RAMP_SCORE_FLY_TARGET_Y
                effect.isShrinking = true
                effect.elapsedMilliseconds = 0
                reachedScoreValue += effect.scoreValue
            end
        end
    end

    return reachedScoreValue > 0 and reachedScoreValue or nil
end

function ScoreFlyEffect.draw()
    for index = 1, #effects do
        local effect = effects[index]

        if effect.drawScale > 0 then
            local imageData = effect.imageData
            imageData.image:drawScaled(
                effect.drawX - imageData.width * effect.drawScale / 2,
                effect.drawY - imageData.height * effect.drawScale / 2,
                effect.drawScale
            )
        end
    end
end

function ScoreFlyEffect.reset()
    effects = {}
end
