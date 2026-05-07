import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank"
import "CoreLibs/animation"

-- Localizing commonly used globals
local pd <const> = playdate
local gfx <const> = playdate.graphics

--local playerImagetable = gfx.imagetable.new("images/Boat")
--local playerAnimation = gfx.animation.loop.new(50, playerImagetable, true)

-- Player variables
local playerVelocity = 0
local playerX, playerY = 200, 120
local playerPaddleRotationPower = 50
local playerPaddle = "both"

-- Player image
local playerImage = gfx.image.new("images/Boat")
local playerSprite = gfx.sprite.new(playerImage)
local playerImageWidth, playerImageHeight = playerImage:getSize()
playerSprite:setCollideRect(0, 0, playerImageWidth, playerImageHeight)
playerSprite:moveTo(playerX, playerY)
playerSprite:add()

-- Rotation variables
local targetRotation = playerSprite:getRotation()  -- Desired rotation angle
local defaultRotationInterpolationSpeed = 0.1  -- Initial interpolation rate (adjust for smoothness)
local rotationInterpolationSpeed = 0.1  -- Initial interpolation rate (adjust for smoothness)
local attenuationFactor = 0.98  -- How much speed decays each frame (0.95-0.99 for subtle decay)
local minInterpolationSpeed = 0.01  -- Minimum speed to prevent full stop

-- Helper function to normalize an angle to 0-360 degrees
local function normalizeAngle(angle)
    return angle % 360
end

-- Helper function to get the shortest angle difference (handles wrapping)
local function shortestAngleDifference(from, to)
    local diff = normalizeAngle(to - from)
    if diff > 180 then
        diff = diff - 360
    end
    return diff
end

function playdate.update()
    -- Update sprites
    gfx.sprite.update()
    --playerAnimation:draw(50, 50)

    -- Draw crank indicator if crank is docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    else
        if pd.buttonJustReleased(pd.kButtonLeft) then
            playerPaddle = "left"
        elseif pd.buttonJustReleased(pd.kButtonRight) then
            playerPaddle = "right"
        elseif pd.buttonJustReleased(pd.kButtonDown) then
            playerPaddle = "both"
        end

        -- Calculate velocity from crank angle 
        local crankPosition = pd.getCrankPosition() - 90
        local crankChange, crankAcceleratedChange = pd.getCrankChange()
        local crankTicks = pd.getCrankTicks(1)
        local playerRotation = playerSprite:getRotation()
        local playerRotationForVelocity = playerRotation - 90
        local xVelocity = 0
        local yVelocity = 0
        print("playerRotation: " .. playerRotation)
        
        -- Move player
        if crankTicks == 1 then
            if playerPaddle == "left" then
                targetRotation = targetRotation - playerPaddleRotationPower
                rotationInterpolationSpeed = defaultRotationInterpolationSpeed  -- Reset speed on input
            elseif playerPaddle == "right" then
                targetRotation = targetRotation + playerPaddleRotationPower
                rotationInterpolationSpeed = defaultRotationInterpolationSpeed
            elseif playerPaddle == "both" then
                playerVelocity += 1
            end
        elseif crankTicks == -1 then
            if playerPaddle == "left" then
                targetRotation = targetRotation + playerPaddleRotationPower
                rotationInterpolationSpeed = defaultRotationInterpolationSpeed
            elseif playerPaddle == "right" then
                targetRotation = targetRotation - playerPaddleRotationPower
                rotationInterpolationSpeed = defaultRotationInterpolationSpeed
            elseif playerPaddle == "both" then
                playerVelocity -= 1
            end
        end

        -- Interpolate player position from velocity
        xVelocity = math.cos(math.rad(playerRotationForVelocity)) * playerVelocity
        yVelocity = math.sin(math.rad(playerRotationForVelocity)) * playerVelocity
        playerSprite:moveBy(xVelocity, yVelocity)
        playerVelocity -= 0.01

        -- Normalize targetRotation after setting it
        targetRotation = normalizeAngle(targetRotation)

        -- Interpolate playerRotation toward targetRotation using shortest path
        local rotationDifference = shortestAngleDifference(playerRotation, targetRotation)

        if math.abs(rotationDifference) > 0.5 then
            playerRotation = normalizeAngle(playerRotation + (rotationDifference * rotationInterpolationSpeed))
            playerSprite:setRotation(playerRotation)
        end

        -- Attenuate the interpolation speed over time
        rotationInterpolationSpeed = math.max(rotationInterpolationSpeed * attenuationFactor, minInterpolationSpeed)

        if (playerVelocity < 0) then
            playerVelocity = 0
        end
    end
end
