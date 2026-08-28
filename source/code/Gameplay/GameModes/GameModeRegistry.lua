GameModes = {
    active = nil,
    wakebreaker = nil,
    theOtherSide = nil
}

function GameModes.initialize(tuning)
    GameModes.wakebreaker = WakebreakerGameMode(tuning)
    GameModes.theOtherSide = TheOtherSideGameMode(tuning)
    GameModes.active = GameModes.wakebreaker
end

function GameModes.refreshActiveMode()
    GameModes.active = Difficulty.isOtherSideMode()
        and GameModes.theOtherSide
        or GameModes.wakebreaker
    return GameModes.active
end

function GameModes.addGameplayMusicSources(channel)
    channel:addSource(GameModes.wakebreaker:getGameplayMusicPlayer())
    channel:addSource(GameModes.theOtherSide:getGameplayMusicPlayer())
end

function GameModes.stopInactiveGameplayMusic()
    local inactiveMode = GameModes.active == GameModes.wakebreaker
        and GameModes.theOtherSide
        or GameModes.wakebreaker
    local inactiveMusic = inactiveMode:getGameplayMusicPlayer()

    if inactiveMusic:isPlaying() then
        inactiveMusic:stop()
    end
end

function GameModes.pauseGameplayMusic()
    local wakebreakerMusic = GameModes.wakebreaker:getGameplayMusicPlayer()
    local otherSideMusic = GameModes.theOtherSide:getGameplayMusicPlayer()

    if wakebreakerMusic:isPlaying() then
        wakebreakerMusic:pause()
    end

    if otherSideMusic:isPlaying() then
        otherSideMusic:pause()
    end
end

function GameModes.stopGameplayMusic()
    GameModes.wakebreaker:getGameplayMusicPlayer():stop()
    GameModes.theOtherSide:getGameplayMusicPlayer():stop()
end

function GameModes.setGameplayMusicRate(rate)
    GameModes.wakebreaker:getGameplayMusicPlayer():setRate(rate)
    GameModes.theOtherSide:getGameplayMusicPlayer():setRate(rate)
end

