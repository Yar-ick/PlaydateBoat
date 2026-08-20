local tuning = nil
local regularProfile = nil
local otherSideProfile = nil

AbilityProgression = {}

local function loadLevel(value)
    local numericLevel = tonumber(value)

    if numericLevel == nil then
        return tuning.LOCKED_ABILITY_LEVEL
    end

    return math.max(
        tuning.LOCKED_ABILITY_LEVEL,
        math.min(tuning.MAX_ABILITY_UPGRADE_LEVEL, math.floor(numericLevel))
    )
end

local function loadProfile(savedCoins, savedUpgrades, abilityTypes)
    if type(savedUpgrades) ~= "table" then
        savedUpgrades = {}
    end

    local profile = {
        coins = math.max(0, math.floor(tonumber(savedCoins) or 0)),
        upgrades = {}
    }

    for index = 1, #abilityTypes do
        local abilityType = abilityTypes[index]
        profile.upgrades[abilityType] = loadLevel(savedUpgrades[abilityType])
    end

    return profile
end

local function getProfile(isOtherSide)
    return isOtherSide and otherSideProfile or regularProfile
end

local function copyUpgrades(profile)
    local upgrades = {}

    for abilityType, level in pairs(profile.upgrades) do
        upgrades[abilityType] = level
    end

    return upgrades
end

function AbilityProgression.initialize(savedProgress, gameplayTuning)
    tuning = gameplayTuning

    local savedOtherSide = savedProgress.otherSide
    if type(savedOtherSide) ~= "table" then
        savedOtherSide = {}
    end

    regularProfile = loadProfile(
        savedProgress.coins,
        savedProgress.upgrades,
        tuning.REGULAR_ABILITY_TYPES
    )
    otherSideProfile = loadProfile(
        savedOtherSide.coins,
        savedOtherSide.upgrades,
        tuning.OTHER_SIDE_ABILITY_TYPES
    )
end

function AbilityProgression.getCoins(isOtherSide)
    return getProfile(isOtherSide).coins
end

function AbilityProgression.addCoins(amount, isOtherSide)
    local profile = getProfile(isOtherSide)
    profile.coins = math.max(0, profile.coins + math.floor(tonumber(amount) or 0))
    return profile.coins
end

function AbilityProgression.getLevel(abilityType, isOtherSide)
    return getProfile(isOtherSide).upgrades[abilityType] or tuning.LOCKED_ABILITY_LEVEL
end

function AbilityProgression.getLevels(isOtherSide)
    return getProfile(isOtherSide).upgrades
end

function AbilityProgression.isPurchased(abilityType, isOtherSide)
    return AbilityProgression.getLevel(abilityType, isOtherSide) > tuning.LOCKED_ABILITY_LEVEL
end

function AbilityProgression.tryPurchase(abilityType, isOtherSide)
    local profile = getProfile(isOtherSide)
    local level = profile.upgrades[abilityType]

    if level == nil or level >= tuning.MAX_ABILITY_UPGRADE_LEVEL then
        return false, nil, false
    end

    local isPurchase = level == tuning.LOCKED_ABILITY_LEVEL
    local purchaseCosts = isOtherSide
        and tuning.OTHER_SIDE_ABILITY_PURCHASE_COSTS
        or tuning.ABILITY_PURCHASE_COSTS
    local upgradeCosts = isOtherSide
        and tuning.OTHER_SIDE_ABILITY_UPGRADE_COSTS
        or tuning.ABILITY_UPGRADE_COSTS
    local nextLevel = isPurchase and 0 or level + 1
    local cost = isPurchase and purchaseCosts[abilityType] or upgradeCosts[abilityType][nextLevel]

    if profile.coins < cost then
        return false, nil, isPurchase
    end

    profile.coins -= cost
    profile.upgrades[abilityType] = nextLevel
    return true, nextLevel, isPurchase
end

function AbilityProgression.areRegularAbilitiesMaxed()
    for index = 1, #tuning.REGULAR_ABILITY_TYPES do
        local abilityType = tuning.REGULAR_ABILITY_TYPES[index]

        if regularProfile.upgrades[abilityType] < tuning.MAX_ABILITY_UPGRADE_LEVEL then
            return false
        end
    end

    return true
end

function AbilityProgression.getSaveData()
    return {
        coins = regularProfile.coins,
        upgrades = copyUpgrades(regularProfile),
        otherSide = {
            coins = otherSideProfile.coins,
            upgrades = copyUpgrades(otherSideProfile)
        }
    }
end
