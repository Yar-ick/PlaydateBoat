local gfx <const> = playdate.graphics
local COLLECTION_SCALE_STEP <const> = 0.14

class("Collectable").extends(gfx.sprite)

function Collectable:init(image, collectableType, onCollected)
    Collectable.super.init(self)
    self:setImage(image)

    self.objectType = "collectable"
    self.collectableType = collectableType
    self.onCollected = onCollected
    self.imageWidth, self.imageHeight = image:getSize()
    self.active = false
    self.isCollecting = false
    self.collectionScale = 1

    -- Keep full-image collision metadata available for alphaCollision(). The main
    -- loop does not use this rectangle as the final collection decision.
    self.collisionResponse = gfx.sprite.kCollisionTypeOverlap
    self:setCollideRect(0, 0, self.imageWidth, self.imageHeight)
    self:setVisible(false)
end

function Collectable:spawnAt(x, y)
    self.collectionScale = 1
    self.isCollecting = false
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
    self:setScale(1)
    self:setVisible(false)
    self:remove()
end

function Collectable:collect()
    if self.active == false or self.isCollecting then
        return
    end

    self.isCollecting = true

    if self.onCollected ~= nil then
        self.onCollected()
    end
end

function Collectable:update()
    if self.active == false or self.isCollecting == false then
        return
    end

    self.collectionScale = math.max(0, self.collectionScale - COLLECTION_SCALE_STEP)
    self:setScale(self.collectionScale)

    if self.collectionScale == 0 then
        self:despawn()
    end
end
