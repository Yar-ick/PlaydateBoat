import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank"
import "CoreLibs/animation"
import "CoreLibs/object"
import "CoreLibs/sprites"

-- Localizing commonly used globals
local pd <const> = playdate
local gfx <const> = playdate.graphics

local GameState = {
    ALIVE = 1,
    CRASHED = 2
}

local BoatGameState = GameState.ALIVE

local playerImagetable = gfx.imagetable.new("images/Boat")
local playerImagetableSize = playerImagetable:getLength()
local explosionImagetable = gfx.imagetable.new("images/Explosion")
local explosionX, explosionY = 0, 0
local explosionAnimation = nil
local explosionFrameDelay = 100
local explosionImageWidth, explosionImageHeight = explosionImagetable:getImage(1):getSize()

-- Player variables
local playerScore = 0
local playerScoreStep = 10
local playerVelocity = 2
local playerSpeedMode = 1  -- 0: No speed, 1: Normal speed, 2: Fast speed
local playerStartX, playerStartY = 200, 130
local playerX, playerY = playerStartX, playerStartY

local scoreTimer = pd.timer.new(1000, function()
    if BoatGameState == GameState.ALIVE and pd.isCrankDocked() == false then
        playerScore += playerScoreStep
    end
end)
scoreTimer.repeats = true

-- Velocity inertia variables
local xVelocity = 0
local yVelocity = 0
local targetXVelocity = 0
local targetYVelocity = 0
local velocityInterpolationSpeed = 0.25  -- Smoothness of velocity transitions (0.0-1.0)

-- Water stream velocity
local waterStreamVelocity = 3  -- X+ direction velocity from water stream

local waterVelocity = 1
local interpolatedWaterVelocity = waterVelocity
local waterImage = gfx.image.new("images/WaterBackground")
local waterImageWidth = waterImage:getSize()
local waterSprites = {}

for i = 1, 2 do
    local waterSprite = gfx.sprite.new(waterImage)
    waterSprite:moveTo(-(i - 1) * waterImageWidth, 140)
    waterSprite:setZIndex(-1000)
    waterSprite:add()
    waterSprites[i] = waterSprite
end

local rockVelocity = 1
local interpolatedRockVelocity = rockVelocity
local worldVelocityInterpolationSpeed = 0.08
local rockImage1 = gfx.image.new("images/Rock1")
local rockImage2 = gfx.image.new("images/Rock2")
local rockImage3 = gfx.image.new("images/Rock3")
local rockImage4 = gfx.image.new("images/Rock4")
local rockImages = { rockImage1, rockImage2, rockImage3, rockImage4 }
local rockImageWidths = {}
local rockImageHeights = {}
local maxRocks = 10
local rockSprites = {}
local rockSpawnPadding = 4

for i = 1, #rockImages do
    rockImageWidths[i], rockImageHeights[i] = rockImages[i]:getSize()
end

local function setRockImage(rock, imageIndex)
    rock.imageIndex = imageIndex
    rock.imageWidth = rockImageWidths[imageIndex]
    rock.imageHeight = rockImageHeights[imageIndex]
    rock:setImage(rockImages[imageIndex])
    rock:setCollideRect(0, 0, rock.imageWidth, rock.imageHeight)
end

local function rocksOverlap(x, y, width, height, otherRock)
    local horizontalDistance = math.abs(x - otherRock.x)
    local verticalDistance = math.abs(y - otherRock.y)
    local minimumHorizontalDistance =
        (width + otherRock.imageWidth) / 2 + rockSpawnPadding
    local minimumVerticalDistance =
        (height + otherRock.imageHeight) / 2 + rockSpawnPadding

    return horizontalDistance < minimumHorizontalDistance
        and verticalDistance < minimumVerticalDistance
end

local function findRockSpawnPosition(rock)
    local minimumX = -600
    local maximumX = -rock.imageWidth / 2
    local minimumY = 50 + rock.imageHeight / 2
    local maximumY = 240 - rock.imageHeight / 2

    for _ = 1, 200 do
        local x = math.random(minimumX, maximumX)
        local y = math.random(minimumY, maximumY)
        local overlaps = false

        for i = 1, maxRocks do
            local otherRock = rockSprites[i]

            if otherRock ~= nil
                and otherRock ~= rock
                and otherRock.active
                and rocksOverlap(x, y, rock.imageWidth, rock.imageHeight, otherRock)
            then
                overlaps = true
                break
            end
        end

        if overlaps == false then
            return x, y
        end
    end

    return nil, nil
end

local function resetRockPosition(rock)
    setRockImage(rock, math.random(#rockImages))

    local x, y = findRockSpawnPosition(rock)
    if x == nil then
        rock.active = false
        rock:setVisible(false)
        return false
    end

    rock:moveTo(x, y)
    rock.active = true
    rock:setVisible(true)
    return true
end

for i = 1, maxRocks do
    local rock = gfx.sprite.new()
    rock.collisionResponse = gfx.sprite.kCollisionTypeOverlap
    rock:moveTo(-20, -100)
    rock:setVisible(false)
    rock.active = false
    rock:add()
    rockSprites[i] = rock
end

for i = 1, maxRocks do
    resetRockPosition(rockSprites[i])
end

local velocityIncreaseTimer = pd.timer.new(5000, function()
    rockVelocity = rockVelocity + 0.5
    waterVelocity = waterVelocity + 0.5
    playerScoreStep += 10
end)
velocityIncreaseTimer.repeats = true
velocityIncreaseTimer:pause()

-- Player image
local playerSprite = gfx.sprite.new(playerImagetable:getImage(1))
local playerImageWidth, playerImageHeight = playerImagetable:getImage(1):getSize()
playerSprite.collisionResponse = gfx.sprite.kCollisionTypeOverlap
playerSprite:setCollideRect(playerImageWidth / 3, playerImageHeight / 2, playerImageWidth / 3, playerImageHeight / 5)
playerSprite:moveTo(playerStartX, playerStartY)
playerSprite:add()

local function resetExplosion()
    explosionAnimation = nil
end

local function startExplosion(x, y)
    explosionX = x
    explosionY = y
    explosionAnimation = gfx.animation.loop.new(explosionFrameDelay, explosionImagetable, false)
end

local function updateExplosion()
    if explosionAnimation == nil or explosionAnimation:isValid() == false then
        return
    end

    explosionAnimation:draw(explosionX - explosionImageWidth / 2, explosionY - explosionImageHeight / 2)
end

-- Particle emitter offsets for each sprite direction (indexed by playerSpriteIndexFromAngle)
-- Each entry is {offsetX, offsetY} relative to boat center
local playerParticleEmitterOffsets = {
    {x = 0, y = 25},    -- 1 frame
    {x = -5, y = 26},   -- 2 frame
    {x = -9, y = 26},   -- 3 frame
    {x = -13, y = 26},  -- 4 frame
    {x = -17, y = 26},  -- 5 frame
    {x = -19, y = 24},  -- 6 frame
    {x = -21, y = 24},  -- 7 frame
    {x = -24, y = 23},  -- 8 frame
    {x = -24, y = 22},  -- 9 frame
    {x = -26, y = 20},  -- 10 frame
    {x = -28, y = 17},  -- 11 frame
    {x = -29, y = 14},  -- 12 frame
    {x = -30, y = 11},  -- 13 frame
    {x = -31, y = 8},   -- 14 frame
    {x = -30, y = 3},   -- 15 frame
    {x = -29, y = -1},  -- 16 frame
    {x = -27, y = -5},  -- 17 frame
    {x = -25, y = -7},  -- 18 frame
    {x = -23, y = -7},  -- 19 frame
    {x = -22, y = -9},  -- 20 frame
    {x = -19, y = -10}, -- 21 frame
    {x = -16, y = -11}, -- 22 frame
    {x = -11, y = -14}, -- 23 frame
    {x = -6, y = -16},  -- 24 frame
    {x = -2, y = -15},  -- 25 frame
    {x = 3, y = -15},   -- 26 frame
    {x = 7, y = -15},   -- 27 frame
    {x = 10, y = -14},  -- 28 frame
    {x = 13, y = -13},  -- 29 frame
    {x = 15, y = -12},  -- 30 frame
    {x = 17, y = -8},   -- 31 frame
    {x = 22, y = -6},   -- 32 frame
    {x = 24, y = -5},   -- 33 frame
    {x = 26, y = -1},   -- 34 frame
    {x = 28, y = 3},    -- 35 frame
    {x = 29, y = 6},    -- 36 frame
    {x = 29, y = 9},    -- 37 frame
    {x = 28, y = 13},   -- 38 frame
    {x = 27, y = 16},   -- 39 frame
    {x = 24, y = 19},   -- 40 frame
    {x = 22, y = 21},   -- 41 frame
    {x = 21, y = 23},   -- 42 frame
    {x = 19, y = 24},   -- 43 frame
    {x = 17, y = 25},   -- 44 frame
    {x = 15, y = 26},   -- 45 frame
    {x = 12, y = 28},   -- 46 frame
    {x = 8, y = 29},    -- 47 frame
    {x = 4, y = 30},    -- 48 frame
}

local wakeLinePoolSize = 28
local wakeLinePool = {}
local wakeLineCursor = 1
local wakeLineSpawnCounter = 0

for i = 1, wakeLinePoolSize do
    wakeLinePool[i] = { active = false }
end

local function clearWakeLines()
    for i = 1, wakeLinePoolSize do
        wakeLinePool[i].active = false
    end
end

local function spawnWakeLine(engineX, engineY, wakeAngle, speedMultiplier)
    local line = wakeLinePool[wakeLineCursor]

    wakeLineCursor += 1
    if wakeLineCursor > wakeLinePoolSize then
        wakeLineCursor = 1
    end

    local angle = wakeAngle + math.random(-12, 12)
    local perpendicularAngle = angle + 90
    local sideOffset = math.random(-3, 3)
    local speed = math.random(12, 20) / 10 * speedMultiplier

    line.active = true
    line.x = engineX + math.sin(math.rad(perpendicularAngle)) * sideOffset
    line.y = engineY - math.cos(math.rad(perpendicularAngle)) * sideOffset
    line.dx = math.sin(math.rad(angle))
    line.dy = -math.cos(math.rad(angle))
    line.speed = speed
    line.length = math.random(8, 15)
    line.age = 0
    line.lifetime = math.random(10, 16)
    line.width = math.random(1, 2)
end

local function updateWakeLines(currentVelocityAngle, playerSpriteIndexFromAngle)
    for i = 1, wakeLinePoolSize do
        local line = wakeLinePool[i]

        if line.active == true then
            local lifeProgress = line.age / line.lifetime

            if lifeProgress >= 1 then
                line.active = false
            else
                line.x += line.dx * line.speed + interpolatedWaterVelocity
                line.y += line.dy * line.speed
                line.age += 1
            end
        end
    end

    local emitterOffset = playerParticleEmitterOffsets[playerSpriteIndexFromAngle]
    local engineX = playerX + emitterOffset.x
    local engineY = playerY + emitterOffset.y
    local wakeAngle = math.normalizeAngle(currentVelocityAngle + 180)

    if playerSpeedMode == 2 then
        spawnWakeLine(engineX, engineY, wakeAngle, 1.6)
        spawnWakeLine(engineX, engineY, wakeAngle, 1.6)
    elseif playerSpeedMode == 1 then
        wakeLineSpawnCounter += 1

        if wakeLineSpawnCounter >= 2 then
            spawnWakeLine(engineX, engineY, wakeAngle, 1)
            wakeLineSpawnCounter = 0
        end
    end
end

local function drawWakeLines()
    local previousLineWidth = gfx.getLineWidth()
    local previousColor = gfx.getColor()

    gfx.setColor(gfx.kColorBlack)

    for i = 1, wakeLinePoolSize do
        local line = wakeLinePool[i]

        if line.active == true then
            local lifeProgress = line.age / line.lifetime
            local lineLength = line.length * (1 - lifeProgress)
            local lineWidth = line.width

            if lifeProgress > 0.55 then
                lineWidth = 1
            end

            gfx.setLineWidth(lineWidth)
            gfx.drawLine(line.x, line.y, line.x + line.dx * lineLength, line.y + line.dy * lineLength)
        end
    end

    gfx.setLineWidth(previousLineWidth)
    gfx.setColor(previousColor)
end

function math.clamp(val, lower, upper)
    return math.max(lower, math.min(upper, val))
end

function math.normalizeAngle(angle)
    return angle % 360
end

function playdate.crankUndocked()
    if BoatGameState == GameState.ALIVE then
        velocityIncreaseTimer:start()
    end
end

function playdate.update()
    pd.timer.updateTimers()

    -- Draw crank indicator if crank is docked
    if pd.isCrankDocked() then
        gfx.sprite.update()
        gfx.drawText("Score: " .. playerScore, 300, 10)
        pd.ui.crankIndicator:draw()
        velocityIncreaseTimer:pause()
        return
    end

    if BoatGameState == GameState.CRASHED then
        gfx.sprite.update()
        updateExplosion()
        gfx.drawText("Score: " .. playerScore, 300, 10)
        gfx.drawText("You crashed! Press A to restart.", 10, 10)

        if pd.buttonJustReleased(pd.kButtonA) then
            -- Reset game state
            BoatGameState = GameState.ALIVE

            -- Reset all relevant variables to their initial state
            xVelocity = 0
            yVelocity = 0
            playerX = playerStartX
            playerY = playerStartY
            rockVelocity = 1
            waterVelocity = 1
            interpolatedRockVelocity = rockVelocity
            interpolatedWaterVelocity = waterVelocity
            playerSpeedMode = 1
            playerScore = 0
            playerScoreStep = 10
            scoreTimer:reset(1000)
            velocityIncreaseTimer:reset(5000)
            velocityIncreaseTimer:start()
            playerSprite:setScale(1)
            playerSprite:moveTo(playerX, playerY)
            waterSprites[1]:moveTo(0, 140)
            waterSprites[2]:moveTo(-waterImageWidth, 140)
            clearWakeLines()

            for i = 1, maxRocks do
                rockSprites[i].active = false
                rockSprites[i]:setVisible(false)
            end

            for i = 1, maxRocks do
                resetRockPosition(rockSprites[i])
            end

            resetExplosion()
        end
        elseif BoatGameState == GameState.ALIVE then
        interpolatedWaterVelocity +=
            (waterVelocity - interpolatedWaterVelocity) * worldVelocityInterpolationSpeed
        interpolatedRockVelocity +=
            (rockVelocity - interpolatedRockVelocity) * worldVelocityInterpolationSpeed

        for i = 1, 2 do
            waterSprites[i]:moveBy(interpolatedWaterVelocity, 0)
        end

        for i = 1, 2 do
            local waterSprite = waterSprites[i]
            if waterSprite.x - waterImageWidth / 2 >= 400 then
                local otherWaterSprite = waterSprites[(i % 2) + 1]
                waterSprite:moveTo(otherWaterSprite.x - waterImageWidth, 140)
            end
        end

        for i = 1, maxRocks do
            local rock = rockSprites[i]

            if rock.active then
                rock:moveBy(interpolatedRockVelocity, 0)
            end
        end

        for i = 1, maxRocks do
            local rock = rockSprites[i]

            if rock.active and rock.x - rock.imageWidth / 2 > 400 then
                rock.active = false
                rock:setVisible(false)
            end
        end

        for i = 1, maxRocks do
            local rock = rockSprites[i]

            if rock.active == false then
                resetRockPosition(rock)
            end
        end

        -- Update player position before moving the emitter so particles emit from the boat engine end
        if pd.buttonJustPressed(pd.kButtonB) and playerSpeedMode == 1 then
            playerSpeedMode = 2
        elseif pd.buttonJustReleased(pd.kButtonB) then
            playerSpeedMode = 1
        elseif pd.buttonJustReleased(pd.kButtonA) then
            -- TODO Think about interesting ability on this button
        end

        -- Calculate velocity from crank angle 
        local crankPosition = pd.getCrankPosition()
        local crankPositionForVelocity = crankPosition - 90

        local playerVelocityMultiplier = 1

        if playerSpeedMode == 1 then
            playerVelocityMultiplier = 1
        elseif playerSpeedMode == 2 then
            playerVelocityMultiplier = 2.25
        end

        -- Calculate target velocities based on crank position
        targetXVelocity = math.cos(math.rad(crankPositionForVelocity)) * playerVelocity * playerVelocityMultiplier
        targetYVelocity = math.sin(math.rad(crankPositionForVelocity)) * playerVelocity * playerVelocityMultiplier

        -- Interpolate velocities toward target for smooth inertia
        xVelocity = xVelocity + (targetXVelocity - xVelocity) * velocityInterpolationSpeed
        yVelocity = yVelocity + (targetYVelocity - yVelocity) * velocityInterpolationSpeed

        -- Calculate sprite index from interpolated velocity direction
        local currentVelocityAngle = math.deg(math.atan2(yVelocity, xVelocity)) + 90
        currentVelocityAngle = math.normalizeAngle(currentVelocityAngle)

        local playerSpriteIndexFromAngle = math.clamp(math.ceil(currentVelocityAngle / 7.5), 1, playerImagetableSize)
        playerSprite:setImage(playerImagetable:getImage(playerSpriteIndexFromAngle))

        -- Update position with velocity and handle collisions
        playerX = playerX + xVelocity + waterStreamVelocity
        playerY = playerY + yVelocity

        local actualX, actualY, collisions, length = playerSprite:moveWithCollisions(playerX, playerY)

        -- Update tracked position to actual position after collision
        playerX = actualX
        playerY = actualY
        playerX = math.clamp(playerX, playerImageWidth / 2, 400 - playerImageWidth / 3)
        playerY = math.clamp(playerY, playerImageHeight / 2, 240 - playerImageHeight / 3)
        playerSprite:moveTo(playerX, playerY)

        updateWakeLines(currentVelocityAngle, playerSpriteIndexFromAngle)
        gfx.sprite.update()
        drawWakeLines()
        gfx.drawText("Score: " .. playerScore, 300, 10)
        gfx.drawText("Boat speed mode: " .. playerSpeedMode, 10, 10)

        -- Pixel-perfect collision check: iterate collisions and use sprite:alphaCollision
        if length > 0 then
            local didAlphaCollision = false

            for i = 1, length do
                local other = collisions[i].other

                if other then
                    if playerSprite:alphaCollision(other) then
                        didAlphaCollision = true
                        break
                    end
                end
            end

            if didAlphaCollision then
                BoatGameState = GameState.CRASHED
                velocityIncreaseTimer:pause()
                playerSprite:setScale(0)
                clearWakeLines()
                startExplosion(playerX, playerY)
            end
        end
    end
end
