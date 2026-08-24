local pdg <const> = playdate.graphics

local tuning = nil
local visible = false
local x = 0
local y = 0
local scale = 0
local opacity = 1
local fading = false
local fadeElapsedMilliseconds = 0

local bayerThresholds <const> = {
    0, 8, 2, 10,
    12, 4, 14, 6,
    3, 11, 1, 9,
    15, 7, 13, 5
}

FlightShadow = {}

function FlightShadow.initialize(gameplayTuning)
    tuning = gameplayTuning
    FlightShadow.reset()
end

function FlightShadow.update(
    elapsedMilliseconds,
    playerX,
    playerY,
    isAirborne,
    didLand,
    jumpScale,
    boatScale
)
    if isAirborne == false and didLand == false and fading == false then
        FlightShadow.reset()
        return
    end

    if didLand then
        visible = true
        fading = true
        fadeElapsedMilliseconds = 0
        opacity = 1
        x = playerX
        scale = boatScale * tuning.RAMP_FLIGHT_SHADOW_MAXIMUM_SCALE
        local halfHeight = tuning.RAMP_FLIGHT_SHADOW_HEIGHT * scale / 2
        y = math.min(
            playerY + tuning.RAMP_FLIGHT_SHADOW_BASE_Y_OFFSET * boatScale,
            239 - halfHeight
        )
        WakeLayer.markDirty()
        return
    end

    if isAirborne == false then
        fadeElapsedMilliseconds += elapsedMilliseconds
        local fadeProgress = math.min(
            1,
            fadeElapsedMilliseconds / tuning.RAMP_FLIGHT_SHADOW_FADE_DURATION_MS
        )
        opacity = 1 - fadeProgress * fadeProgress * (3 - 2 * fadeProgress)

        if fadeProgress >= 1 then
            FlightShadow.reset()
        else
            WakeLayer.markDirty()
        end

        return
    end

    local heightProgress = math.clamp(
        (jumpScale - 1) / math.max(0.001, tuning.RAMP_JUMP_SCALE_INCREASE),
        0,
        1
    )

    visible = true
    fading = false
    fadeElapsedMilliseconds = 0
    opacity = 1
    x = playerX
    scale = boatScale * (
        tuning.RAMP_FLIGHT_SHADOW_MAXIMUM_SCALE
            - (tuning.RAMP_FLIGHT_SHADOW_MAXIMUM_SCALE
                - tuning.RAMP_FLIGHT_SHADOW_MINIMUM_SCALE) * heightProgress
    )
    local yOffset = (
        tuning.RAMP_FLIGHT_SHADOW_BASE_Y_OFFSET
            + tuning.RAMP_FLIGHT_SHADOW_HEIGHT_Y_OFFSET * heightProgress
    ) * boatScale
    local halfHeight = tuning.RAMP_FLIGHT_SHADOW_HEIGHT * scale / 2
    y = math.min(playerY + yOffset, 239 - halfHeight)
    WakeLayer.markDirty()
end

function FlightShadow.draw()
    if visible == false or scale <= 0 then
        return
    end

    local halfWidth = tuning.RAMP_FLIGHT_SHADOW_WIDTH * scale / 2
    local halfHeight = tuning.RAMP_FLIGHT_SHADOW_HEIGHT * scale / 2

    if halfWidth < 1 or halfHeight < 1 then
        return
    end

    pdg.setColor(pdg.kColorBlack)

    if fading == false then
        pdg.fillEllipseInRect(
            math.floor(x - halfWidth + 0.5),
            math.floor(y - halfHeight + 0.5),
            math.max(1, math.floor(halfWidth * 2 + 0.5)),
            math.max(1, math.floor(halfHeight * 2 + 0.5))
        )
        return
    end

    local top = math.ceil(y - halfHeight)
    local bottom = math.floor(y + halfHeight)

    for pixelY = top, bottom do
        local normalizedY = (pixelY - y) / halfHeight
        local lineHalfWidth = halfWidth
            * math.sqrt(math.max(0, 1 - normalizedY * normalizedY))
        local left = math.ceil(x - lineHalfWidth)
        local right = math.floor(x + lineHalfWidth)

        for pixelX = left, right do
            local thresholdIndex = pixelY % 4 * 4 + pixelX % 4 + 1
            local threshold = (bayerThresholds[thresholdIndex] + 0.5) / 16

            if threshold <= opacity then
                pdg.drawPixel(pixelX, pixelY)
            end
        end
    end
end

function FlightShadow.reset()
    local wasVisible = visible
    visible = false
    scale = 0
    opacity = 1
    fading = false
    fadeElapsedMilliseconds = 0

    if wasVisible then
        WakeLayer.markDirty()
    end
end
