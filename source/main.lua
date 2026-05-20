import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank"
import "CoreLibs/animation"

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

-- Player variables
local playerScore = 0
local playerVelocity = 2
local playerSpeedMode = 1  -- 0: No speed, 1: Normal speed, 2: Fast speed
local playerStartX, playerStartY = 350, 150
local playerX, playerY = playerStartX, playerStartY

local scoreTimer = pd.timer.new(1000, function()
    if BoatGameState == GameState.ALIVE and pd.isCrankDocked() == false then
        playerScore += 10
    end
end)
scoreTimer.repeats = true

-- Velocity inertia variables
local xVelocity = 0
local yVelocity = 0
local targetXVelocity = 0
local targetYVelocity = 0
local velocityInterpolationSpeed = 0.1  -- Smoothness of velocity transitions (0.0-1.0)

-- Water stream velocity
local waterStreamVelocity = 1  -- X+ direction velocity from water stream

local waterVelocity = 1
local waterImagetable = gfx.imagetable.new("images/Water")
local waterImage = gfx.image.new("images/WaterBackground")
local waterSprite = gfx.sprite.new(waterImage)
waterSprite:moveTo(0, 140)
waterSprite:add()

local rockVelocity = 1
local rockImage1 = gfx.image.new("images/Rock1")
local rockImage2 = gfx.image.new("images/Rock2")
local rockImage3 = gfx.image.new("images/Rock3")
local rockImages = { rockImage1, rockImage2, rockImage3 }
local rockImageWidth, rockImageHeight = rockImage1:getSize()
local maxRocks = 5
local rockSprites = {}

for i = 1, maxRocks do
    local rock = gfx.sprite.new(rockImages[math.random(#rockImages)])
    rock:setCollideRect(0, 0, rockImageWidth, rockImageHeight)
    rock.collisionResponse = gfx.sprite.kCollisionTypeOverlap
    rock:moveTo(-20, -100)
    rock:setVisible(false)
    rock.active = false
    rock:add()
    rockSprites[i] = rock
end

local function spawnRockGroup()
    local groupSize = math.random(2, maxRocks)

    for i = 1, maxRocks do
        if i <= groupSize then
            rockSprites[i].active = true
            rockSprites[i]:setVisible(true)
            rockSprites[i]:moveTo(-20 - ((i - 1) * 40), math.random(50, 190))
        else
            rockSprites[i].active = false
            rockSprites[i]:setVisible(false)
            rockSprites[i]:moveTo(-20, -100)
        end
    end
end

local function allRocksOffscreen()
    for i = 1, maxRocks do
        if rockSprites[i].active and rockSprites[i].x <= 410 then
            return false
        end
    end

    return true
end

spawnRockGroup()

-- Player image
local playerSprite = gfx.sprite.new(playerImagetable:getImage(1))
local playerImageWidth, playerImageHeight = playerImagetable:getImage(1):getSize()
playerSprite.collisionResponse = gfx.sprite.kCollisionTypeOverlap
playerSprite:setCollideRect(0, 10, playerImageWidth, playerImageHeight - 10)
playerSprite:moveTo(playerStartX, playerStartY)
playerSprite:add()

function math.clamp(val, lower, upper)
    return math.max(lower, math.min(upper, val))
end

function math.normalizeAngle(angle)
    return angle % 360
end

function playdate.update()
    -- Update sprites
    gfx.sprite.update()
    pd.timer.updateTimers()

    gfx.drawText("Score: " .. playerScore, 300, 10)

    -- Draw crank indicator if crank is docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
        return
    end

    if BoatGameState == GameState.CRASHED then
        gfx.drawText("You crashed! Press A to restart.", 10, 10)

        if pd.buttonJustReleased(pd.kButtonA) then
            -- Reset game state
            BoatGameState = GameState.ALIVE

            xVelocity = 0
            yVelocity = 0
            playerX = playerStartX
            playerY = playerStartY
            rockVelocity = 1
            waterVelocity = 1
            playerSpeedMode = 1
            playerScore = 0
            scoreTimer:reset(1000)

            for i = 1, maxRocks do
                rockSprites[i].active = false
                rockSprites[i]:setVisible(false)
                rockSprites[i]:moveTo(-20, -100)
            end
        end
    elseif BoatGameState == GameState.ALIVE then
        gfx.drawText("Boat speed mode: " .. playerSpeedMode, 10, 10)

        waterSprite:moveBy(waterVelocity, 0)

        if (waterSprite.x >= 400) then
            waterSprite:moveTo(0, 140)
        end

        for i = 1, maxRocks do
            if rockSprites[i].active then
                rockSprites[i]:moveBy(rockVelocity, 0)
            end
        end

        if allRocksOffscreen() then
            spawnRockGroup()
            rockVelocity += 0.5
            waterVelocity += 0.5
        end

        if pd.buttonJustPressed(pd.kButtonB) and playerSpeedMode == 1 then
            playerSpeedMode = 2
        elseif pd.buttonJustReleased(pd.kButtonB) then
            playerSpeedMode = 1
        elseif pd.buttonJustReleased(pd.kButtonA) then
            playerSpeedMode = 0
        end

        -- Calculate velocity from crank angle 
        local crankPosition = pd.getCrankPosition()
        local crankPositionForVelocity = crankPosition - 90

        -- Calculate target velocities based on crank position
        targetXVelocity = math.cos(math.rad(crankPositionForVelocity)) * playerVelocity * playerSpeedMode
        targetYVelocity = math.sin(math.rad(crankPositionForVelocity)) * playerVelocity * playerSpeedMode

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
            end
        end
    end
end
