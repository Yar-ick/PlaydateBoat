local pdg <const> = playdate.graphics

local buoyImage <const> = pdg.image.new("images/ShallowWaterBuoy")

local tuning = nil
local interactableObjectGroups = nil
local areas = {}
local shallowWaterImage = nil
local spawnRemainingMilliseconds = 0
local running = false
local playerInside = false

ShallowWaters = {}

local function makeShallowWaterImage()
    local width = tuning.OTHER_SIDE_SHALLOW_WATER_WIDTH
    local height = tuning.OTHER_SIDE_SHALLOW_WATER_HEIGHT
    local image = pdg.image.new(width, height)

    pdg.pushContext(image)
    pdg.setColor(pdg.kColorBlack)
    pdg.setDitherPattern(
        tuning.OTHER_SIDE_SHALLOW_WATER_DITHER_ALPHA,
        pdg.image.kDitherTypeBayer8x8
    )
    pdg.fillEllipseInRect(0, 0, width, height)
    pdg.setColor(pdg.kColorBlack)
    buoyImage:drawAnchored(width / 2, height / 2, 0.5, 0.5)
    pdg.popContext()
    return image
end

local function resetSpawnCountdown()
    spawnRemainingMilliseconds = math.random(
        tuning.OTHER_SIDE_SHALLOW_WATER_MINIMUM_SPAWN_INTERVAL_MS,
        tuning.OTHER_SIDE_SHALLOW_WATER_MAXIMUM_SPAWN_INTERVAL_MS
    )
end

local function deactivate(area)
    area.active = false
    area:setVisible(false)

    if area.shallowWaterAdded then
        area:remove()
        area.shallowWaterAdded = false
    end
end

local function findInactiveArea()
    for index = 1, #areas do
        if areas[index].active == false then
            return areas[index]
        end
    end

    return nil
end

local function hasActiveArea()
    for index = 1, #areas do
        if areas[index].active then
            return true
        end
    end

    return false
end

local function activate(area, x, y)
    area.active = true
    area:moveTo(x, y)
    area:setVisible(true)

    if area.shallowWaterAdded == false then
        area:add()
        area.shallowWaterAdded = true
    end
end

local function spawnWorldArea()
    local area = findInactiveArea()

    if area == nil then
        return false
    end

    local x, y = InteractiveSpawn.findPosition(
        interactableObjectGroups,
        area,
        area.imageWidth,
        area.imageHeight,
        tuning.OTHER_SIDE_SHALLOW_WATER_SPAWN_MINIMUM_X,
        -area.imageWidth / 2,
        tuning.WORLD_SPAWN_MINIMUM_Y + area.imageHeight / 2,
        tuning.WORLD_SPAWN_MAXIMUM_Y - area.imageHeight / 2,
        tuning.INTERACTIVE_SPAWN_PADDING,
        tuning.INTERACTIVE_SPAWN_ATTEMPTS
    )

    if x == nil then
        return false
    end

    activate(area, x, y)
    return true
end

local function containsPlayer(area, playerX, playerY)
    local radiusX = area.imageWidth / 2
        + tuning.OTHER_SIDE_SHALLOW_WATER_COLLISION_PADDING
    local radiusY = area.imageHeight / 2
        + tuning.OTHER_SIDE_SHALLOW_WATER_COLLISION_PADDING
    local normalizedX = (playerX - area.x) / radiusX
    local normalizedY = (playerY - area.y) / radiusY
    return normalizedX * normalizedX + normalizedY * normalizedY <= 1
end

function ShallowWaters.initialize(gameplayTuning, objectGroups)
    tuning = gameplayTuning
    interactableObjectGroups = objectGroups
    shallowWaterImage = makeShallowWaterImage()
    local imageWidth, imageHeight = shallowWaterImage:getSize()

    for index = 1, tuning.OTHER_SIDE_SHALLOW_WATER_POOL_SIZE do
        local area = pdg.sprite.new(shallowWaterImage)
        area.active = false
        area.shallowWaterAdded = false
        area.imageWidth = imageWidth
        area.imageHeight = imageHeight
        area:setZIndex(tuning.OTHER_SIDE_SHALLOW_WATER_Z_INDEX)
        area:setVisible(false)
        areas[index] = area
    end

    interactableObjectGroups[#interactableObjectGroups + 1] = areas
end

function ShallowWaters.beginRun()
    running = true
    playerInside = false
    resetSpawnCountdown()
end

function ShallowWaters.update(
    elapsedMilliseconds,
    worldDisplacement,
    playerX,
    playerY
)
    playerInside = false

    for index = 1, #areas do
        local area = areas[index]

        if area.active then
            area:moveBy(worldDisplacement, 0)

            if containsPlayer(area, playerX, playerY) then
                playerInside = true
            end

            if area.x - area.imageWidth / 2 > 400 then
                deactivate(area)
            end
        end
    end

    if running == false or hasActiveArea() then
        return
    end

    spawnRemainingMilliseconds -= elapsedMilliseconds

    if spawnRemainingMilliseconds <= 0 then
        resetSpawnCountdown()

        if math.random(100)
            <= tuning.OTHER_SIDE_SHALLOW_WATER_SPAWN_CHANCE_PERCENT
        then
            spawnWorldArea()
        end
    end
end

function ShallowWaters.isPlayerInside()
    return playerInside
end

function ShallowWaters.rewind(displacement)
    playerInside = false

    for index = 1, #areas do
        local area = areas[index]

        if area.active then
            area:moveBy(displacement, 0)

            if area.x + area.imageWidth / 2 < 0 then
                deactivate(area)
            end
        end
    end
end

function ShallowWaters.reset()
    running = false
    playerInside = false
    spawnRemainingMilliseconds = 0

    for index = 1, #areas do
        deactivate(areas[index])
    end
end
