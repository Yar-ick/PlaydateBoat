local pdg <const> = playdate.graphics

local digitImagePadding = 2
local digitCellWidth = 0
local digitHeight = 0
local digitImages = {}

for digit = 0, 9 do
    local width, height = pdg.getTextSize(tostring(digit))
    digitCellWidth = math.max(digitCellWidth, width)
    digitHeight = math.max(digitHeight, height)
end

local previousColor = pdg.getColor()
pdg.setColor(pdg.kColorBlack)

for digit = 0, 9 do
    local digitText = tostring(digit)
    local digitWidth = pdg.getTextSize(digitText)
    local image = pdg.image.new(
        digitCellWidth + digitImagePadding * 2,
        digitHeight + digitImagePadding * 2,
        pdg.kColorClear
    )

    pdg.pushContext(image)
    pdg.drawText(
        digitText,
        digitImagePadding + math.floor((digitCellWidth - digitWidth) / 2),
        digitImagePadding
    )
    pdg.popContext()
    digitImages[digit + 1] = image
end

pdg.setColor(previousColor)

FixedWidthNumber = {}

function FixedWidthNumber.new(minimumDigits)
    return {
        value = nil,
        minimumDigits = minimumDigits,
        digitCount = minimumDigits,
        digits = {},
        width = minimumDigits * (digitCellWidth + 1)
    }
end

function FixedWidthNumber.update(numberCache, value)
    value = math.max(0, math.floor(value))
    if numberCache.value == value then
        return
    end

    numberCache.value = value
    local remainingValue = value
    local digitCount = 1

    while remainingValue >= 10 do
        remainingValue = math.floor(remainingValue / 10)
        digitCount += 1
    end

    digitCount = math.max(numberCache.minimumDigits, digitCount)
    numberCache.digitCount = digitCount
    numberCache.width = digitCount * (digitCellWidth + 1)
    remainingValue = value

    for digitIndex = digitCount, 1, -1 do
        numberCache.digits[digitIndex] = remainingValue % 10
        remainingValue = math.floor(remainingValue / 10)
    end
end

function FixedWidthNumber.draw(numberCache, x, y)
    for digitIndex = 1, numberCache.digitCount do
        digitImages[numberCache.digits[digitIndex] + 1]:draw(
            x - digitImagePadding,
            y - digitImagePadding
        )
        x += digitCellWidth + 1
    end
end
