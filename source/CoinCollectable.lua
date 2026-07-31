local gfx <const> = playdate.graphics

class("CoinCollectable").extends(Collectable)

function CoinCollectable:init(imagetable, onCollected)
    CoinCollectable.super.init(self, imagetable:getImage(1), "coin", onCollected)

    self.imagetable = imagetable
    self.animationFrame = 1
    self.animationTick = 0
    self.animationFrameDelay = 4
end

function CoinCollectable:update()
    CoinCollectable.super.update(self)

    if self.active == false or self.isCollecting then
        return
    end

    self.animationTick += 1

    if self.animationTick >= self.animationFrameDelay then
        self.animationTick = 0
        self.animationFrame += 1

        if self.animationFrame > self.imagetable:getLength() then
            self.animationFrame = 1
        end

        self:setImage(self.imagetable:getImage(self.animationFrame))
    end
end
