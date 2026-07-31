class("ShieldCollectable").extends(Collectable)

function ShieldCollectable:init(image, onCollected)
    ShieldCollectable.super.init(self, image, "shield", onCollected)
end
