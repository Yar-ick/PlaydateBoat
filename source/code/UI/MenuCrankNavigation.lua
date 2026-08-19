local pd <const> = playdate

local travelDegrees = 0
local direction = 0

MenuCrankNavigation = {}

function MenuCrankNavigation.reset()
    travelDegrees = 0
    direction = 0
end

function MenuCrankNavigation.getSelectionDelta(ticksPerRevolution)
    local crankChange = pd.getCrankChange()

    if crankChange == 0 then
        return 0
    end

    local currentDirection = crankChange > 0 and 1 or -1

    if direction ~= 0 and currentDirection ~= direction then
        travelDegrees = 0
    end

    direction = currentDirection
    travelDegrees += crankChange

    local degreesPerSelection = 360 / ticksPerRevolution
    local selectionDelta = 0

    if travelDegrees >= degreesPerSelection then
        selectionDelta = math.floor(travelDegrees / degreesPerSelection)
    elseif travelDegrees <= -degreesPerSelection then
        selectionDelta = math.ceil(travelDegrees / degreesPerSelection)
    end

    travelDegrees -= selectionDelta * degreesPerSelection
    return selectionDelta
end
