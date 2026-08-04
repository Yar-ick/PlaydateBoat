class("ShrinkCollectable").extends(Collectable)

function ShrinkCollectable:init(image, onCollected)
    ShrinkCollectable.super.init(self, image, "shrink", onCollected, true)
end
