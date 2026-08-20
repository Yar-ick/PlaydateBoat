local gfx <const> = playdate.graphics

DecorationManager = {}
DecorationManager.__index = DecorationManager

local function resetSpawnCountdown(decorationType)
    local config = decorationType.config
    decorationType.spawnRemainingMilliseconds =
        math.random(config.minimumIntervalMs, config.maximumIntervalMs)
end

local function despawnDecoration(decoration)
    decoration.active = false
    decoration:setVisible(false)
    decoration:remove()
end

function DecorationManager.new(configs, objectGroups, decorationSprites, settings)
    local manager = setmetatable({}, DecorationManager)
    manager.decorationTypes = {}
    manager.objectGroups = objectGroups
    manager.settings = settings
    manager.spawnDisabled = false

    for configIndex = 1, #configs do
        local config = configs[configIndex]
        local image = gfx.image.new(config.imagePath)
        local imageWidth, imageHeight = image:getSize()
        local decorationType = {
            config = config,
            sprites = {}
        }

        for spriteIndex = 1, config.maximumActive do
            local decoration = gfx.sprite.new(image)
            decoration.objectType = "decoration"
            decoration.decorationType = config.name
            decoration.imageWidth = imageWidth
            decoration.imageHeight = imageHeight
            decoration.active = false
            decoration:setZIndex(settings.DECORATION_Z_INDEX)
            decoration:setVisible(false)
            decorationType.sprites[spriteIndex] = decoration
            decorationSprites[#decorationSprites + 1] = decoration
        end

        resetSpawnCountdown(decorationType)
        manager.decorationTypes[configIndex] = decorationType
    end

    return manager
end

function DecorationManager:spawn(decorationType)
    local decoration = nil

    for i = 1, #decorationType.sprites do
        if decorationType.sprites[i].active == false then
            decoration = decorationType.sprites[i]
            break
        end
    end

    if decoration == nil then
        return false
    end

    local x, y = InteractiveSpawn.findPosition(
        self.objectGroups,
        decoration,
        decoration.imageWidth,
        decoration.imageHeight,
        self.settings.DECORATION_SPAWN_MINIMUM_X,
        -decoration.imageWidth / 2,
        self.settings.WORLD_SPAWN_MINIMUM_Y + decoration.imageHeight / 2,
        self.settings.WORLD_SPAWN_MAXIMUM_Y - decoration.imageHeight / 2,
        self.settings.INTERACTIVE_SPAWN_PADDING,
        self.settings.INTERACTIVE_SPAWN_ATTEMPTS
    )

    if x == nil then
        return false
    end

    decoration:moveTo(x, y)
    decoration.active = true
    decoration:setVisible(true)
    decoration:add()
    return true
end


function DecorationManager:update(elapsedMilliseconds, worldDisplacement, currentWorldVelocity)
    for typeIndex = 1, #self.decorationTypes do
        local decorationType = self.decorationTypes[typeIndex]

        for spriteIndex = 1, #decorationType.sprites do
            local decoration = decorationType.sprites[spriteIndex]

            if decoration.active then
                decoration:moveBy(worldDisplacement, 0)

                if decoration.x - decoration.imageWidth / 2 > 400 then
                    despawnDecoration(decoration)
                end
            end
        end
    end

    if currentWorldVelocity >= self.settings.DECORATION_STOP_SPAWN_WORLD_VELOCITY then
        self.spawnDisabled = true
    end

    if self.spawnDisabled then
        return
    end

    for typeIndex = 1, #self.decorationTypes do
        local decorationType = self.decorationTypes[typeIndex]
        decorationType.spawnRemainingMilliseconds -= elapsedMilliseconds

        if decorationType.spawnRemainingMilliseconds <= 0 then
            resetSpawnCountdown(decorationType)

            if math.random(100) <= decorationType.config.spawnChancePercent then
                self:spawn(decorationType)
            end
        end
    end
end

function DecorationManager:clearDecoration(decoration)
    if decoration == nil or decoration.active == false then
        return false
    end

    despawnDecoration(decoration)
    return true
end

function DecorationManager:reset()
    self.spawnDisabled = false

    for typeIndex = 1, #self.decorationTypes do
        local decorationType = self.decorationTypes[typeIndex]
        resetSpawnCountdown(decorationType)

        for spriteIndex = 1, #decorationType.sprites do
            despawnDecoration(decorationType.sprites[spriteIndex])
        end
    end
end
