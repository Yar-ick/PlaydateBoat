local pdg <const> = playdate.graphics

local settings = nil
local elapsedMilliseconds = 0
local phase = 0
local offsetX = 0
local offsetY = 0

ScreenShake = {}

local function calculateOffset()
    if settings == nil then
        offsetX = 0
        offsetY = 0
        return
    end

    local progress = math.clamp(elapsedMilliseconds / settings.DURATION_MS, 0, 1)
    local strength = (1 - progress) ^ settings.DECAY_POWER
    local currentPhase = phase
        + elapsedMilliseconds * settings.FREQUENCY_HZ * math.pi * 2 / 1000

    offsetX = math.floor(
        math.sin(currentPhase) * settings.HORIZONTAL_AMPLITUDE * strength + 0.5
    )
    offsetY = math.floor(
        math.sin(currentPhase * 1.37 + 1.9) * settings.VERTICAL_AMPLITUDE * strength + 0.5
    )
end

function ScreenShake.start(newSettings)
    settings = newSettings
    elapsedMilliseconds = 0
    phase = math.random() * math.pi * 2
    calculateOffset()
end

function ScreenShake.update(frameElapsedMilliseconds)
    if settings == nil then
        return
    end

    elapsedMilliseconds += frameElapsedMilliseconds

    if elapsedMilliseconds >= settings.DURATION_MS then
        settings = nil
        offsetX = 0
        offsetY = 0
        return
    end

    calculateOffset()
end

function ScreenShake.applyDrawOffset()
    pdg.setDrawOffset(offsetX, offsetY)
end

function ScreenShake.clearDrawOffset()
    pdg.setDrawOffset(0, 0)
end

function ScreenShake.reset()
    settings = nil
    elapsedMilliseconds = 0
    offsetX = 0
    offsetY = 0
    ScreenShake.clearDrawOffset()
end
