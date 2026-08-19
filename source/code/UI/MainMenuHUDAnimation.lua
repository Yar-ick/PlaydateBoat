local progress = 0
local direction = 0
local pendingAction = nil

MainMenuHUDAnimation = {}

function MainMenuHUDAnimation.show()
    progress = 0
    direction = 1
    pendingAction = nil
end

function MainMenuHUDAnimation.hide(action)
    if direction ~= 0 or progress < 1 then
        return false
    end

    direction = -1
    pendingAction = action
    return true
end

function MainMenuHUDAnimation.update(elapsedMilliseconds, tuning)
    if direction == 0 then
        return nil
    end

    progress = math.clamp(
        progress + direction * elapsedMilliseconds / tuning.MAIN_MENU_HUD_SLIDE_DURATION_MS,
        0,
        1
    )

    if direction > 0 and progress >= 1 then
        direction = 0
    elseif direction < 0 and progress <= 0 then
        direction = 0
        local completedAction = pendingAction
        pendingAction = nil
        return completedAction
    end

    return nil
end

function MainMenuHUDAnimation.isInteractive()
    return direction == 0 and progress >= 1
end

function MainMenuHUDAnimation.getOffsets(tuning)
    local easedProgress = progress * progress * (3 - 2 * progress)
    local hiddenProgress = 1 - easedProgress

    return math.floor(tuning.MAIN_MENU_HUD_LEFT_HIDDEN_OFFSET_X * hiddenProgress + 0.5),
        math.floor(tuning.MAIN_MENU_HUD_RIGHT_HIDDEN_OFFSET_X * hiddenProgress + 0.5)
end
