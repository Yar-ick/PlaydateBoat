local gfx <const> = playdate.graphics
local COLLECTION_SCALE_STEP <const> = 0.14
local IDLE_PULSE_MAX_SCALE <const> = 1.12
local IDLE_PULSE_PHASE_STEP <const> = 0.12

class("Collectable").extends(gfx.sprite)

function Collectable:init(image, collectableType, onCollected, idlePulseEnabled)
    Collectable.super.init(self)
    self:setImage(image)

    self.objectType = "collectable"
    self.collectableType = collectableType
    self.onCollected = onCollected
    self.imageWidth, self.imageHeight = image:getSize()
    self.active = false
    self.isCollecting = false
    self.collectionScale = 1
    self.idlePulseEnabled = idlePulseEnabled == true
    self.idlePulsePhase = 0
    self.visualScale = 1

    -- Keep full-image collision metadata available for alphaCollision(). The main
    -- loop does not use this rectangle as the final collection decision.
    self.collisionResponse = gfx.sprite.kCollisionTypeOverlap
    self:setCollideRect(0, 0, self.imageWidth, self.imageHeight)
    self:setVisible(false)
end

function Collectable:spawnAt(x, y)
    self.collectionScale = 1
    self.isCollecting = false
    self.idlePulsePhase = 0
    self.visualScale = 1
    self:setScale(1)
    self:moveTo(x, y)
    self.active = true
    self:setVisible(true)
    self:add()
end

function Collectable:despawn()
    self.active = false
    self.isCollecting = false
    self.collectionScale = 1
    self.idlePulsePhase = 0
    self.visualScale = 1
    self:setScale(1)
    self:setVisible(false)
    self:remove()
end

function Collectable:collect()
    if self.active == false or self.isCollecting then
        return
    end

    self.isCollecting = true
    self.collectionScale = self.visualScale

    if self.onCollected ~= nil then
        self.onCollected()
    end
end

function Collectable:update()
    if self.active == false then
        return
    end

    if self.isCollecting then
        self.collectionScale = math.max(0, self.collectionScale - COLLECTION_SCALE_STEP)
        self.visualScale = self.collectionScale
        self:setScale(self.collectionScale)

        if self.collectionScale == 0 then
            self:despawn()
        end
    elseif self.idlePulseEnabled then
        self.idlePulsePhase = (self.idlePulsePhase + IDLE_PULSE_PHASE_STEP)
            % (math.pi * 2)
        local pulseProgress = (1 - math.cos(self.idlePulsePhase)) * 0.5
        self.visualScale = 1 + (IDLE_PULSE_MAX_SCALE - 1) * pulseProgress
        self:setScale(self.visualScale)
    end
end
