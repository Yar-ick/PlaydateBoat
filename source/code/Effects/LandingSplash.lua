local pdg <const> = playdate.graphics

local tuning = nil
local particles = {}
local active = false
local elapsedMilliseconds = 0
local centerX = 0
local centerY = 0
local effectScale = 1

LandingSplash = {}

function LandingSplash.initialize(gameplayTuning)
    tuning = gameplayTuning
    particles = {}

    for index = 1, tuning.LANDING_SPLASH_PARTICLE_COUNT do
        particles[index] = {
            active = false,
            x = 0,
            y = 0,
            dx = 0,
            dy = 0,
            ageMilliseconds = 0,
            lifetimeMilliseconds = 1,
            length = 1
        }
    end

    LandingSplash.reset()
end

function LandingSplash.start(x, y, scale)
    active = true
    elapsedMilliseconds = 0
    centerX = x
    centerY = y
    effectScale = scale or 1

    for index = 1, #particles do
        local particle = particles[index]
        local angle = (index - 1) * math.pi * 2 / #particles
            + math.rad(math.random(
                -tuning.LANDING_SPLASH_ANGLE_JITTER_DEGREES,
                tuning.LANDING_SPLASH_ANGLE_JITTER_DEGREES
            ))
        local speed = math.random(
            tuning.LANDING_SPLASH_MINIMUM_SPEED_TENTHS,
            tuning.LANDING_SPLASH_MAXIMUM_SPEED_TENTHS
        ) / 10 * effectScale

        particle.active = true
        particle.x = x
        particle.y = y
        particle.dx = math.cos(angle) * speed
        particle.dy = math.sin(angle) * speed * tuning.LANDING_SPLASH_VERTICAL_SPEED_MULTIPLIER
        particle.ageMilliseconds = 0
        particle.lifetimeMilliseconds = math.random(
            tuning.LANDING_SPLASH_MINIMUM_LIFETIME_MS,
            tuning.LANDING_SPLASH_MAXIMUM_LIFETIME_MS
        )
        particle.length = math.random(
            tuning.LANDING_SPLASH_MINIMUM_LINE_LENGTH,
            tuning.LANDING_SPLASH_MAXIMUM_LINE_LENGTH
        ) * effectScale
    end

    WakeLayer.markDirty()
end

function LandingSplash.update(frameElapsedMilliseconds, worldDisplacement)
    if active == false then
        return
    end

    elapsedMilliseconds += frameElapsedMilliseconds
    centerX += worldDisplacement

    local frameDurationMilliseconds <const> = 1000 / 30
    local retention = tuning.LANDING_SPLASH_VELOCITY_RETENTION_PER_FRAME
        ^ (frameElapsedMilliseconds / frameDurationMilliseconds)
    local hasActiveParticle = false

    for index = 1, #particles do
        local particle = particles[index]

        if particle.active then
            particle.ageMilliseconds += frameElapsedMilliseconds

            if particle.ageMilliseconds >= particle.lifetimeMilliseconds then
                particle.active = false
            else
                particle.x += particle.dx + worldDisplacement
                particle.y += particle.dy
                particle.dx *= retention
                particle.dy *= retention
                hasActiveParticle = true
            end
        end
    end

    if elapsedMilliseconds >= tuning.LANDING_SPLASH_RING_DURATION_MS
        and hasActiveParticle == false
    then
        active = false
    end

    WakeLayer.markDirty()
end

function LandingSplash.draw()
    if active == false then
        return
    end

    local previousColor = pdg.getColor()
    local previousLineWidth = pdg.getLineWidth()
    local ringProgress = math.min(
        1,
        elapsedMilliseconds / tuning.LANDING_SPLASH_RING_DURATION_MS
    )
    local ringWidth = tuning.LANDING_SPLASH_RING_MAXIMUM_WIDTH
        * effectScale * ringProgress
    local ringHeight = tuning.LANDING_SPLASH_RING_MAXIMUM_HEIGHT
        * effectScale * ringProgress

    pdg.setColor(pdg.kColorBlack)
    pdg.setLineWidth(1)

    if ringProgress > 0 and ringProgress < 1 then
        local halfWidth = ringWidth / 2
        local halfHeight = ringHeight / 2
        local previousX = centerX + halfWidth
        local previousY = centerY

        for segmentIndex = 1, tuning.LANDING_SPLASH_RING_SEGMENT_COUNT do
            local angle = segmentIndex * math.pi * 2
                / tuning.LANDING_SPLASH_RING_SEGMENT_COUNT
            local x = centerX + math.cos(angle) * halfWidth
            local y = centerY + math.sin(angle) * halfHeight

            pdg.drawLine(previousX, previousY, x, y)
            previousX = x
            previousY = y
        end
    end

    for index = 1, #particles do
        local particle = particles[index]

        if particle.active then
            local lifeProgress = particle.ageMilliseconds / particle.lifetimeMilliseconds
            local length = particle.length * (1 - lifeProgress)
            local velocityLength = math.sqrt(
                particle.dx * particle.dx + particle.dy * particle.dy
            )

            if velocityLength > 0 then
                pdg.drawLine(
                    particle.x,
                    particle.y,
                    particle.x - particle.dx / velocityLength * length,
                    particle.y - particle.dy / velocityLength * length
                )
            end

            if lifeProgress < 0.55 then
                pdg.fillCircleAtPoint(particle.x, particle.y, 1)
            end
        end
    end

    pdg.setLineWidth(previousLineWidth)
    pdg.setColor(previousColor)
end

function LandingSplash.reset()
    active = false
    elapsedMilliseconds = 0

    for index = 1, #particles do
        particles[index].active = false
    end

    WakeLayer.markDirty()
end
