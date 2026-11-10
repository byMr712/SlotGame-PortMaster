local betModal = {}

local economy = require("src.core.economy")
local audio = require("src.core.audio")

betModal.active = false
betModal.digits = { 0, 0, 0, 1, 0, 0, 0 } -- 7 цифр: 1M, 100K, 10K, 1K, 100, 10, 1
betModal.cursor = 4
betModal.minBet = 100
betModal.maxBet = 100000
betModal.callback = nil
betModal.timer = 0

local digitLabels = { "1M", "100K", "10K", "1K", "100", "10", "1" }

function betModal.open(currentBet, minBet, maxBet, callback)
    betModal.active = true
    betModal.minBet = minBet or 100
    betModal.maxBet = maxBet or economy.getBalance()
    if betModal.maxBet < betModal.minBet then
        betModal.maxBet = betModal.minBet
    end
    betModal.callback = callback
    betModal.timer = 0

    local val = math.max(0, math.floor(currentBet or 100))
    for i = 7, 1, -1 do
        betModal.digits[i] = val % 10
        val = math.floor(val / 10)
    end

    -- Ставим курсор на первую значащую цифру в самом начале числа ставки
    betModal.cursor = 5 -- по умолчанию сотни, если 0
    for i = 1, 7 do
        if betModal.digits[i] > 0 then
            betModal.cursor = i
            break
        end
    end

    audio.play("click")
end

function betModal.close()
    betModal.active = false
end

function betModal.getTotal()
    local total = 0
    for i = 1, 7 do
        total = total * 10 + betModal.digits[i]
    end
    return total
end

function betModal.confirm()
    local total = betModal.getTotal()
    total = math.max(betModal.minBet, math.min(betModal.maxBet, total))
    audio.play("coin")
    betModal.active = false
    if betModal.callback then
        betModal.callback(total)
    end
end

function betModal.update(dt)
    if betModal.active then
        betModal.timer = betModal.timer + dt
    end
end

function betModal.keypressed(key)
    if not betModal.active then return false end

    if key == "left" then
        betModal.cursor = math.max(1, betModal.cursor - 1)
        audio.play("click")
        return true
    elseif key == "right" then
        betModal.cursor = math.min(7, betModal.cursor + 1)
        audio.play("click")
        return true
    elseif key == "up" then
        betModal.digits[betModal.cursor] = (betModal.digits[betModal.cursor] + 1) % 10
        audio.play("click")
        return true
    elseif key == "down" then
        betModal.digits[betModal.cursor] = (betModal.digits[betModal.cursor] + 9) % 10
        audio.play("click")
        return true
    elseif key == "a" or key == "return" or key == "space" or key == "y" then
        betModal.confirm()
        return true
    elseif key == "b" or key == "escape" then
        audio.play("click")
        betModal.close()
        return true
    end

    return true
end

function betModal.draw()
    if not betModal.active then return end

    -- Затемнение фона
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1024, 768)

    local mx = 232
    local my = 174
    local mw = 560
    local mh = 410

    -- Тень окна
    love.graphics.setColor(0.04, 0.02, 0.01)
    love.graphics.rectangle("fill", mx + 6, my + 6, mw, mh, 10)

    -- Рама из темного ореха
    love.graphics.setColor(0.16, 0.07, 0.02)
    love.graphics.rectangle("fill", mx, my, mw, mh, 10)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", mx, my, mw, mh, 10)
    love.graphics.setLineWidth(1)

    -- Внутреннее поле
    love.graphics.setColor(0.09, 0.04, 0.01)
    love.graphics.rectangle("fill", mx + 12, my + 12, mw - 24, mh - 24, 8)

    -- Заголовок модального окна
    love.graphics.setColor(1, 0.88, 0.4)
    local title = "SET YOUR BET"
    local font = love.graphics.getFont()
    local tw = font and font:getWidth(title) or (#title * 8)
    love.graphics.print(title, mx + mw / 2 - tw / 2, my + 24)

    -- Текущая собранная сумма
    local curTotal = betModal.getTotal()
    local totalStr = string.format("BET: %s", economy.format(curTotal))
    local stw = font and font:getWidth(totalStr) or (#totalStr * 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(totalStr, mx + mw / 2 - stw / 2, my + 54)

    -- 7 ячеек для цифр
    local cellW = 54
    local cellH = 74
    local gap = 10
    local totalGridW = 7 * cellW + 6 * gap
    local startX = mx + (mw - totalGridW) / 2
    local startY = my + 104

    local pulse = 0.5 + 0.5 * math.sin(betModal.timer * 6)

    for i = 1, 7 do
        local cx = startX + (i - 1) * (cellW + gap)
        local cy = startY
        local isSelected = (i == betModal.cursor)

        -- Фон ячейки
        if isSelected then
            love.graphics.setColor(0.35 + 0.1 * pulse, 0.20 + 0.05 * pulse, 0.05)
            love.graphics.rectangle("fill", cx, cy, cellW, cellH, 6)
            love.graphics.setColor(1, 0.9 + 0.1 * pulse, 0.4)
            love.graphics.setLineWidth(2.5)
            love.graphics.rectangle("line", cx, cy, cellW, cellH, 6)
            love.graphics.setLineWidth(1)

            -- Стрелочки вверх и вниз над/под выбранной ячейкой (полигоны без шрифтовых глитчей)
            love.graphics.setColor(1, 0.88, 0.4, 0.8 + 0.2 * pulse)
            -- Стрелка вверх ▲
            love.graphics.polygon("fill", cx + cellW / 2, cy - 14, cx + cellW / 2 - 9, cy - 4, cx + cellW / 2 + 9, cy - 4)
            -- Стрелка вниз ▼
            love.graphics.polygon("fill", cx + cellW / 2, cy + cellH + 14, cx + cellW / 2 - 9, cy + cellH + 4, cx + cellW / 2 + 9, cy + cellH + 4)
        else
            love.graphics.setColor(0.14, 0.06, 0.02)
            love.graphics.rectangle("fill", cx, cy, cellW, cellH, 6)
            love.graphics.setColor(0.55, 0.26, 0.08)
            love.graphics.rectangle("line", cx, cy, cellW, cellH, 6)
        end

        -- Цифра
        local dStr = tostring(betModal.digits[i])
        local dw = font and font:getWidth(dStr) or 8
        if isSelected then
            love.graphics.setColor(1, 1, 1)
        else
            if betModal.digits[i] > 0 then
                love.graphics.setColor(1, 0.88, 0.4)
            else
                love.graphics.setColor(0.55, 0.42, 0.25)
            end
        end
        love.graphics.print(dStr, cx + cellW / 2 - dw / 2, cy + 26)

        -- Подпись разряда (1M, 100K, 10K, ...)
        love.graphics.setColor(0.7, 0.55, 0.3)
        local lbl = digitLabels[i]
        local lw = font and font:getWidth(lbl) or (#lbl * 6)
        love.graphics.print(lbl, cx + cellW / 2 - lw / 2, cy + cellH + 20)
    end

    -- Лимиты
    love.graphics.setColor(0.85, 0.72, 0.45)
    local limStr = string.format("MIN: %s   •   MAX: %s (BALANCE)", economy.format(betModal.minBet), economy.format(betModal.maxBet))
    local limW = font and font:getWidth(limStr) or (#limStr * 7)
    love.graphics.print(limStr, mx + mw / 2 - limW / 2, my + 260)

    -- Панель горячих клавиш управления
    love.graphics.setColor(0.14, 0.06, 0.02)
    love.graphics.rectangle("fill", mx + 24, my + 300, mw - 48, 48, 6)
    love.graphics.setColor(0.55, 0.26, 0.08)
    love.graphics.rectangle("line", mx + 24, my + 300, mw - 48, 48, 6)

    love.graphics.setColor(1, 0.88, 0.4)
    local hint = "[◄/►] SELECT   •   [▲/▼] 0-9   •   [A] CONFIRM   •   [B] BACK"
    local hw = font and font:getWidth(hint) or (#hint * 7)
    love.graphics.print(hint, mx + mw / 2 - hw / 2, my + 316)
end

return betModal
