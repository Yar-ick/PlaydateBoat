local pdg <const> = playdate.graphics

local images = {
    abilityFrame = pdg.image.new("images/AbilityFrame"),
    selector = pdg.image.new("images/UpgradeAbilitySelector"),
    aButton = pdg.image.new("images/A_Button"),
    bButton = pdg.image.new("images/B_Button"),
    coin = pdg.imagetable.new("images/Coin"),
    dash = pdg.image.new("images/Dash"),
    horn = pdg.image.new("images/Horn"),
    shield = pdg.image.new("images/Shield"),
    shrink = pdg.image.new("images/Srink"),
    growth = pdg.image.new("images/Growth"),
    speedReduction = pdg.image.new("images/SpeedReductionNoFrame")
}

local regularAbilities = {
        {
            type = "dash",
            title = "DASH",
            description = "Burst forward with inertia.",
            upgradeDescription = "Upgrade: reduce cooldown.",
            image = images.dash
        },
        {
            type = "shield",
            title = "SHIELD",
            description = "Break rocks on collision.",
            upgradeDescription = "Upgrade: destroy more rocks.",
            image = images.shield
        },
        {
            type = "shrink",
            title = "SHRINK",
            description = "Shrink the boat and hitbox.",
            upgradeDescription = "Upgrade: extend duration.",
            image = images.shrink
        },
        {
            type = "speedReduction",
            title = "SLOWDOWN",
            description = "Slow rocks and water.",
            upgradeDescription = "Upgrade: stronger slowdown.",
            image = images.speedReduction,
            imageYOffset = 1
        }
    }

local otherSideAbilities = {
    {
        type = "horn",
        title = "HORN",
        description = "Warn small boats to move away.",
        upgradeDescription = "Upgrade: + range, - cooldown.",
        image = images.horn
    },
    {
        type = "shield",
        title = "SHIELD",
        description = "Survive a small boat collision.",
        upgradeDescription = "Upgrade: store more protection.",
        image = images.shield
    },
    {
        type = "growth",
        title = "IMPULSE",
        description = "Break rocks and push small boats.",
        upgradeDescription = "Upgrade: increase radius.",
        image = images.growth,
        imageYOffset = 1
    },
    {
        type = "speedReduction",
        title = "SLOWDOWN",
        description = "Slow rocks and water.",
        upgradeDescription = "Upgrade: stronger slowdown.",
        image = images.speedReduction,
        imageYOffset = 1
    }
}

UpgradeMenuUI = {
    REGULAR_ABILITIES = regularAbilities,
    OTHER_SIDE_ABILITIES = otherSideAbilities,
    coinFrame = 1,
    coinElapsedMilliseconds = 0,
    upgradeBlinkElapsedMilliseconds = 0,
    upgradeBlinkOn = true,
    upgradeEffect = {
        active = false,
        elapsedMilliseconds = 0,
        nodeIndex = 1,
        contractionDurationMilliseconds = 0,
        soundPending = false
    }
}

function UpgradeMenuUI.getAbilities(isOtherSide)
    return isOtherSide and otherSideAbilities or regularAbilities
end

local upgradeNodeCenters <const> = { 125, 205, 285, 365 }

local function clamp01(value)
    return math.max(0, math.min(1, value))
end

local function smoothstep(value)
    value = clamp01(value)
    return value * value * (3 - 2 * value)
end

local function drawFramedAbility(abilityImage, frameX, frameY, imageYOffset)
    local frameWidth, frameHeight = images.abilityFrame:getSize()
    local imageWidth, imageHeight = abilityImage:getSize()
    imageYOffset = imageYOffset or 0

    images.abilityFrame:draw(frameX, frameY)
    abilityImage:draw(
        math.floor(frameX + (frameWidth - imageWidth) / 2),
        math.floor(frameY + (frameHeight - imageHeight) / 2) + imageYOffset
    )
end

local function drawPanel(x, y, width, height)
    pdg.setColor(pdg.kColorBlack)
    pdg.fillRect(x + 3, y + 3, width, height)
    pdg.setColor(pdg.kColorWhite)
    pdg.fillRect(x, y, width, height)
    pdg.setColor(pdg.kColorBlack)
    pdg.drawRect(x, y, width, height)
    pdg.drawRect(x + 2, y + 2, width - 4, height - 4)

    -- Small cut-corner blocks keep the panel language pixel-art rather than
    -- looking like an anti-aliased modern UI card.
    pdg.fillRect(x, y, 5, 2)
    pdg.fillRect(x, y, 2, 5)
    pdg.fillRect(x + width - 5, y, 5, 2)
    pdg.fillRect(x + width - 2, y, 2, 5)
    pdg.fillRect(x, y + height - 2, 5, 2)
    pdg.fillRect(x, y + height - 5, 2, 5)
    pdg.fillRect(x + width - 5, y + height - 2, 5, 2)
    pdg.fillRect(x + width - 2, y + height - 5, 2, 5)
end

local function drawWorkshopTexture(yOffset)
    pdg.setColor(pdg.kColorBlack)

    -- Sparse one-pixel plank marks stay in the gutters behind the solid panels.
    -- The alternating phase avoids a rigid checkerboard while remaining 1-bit.
    for y = yOffset + 11, yOffset + 229, 7 do
        local phase = math.floor((y - yOffset) / 7) % 2 * 5

        for x = 11 + phase, 389, 13 do
            pdg.fillRect(x, y, 4, 1)
        end
    end
end

local function drawScrew(x, y)
    pdg.setColor(pdg.kColorWhite)
    pdg.fillCircleAtPoint(x, y, 3)
    pdg.setColor(pdg.kColorBlack)
    pdg.drawCircleAtPoint(x, y, 3)
    pdg.drawLine(x - 1, y - 1, x + 1, y + 1)
end

local function drawWorkshopBackground(yOffset)
    pdg.setColor(pdg.kColorWhite)
    pdg.fillRect(0, yOffset, 400, 240)
    drawWorkshopTexture(yOffset)
    pdg.setColor(pdg.kColorBlack)
    pdg.drawRect(3, yOffset + 3, 394, 234)
    pdg.drawRect(7, yOffset + 7, 386, 226)

    drawPanel(14, yOffset + 16, 76, 176)
    drawPanel(100, yOffset + 16, 286, 176)
    drawPanel(14, yOffset + 198, 372, 33)

    -- Crisp workshop separators and rivets. Every primitive is strictly 1-bit.
    pdg.drawLine(103, yOffset + 65, 383, yOffset + 65)
    pdg.drawLine(103, yOffset + 110, 383, yOffset + 110)
    pdg.drawLine(103, yOffset + 157, 383, yOffset + 157)
    -- The coin counter is engraved into the header instead of floating above it.
    pdg.drawLine(304, yOffset + 19, 304, yOffset + 62)
    -- A small empty tool rail gives the header workshop character without
    -- putting texture behind any ability title.
    pdg.drawLine(244, yOffset + 27, 294, yOffset + 27)
    pdg.drawLine(244, yOffset + 53, 294, yOffset + 53)
    for x = 248, 292, 11 do
        pdg.fillRect(x, yOffset + 25, 2, 5)
        pdg.fillRect(x, yOffset + 51, 2, 5)
    end
    drawScrew(22, yOffset + 24)
    drawScrew(82, yOffset + 184)
    drawScrew(108, yOffset + 24)
    drawScrew(378, yOffset + 184)
    drawScrew(378, yOffset + 223)
end

local function drawButtonPrompt(buttonImage, label, x, y)
    buttonImage:draw(x, y)
    pdg.drawText(label, x + 30, y + 3)
end

local function drawUpgradeTrack(level, tuning, yOffset)
    local centerY = yOffset + 133
    local effect = UpgradeMenuUI.upgradeEffect

    pdg.setColor(pdg.kColorBlack)

    -- Draw the connected double rail first so the node faces mask its ends.
    for nodeIndex = 1, #upgradeNodeCenters - 1 do
        pdg.drawLine(
            upgradeNodeCenters[nodeIndex],
            centerY - 2,
            upgradeNodeCenters[nodeIndex + 1],
            centerY - 2
        )
        pdg.drawLine(
            upgradeNodeCenters[nodeIndex],
            centerY + 2,
            upgradeNodeCenters[nodeIndex + 1],
            centerY + 2
        )
    end

    for nodeIndex = 1, #upgradeNodeCenters do
        local isCompleted = nodeIndex <= level + 1
        local isNextLevel = level < tuning.MAX_ABILITY_UPGRADE_LEVEL
            and nodeIndex == level + 2
        local isFilled = isCompleted or (isNextLevel and UpgradeMenuUI.upgradeBlinkOn)
        local centerX = upgradeNodeCenters[nodeIndex]
        local contractionRadius = nil

        if effect.active and nodeIndex == effect.nodeIndex then
            isFilled = false

            if effect.elapsedMilliseconds < effect.contractionDurationMilliseconds then
                local contractionProgress = smoothstep(
                    effect.elapsedMilliseconds / effect.contractionDurationMilliseconds
                )
                contractionRadius = math.floor(7 * (1 - contractionProgress) + 0.5)
            end
        end

        pdg.setColor(pdg.kColorBlack)
        pdg.fillCircleAtPoint(centerX, centerY, 13)
        pdg.setColor(pdg.kColorWhite)
        pdg.fillCircleAtPoint(centerX, centerY, 10)
        pdg.setColor(pdg.kColorBlack)
        pdg.drawCircleAtPoint(centerX, centerY, 8)

        if contractionRadius ~= nil and contractionRadius > 0 then
            pdg.fillCircleAtPoint(centerX, centerY, contractionRadius)
        elseif isFilled then
            pdg.fillCircleAtPoint(centerX, centerY, 7)
        end
    end
end

local function drawUpgradeEffect(yOffset, tuning)
    local effect = UpgradeMenuUI.upgradeEffect

    if effect.active == false then
        return
    end

    local centerX = upgradeNodeCenters[effect.nodeIndex]
    local centerY = yOffset + 133
    local animationElapsedMilliseconds = effect.elapsedMilliseconds
        - effect.contractionDurationMilliseconds

    if animationElapsedMilliseconds < 0 then
        return
    end

    local coreProgress = smoothstep(
        animationElapsedMilliseconds / tuning.UPGRADE_EFFECT_CORE_DURATION_MS
    )
    local coreRadius = math.floor(7 * coreProgress + 0.5)

    pdg.setColor(pdg.kColorBlack)

    if coreRadius > 0 then
        pdg.fillCircleAtPoint(centerX, centerY, coreRadius)
    end

    local burstElapsedMilliseconds = animationElapsedMilliseconds
        - tuning.UPGRADE_EFFECT_CORE_DURATION_MS

    if burstElapsedMilliseconds < 0 then
        return
    end

    local particleCount = tuning.UPGRADE_EFFECT_BASE_PARTICLE_COUNT
        + (effect.nodeIndex - 1) * tuning.UPGRADE_EFFECT_PARTICLES_PER_LEVEL
    local particleDistance = tuning.UPGRADE_EFFECT_BASE_PARTICLE_DISTANCE
        + (effect.nodeIndex - 1) * tuning.UPGRADE_EFFECT_PARTICLE_DISTANCE_PER_LEVEL
    local particleMaxRadius = tuning.UPGRADE_EFFECT_BASE_PARTICLE_MAX_RADIUS
        + (effect.nodeIndex - 1) * tuning.UPGRADE_EFFECT_PARTICLE_RADIUS_PER_LEVEL

    for particleIndex = 1, particleCount do
        local particleElapsedMilliseconds = burstElapsedMilliseconds
            - (particleIndex - 1) * tuning.UPGRADE_EFFECT_PARTICLE_STAGGER_MS
        local progress = clamp01(
            particleElapsedMilliseconds / tuning.UPGRADE_EFFECT_BURST_DURATION_MS
        )

        if progress > 0 and progress < 1 then
            local angle = (particleIndex - 1) * math.pi * 2 / particleCount
                + (particleIndex % 2) * 0.12
            local distance = particleDistance * smoothstep(progress)
            local radiusScale = math.sin(progress * math.pi)
            local radius = math.max(
                1,
                math.floor(particleMaxRadius * radiusScale + 0.5)
            )
            local x = math.floor(centerX + math.cos(angle) * distance + 0.5)
            local y = math.floor(centerY + math.sin(angle) * distance + 0.5)

            pdg.fillCircleAtPoint(x, y, radius)
        end
    end
end

function UpgradeMenuUI.playUpgradeEffect(level)
    local effect = UpgradeMenuUI.upgradeEffect
    local shouldContract = UpgradeMenuUI.upgradeBlinkOn

    effect.active = true
    effect.elapsedMilliseconds = 0
    effect.nodeIndex = math.max(
        1,
        math.min(#upgradeNodeCenters, level + 1)
    )
    effect.contractionDurationMilliseconds = shouldContract
        and GameplayTuning.UPGRADE_EFFECT_CONTRACTION_DURATION_MS
        or 0
    effect.soundPending = shouldContract
    return shouldContract
end

function UpgradeMenuUI.update(elapsedMilliseconds)
    local shouldPlayUpgradeSound = false
    UpgradeMenuUI.coinElapsedMilliseconds += elapsedMilliseconds
    UpgradeMenuUI.upgradeBlinkElapsedMilliseconds += elapsedMilliseconds

    if UpgradeMenuUI.coinElapsedMilliseconds >= 100 then
        UpgradeMenuUI.coinElapsedMilliseconds %= 100
        UpgradeMenuUI.coinFrame = UpgradeMenuUI.coinFrame % images.coin:getLength() + 1
    end

    if UpgradeMenuUI.upgradeBlinkElapsedMilliseconds >= GameplayTuning.UPGRADE_LEVEL_BLINK_INTERVAL_MS then
        UpgradeMenuUI.upgradeBlinkElapsedMilliseconds %=
            GameplayTuning.UPGRADE_LEVEL_BLINK_INTERVAL_MS
        UpgradeMenuUI.upgradeBlinkOn = not UpgradeMenuUI.upgradeBlinkOn
    end

    local effect = UpgradeMenuUI.upgradeEffect

    if effect.active then
        effect.elapsedMilliseconds += elapsedMilliseconds

        if effect.soundPending
            and effect.elapsedMilliseconds >= effect.contractionDurationMilliseconds
        then
            effect.soundPending = false
            shouldPlayUpgradeSound = true
        end

        local particleCount = GameplayTuning.UPGRADE_EFFECT_BASE_PARTICLE_COUNT
            + (effect.nodeIndex - 1) * GameplayTuning.UPGRADE_EFFECT_PARTICLES_PER_LEVEL
        local totalDurationMilliseconds = effect.contractionDurationMilliseconds
            + GameplayTuning.UPGRADE_EFFECT_CORE_DURATION_MS
            + GameplayTuning.UPGRADE_EFFECT_BURST_DURATION_MS
            + (particleCount - 1)
                * GameplayTuning.UPGRADE_EFFECT_PARTICLE_STAGGER_MS

        if effect.elapsedMilliseconds >= totalDurationMilliseconds then
            effect.active = false
        end
    end

    return shouldPlayUpgradeSound
end

function UpgradeMenuUI.draw(yOffset, selectionIndex, levels, coins, message, tuning, isOtherSide)
    local abilities = UpgradeMenuUI.getAbilities(isOtherSide)
    local ability = abilities[selectionIndex]
    local level = levels[ability.type]

    local previousColor = pdg.getColor()
    drawWorkshopBackground(yOffset)

    for index = 1, #abilities do
        local selectorAbility = abilities[index]
        local frameX = 36
        local frameY = yOffset + 27 + (index - 1) * 40

        drawFramedAbility(
            selectorAbility.image,
            frameX,
            frameY,
            selectorAbility.imageYOffset
        )

        if index == selectionIndex then
            images.selector:draw(21, frameY + 9)
        end
    end

    drawFramedAbility(ability.image, 112, yOffset + 26, ability.imageYOffset)
    pdg.drawText(ability.title, 152, yOffset + 33)
    pdg.drawText(ability.description, 112, yOffset + 70)

    if level == tuning.LOCKED_ABILITY_LEVEL then
        pdg.drawText("Buy to unlock this ability.", 112, yOffset + 89)
    else
        pdg.drawText(ability.upgradeDescription, 112, yOffset + 89)
    end

    drawUpgradeTrack(level, tuning, yOffset)
    drawUpgradeEffect(yOffset, tuning)

    if level < tuning.MAX_ABILITY_UPGRADE_LEVEL then
        local cost
        local actionLabel

        if level == tuning.LOCKED_ABILITY_LEVEL then
            local purchaseCosts = isOtherSide
                and tuning.OTHER_SIDE_ABILITY_PURCHASE_COSTS
                or tuning.ABILITY_PURCHASE_COSTS
            cost = purchaseCosts[ability.type]
            actionLabel = "Buy"
        else
            local upgradeCosts = isOtherSide
                and tuning.OTHER_SIDE_ABILITY_UPGRADE_COSTS
                or tuning.ABILITY_UPGRADE_COSTS
            cost = upgradeCosts[ability.type][level + 1]
            actionLabel = "Upgrade"
        end

        drawButtonPrompt(images.aButton, actionLabel, 112, yOffset + 163)
        images.coin:getImage(UpgradeMenuUI.coinFrame):draw(225, yOffset + 165)
        pdg.drawText(tostring(cost), 248, yOffset + 167)
    else
        pdg.drawText("Maximum level", 112, yOffset + 167)
    end

    drawButtonPrompt(images.bButton, "Back", 22, yOffset + 202)

    local coinText = string.format("%03d", coins)
    local coinTextWidth = pdg.getTextSize(coinText)
    images.coin:getImage(UpgradeMenuUI.coinFrame):draw(315, yOffset + 30)
    pdg.drawText(coinText, 378 - coinTextWidth - 8, yOffset + 32)

    if message ~= nil then
        pdg.drawTextAligned(message, 264, yOffset + 208, kTextAlignment.center)
    end

    pdg.setColor(previousColor)
end
