class("ImpulseCollectable").extends(Collectable)

function ImpulseCollectable:init(image, onCollected)
    ImpulseCollectable.super.init(self, image, "impulse", onCollected, true)
end
