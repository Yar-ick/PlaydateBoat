class("GrowthCollectable").extends(Collectable)

function GrowthCollectable:init(image, onCollected)
    GrowthCollectable.super.init(self, image, "growth", onCollected, true)
end
