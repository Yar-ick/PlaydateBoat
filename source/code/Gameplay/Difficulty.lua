local tuning = nil
local highScores = {}
local selectedModeIndex = 1
local persistedModeId = nil
local secretModeUnlocked = false

Difficulty = {}

local function findModeIndex(modeId)
    for index = 1, #tuning.DIFFICULTY_MODES do
        if tuning.DIFFICULTY_MODES[index].ID == modeId then
            return index
        end
    end

    return nil
end

local function isModeUnlocked(mode)
    if mode.UNLOCK_ALL_ABILITIES then
        return secretModeUnlocked
    end

    if mode.UNLOCK_MODE_ID == nil then
        return true
    end

    return (highScores[mode.UNLOCK_MODE_ID] or 0) >= mode.UNLOCK_SCORE
end

function Difficulty.setSecretModeUnlocked(isUnlocked)
    secretModeUnlocked = isUnlocked == true

    if secretModeUnlocked
        and tuning ~= nil
        and isModeUnlocked(tuning.DIFFICULTY_MODES[selectedModeIndex])
    then
        persistedModeId = tuning.DIFFICULTY_MODES[selectedModeIndex].ID
    end
end

function Difficulty.initialize(savedProgress, gameplayTuning)
    tuning = gameplayTuning
    highScores = {}

    local savedDifficulty = savedProgress.difficulty
    if type(savedDifficulty) ~= "table" then
        savedDifficulty = {}
    end

    local savedHighScores = savedDifficulty.highScores
    if type(savedHighScores) ~= "table" then
        savedHighScores = {}
    end

    for index = 1, #tuning.DIFFICULTY_MODES do
        local mode = tuning.DIFFICULTY_MODES[index]
        local savedScore = tonumber(savedHighScores[mode.ID]) or 0
        highScores[mode.ID] = math.max(0, math.floor(savedScore))
    end

    selectedModeIndex = findModeIndex(savedDifficulty.selectedModeId) or 1

    if isModeUnlocked(tuning.DIFFICULTY_MODES[selectedModeIndex]) == false then
        selectedModeIndex = 1
    end

    persistedModeId = tuning.DIFFICULTY_MODES[selectedModeIndex].ID
end

function Difficulty.getSelectedMode()
    return tuning.DIFFICULTY_MODES[selectedModeIndex]
end

function Difficulty.getSelectedModeIndex()
    return selectedModeIndex
end

function Difficulty.getModeCount()
    return #tuning.DIFFICULTY_MODES
end

function Difficulty.isSelectedModeUnlocked()
    return isModeUnlocked(Difficulty.getSelectedMode())
end

function Difficulty.select(direction)
    selectedModeIndex = (selectedModeIndex - 1 + direction)
        % #tuning.DIFFICULTY_MODES + 1

    if Difficulty.isSelectedModeUnlocked() then
        persistedModeId = Difficulty.getSelectedMode().ID
        return true
    end

    return false
end

function Difficulty.getHighScore(modeId)
    return highScores[modeId] or 0
end

function Difficulty.getSelectedHighScore()
    return Difficulty.getHighScore(Difficulty.getSelectedMode().ID)
end

function Difficulty.recordScore(score)
    local modeId = Difficulty.getSelectedMode().ID
    local normalizedScore = math.max(0, math.floor(tonumber(score) or 0))

    if normalizedScore <= Difficulty.getHighScore(modeId) then
        return false
    end

    highScores[modeId] = normalizedScore
    return true
end

function Difficulty.getCoinReward()
    return Difficulty.getSelectedMode().COIN_REWARD
end

function Difficulty.getMaxWorldVelocity()
    return Difficulty.getSelectedMode().MAX_WORLD_VELOCITY
end

function Difficulty.getWorldVelocityGrowthMultiplier()
    return Difficulty.getSelectedMode().WORLD_VELOCITY_GROWTH_MULTIPLIER
end

function Difficulty.getRandomCollectableInterval(baseConfig, collectableType)
    local multiplier = 1

    if collectableType ~= "coin" then
        multiplier = Difficulty.getSelectedMode().ABILITY_SPAWN_INTERVAL_MULTIPLIER
    end

    local minimumInterval = math.max(1, math.floor(baseConfig.minimumIntervalMs * multiplier + 0.5))
    local maximumInterval = math.max(
        minimumInterval,
        math.floor(baseConfig.maximumIntervalMs * multiplier + 0.5)
    )

    return math.random(minimumInterval, maximumInterval)
end

function Difficulty.getCollectableSpawnChance(baseConfig, collectableType)
    if collectableType == "coin" then
        return baseConfig.spawnChancePercent
    end

    return math.clamp(
        baseConfig.spawnChancePercent
            * Difficulty.getSelectedMode().ABILITY_SPAWN_CHANCE_MULTIPLIER,
        0,
        100
    )
end

function Difficulty.getSaveData()
    local savedHighScores = {}

    for index = 1, #tuning.DIFFICULTY_MODES do
        local modeId = tuning.DIFFICULTY_MODES[index].ID
        savedHighScores[modeId] = Difficulty.getHighScore(modeId)
    end

    return {
        selectedModeId = persistedModeId,
        highScores = savedHighScores
    }
end
