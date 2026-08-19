InteractiveSpawn = {}

local function objectsOverlap(x, y, width, height, otherObject, padding)
    local horizontalDistance = math.abs(x - otherObject.x)
    local verticalDistance = math.abs(y - otherObject.y)
    local minimumHorizontalDistance = (width + otherObject.imageWidth) / 2 + padding
    local minimumVerticalDistance = (height + otherObject.imageHeight) / 2 + padding

    return horizontalDistance < minimumHorizontalDistance
        and verticalDistance < minimumVerticalDistance
end

function InteractiveSpawn.findPosition(
    objectGroups,
    excludedObject,
    width,
    height,
    minimumX,
    maximumX,
    minimumY,
    maximumY,
    padding,
    maximumAttempts
)
    for _ = 1, maximumAttempts do
        local x = math.random(math.ceil(minimumX), math.floor(maximumX))
        local y = math.random(math.ceil(minimumY), math.floor(maximumY))
        local overlaps = false

        for groupIndex = 1, #objectGroups do
            local objects = objectGroups[groupIndex]

            for objectIndex = 1, #objects do
                local otherObject = objects[objectIndex]

                if otherObject ~= excludedObject
                    and otherObject.active == true
                    and objectsOverlap(x, y, width, height, otherObject, padding)
                then
                    overlaps = true
                    break
                end
            end

            if overlaps then
                break
            end
        end

        if overlaps == false then
            return x, y
        end
    end

    return nil, nil
end
