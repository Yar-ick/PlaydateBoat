local pdg <const> = playdate.graphics

local wakeLayerSprite = nil

class("WakeLayerSprite").extends(pdg.sprite)

function WakeLayerSprite:init(drawCallback, zIndex)
    WakeLayerSprite.super.init(self)
    self.drawCallback = drawCallback
    self:setSize(400, 240)
    self:setCenter(0, 0)
    self:moveTo(0, 0)
    self:setZIndex(zIndex)
end

function WakeLayerSprite:draw()
    self.drawCallback()
end

WakeLayer = {}

function WakeLayer.initialize(drawCallback, zIndex)
    if wakeLayerSprite ~= nil then
        wakeLayerSprite:remove()
    end

    wakeLayerSprite = WakeLayerSprite(drawCallback, zIndex)
    wakeLayerSprite:add()
end

function WakeLayer.markDirty()
    if wakeLayerSprite ~= nil then
        wakeLayerSprite:markDirty()
    end
end
