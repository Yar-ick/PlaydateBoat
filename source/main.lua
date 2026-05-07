import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank"
import "CoreLibs/animation"

-- Localizing commonly used globals
local pd <const> = playdate
local gfx <const> = playdate.graphics

local playerImagetable = gfx.imagetable.new("images/Boat")
local playerImagetableSize = playerImagetable:getLength()

-- Player variables
local playerVelocity = 2
local playerSpeedMode = 1  -- 1: Normal speed, 2: Fast speed, 0: No speed
local playerX, playerY = 200, 120

-- Velocity inertia variables
local xVelocity = 0
local yVelocity = 0
local targetXVelocity = 0
local targetYVelocity = 0
local velocityInterpolationSpeed = 0.1  -- Smoothness of velocity transitions (0.0-1.0)

-- Player image
local playerSprite = gfx.sprite.new(playerImagetable:getImage(1))
local playerImageWidth, playerImageHeight = playerImagetable:getImage(1):getSize()
playerSprite:setCollideRect(0, 0, playerImageWidth, playerImageHeight)
playerSprite:moveTo(playerX, playerY)
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
    gfx.drawText("Boat speed mode: " .. playerSpeedMode, 10, 10)

    -- Draw crank indicator if crank is docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
        return
    else
        if pd.buttonJustReleased(pd.kButtonDown) then
            playerSpeedMode = math.clamp(playerSpeedMode - 1, 0, 2)
        elseif pd.buttonJustReleased(pd.kButtonUp) then
            playerSpeedMode = math.clamp(playerSpeedMode + 1, 0, 2)
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

        -- Apply interpolated velocity to sprite
        playerSprite:moveBy(xVelocity, yVelocity)
    end
end
