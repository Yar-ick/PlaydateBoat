local pdg <const> = playdate.graphics
local boldFont = pdg.getFont(pdg.font.kVariantBold)

local images = {
    background = pdg.image.new("images/UpgradeMenu"),
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

local upgradeNodeCenters <const> = { 117, 197, 285, 365 }

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

local function drawBoldText(text, x, y)
    local previousFont = pdg.getFont()
    pdg.setFont(boldFont)
    pdg.drawText(text, x, y)
    pdg.setFont(previousFont)
end

local function drawButtonPrompt(buttonImage, label, x, y)
    buttonImage:draw(x, y)
    drawBoldText(label, x + 30, y + 4)
end

local function drawUpgradeTrack(level, tuning, yOffset)
    local centerY = yOffset + 129
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
    local centerY = yOffset + 129
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
    images.background:draw(0, yOffset)
    pdg.setColor(pdg.kColorBlack)

    for index = 1, #abilities do
        local selectorAbility = abilities[index]
        local frameX = 30
        local frameY = yOffset + 22 + (index - 1) * 40

        drawFramedAbility(
            selectorAbility.image,
            frameX,
            frameY,
            selectorAbility.imageYOffset
        )

        if index == selectionIndex then
            images.selector:draw(18, frameY + 9)
        end
    end

    drawFramedAbility(ability.image, 106, yOffset + 22, ability.imageYOffset)
    drawBoldText(ability.title, 146, yOffset + 30)
    pdg.drawText(ability.description, 106, yOffset + 70)

    if level == tuning.LOCKED_ABILITY_LEVEL then
        pdg.drawText("Buy to unlock this ability.", 106, yOffset + 89)
    else
        pdg.drawText(ability.upgradeDescription, 106, yOffset + 89)
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

        drawButtonPrompt(images.aButton, actionLabel, 106, yOffset + 151)
        images.coin:getImage(UpgradeMenuUI.coinFrame):draw(225, yOffset + 153)
        pdg.drawText(tostring(cost), 248, yOffset + 155)
    else
        drawBoldText("Maximum level", 106, yOffset + 155)
    end

    drawButtonPrompt(images.bButton, "Back", 21, yOffset + 198)

    local coinText = string.format("%03d", coins)
    local coinTextWidth = pdg.getTextSize(coinText)
    images.coin:getImage(UpgradeMenuUI.coinFrame):draw(315, yOffset + 28)
    pdg.drawText(coinText, 378 - coinTextWidth - 8, yOffset + 30)

    if message ~= nil then
        pdg.drawTextAligned(message, 264, yOffset + 208, kTextAlignment.center)
    end

    pdg.setColor(previousColor)
end
