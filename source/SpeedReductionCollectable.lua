class("SpeedReductionCollectable").extends(Collectable)

function SpeedReductionCollectable:init(image, onCollected)
    SpeedReductionCollectable.super.init(self, image, "speedReduction", onCollected)
end
