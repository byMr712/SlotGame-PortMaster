local betModal = {}

local economy = require("src.core.economy")
local audio = require("src.core.audio")
local i18n = require("src.core.i18n")

betModal.active = false
-- 10 ячеек цифр: до 9,999,999,999 (миллиарды)
betModal.digits = { 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 }
betModal.cursor = 8 -- по умолчанию сотни (индекс 8)
betModal.minBet = 100
betModal.maxBet = 100000
betModal.callback = nil
betModal.timer = 0

local digitLabels = { "1B", "100M", "10M", "1M", "100K", "10K", "1K", "100", "10", "1" }

local function syncDigits(val)
    val = math.max(0, math.floor(val or 0))
    for i = 10, 1, -1 do
        betModal.digits[i] = val % 10
        val = math.floor(val / 10)
    end
end

function betModal.getTotal()
    local total = 0
    for i = 1, 10 do
        total = total * 10 + betModal.digits[i]
    end
    return total
end

function betModal.clampToBalance()
    local bal = economy.getBalance()
    local total = betModal.getTotal()
    if total > bal then
        syncDigits(bal)
    end
end

function betModal.setHalf()
    local cur = math.floor(betModal.getTotal() / 2)
    cur = math.max(betModal.minBet, cur)
    local bal = economy.getBalance()
    if cur > bal then cur = bal end
    syncDigits(cur)
    audio.play("click")
end

function betModal.setDouble()
    local cur = betModal.getTotal() * 2
    local bal = economy.getBalance()
    cur = math.min(bal, cur)
    syncDigits(cur)
    audio.play("click")
end

function betModal.setMin()
    local cur = betModal.minBet
    local bal = economy.getBalance()
    if bal < cur and bal > 0 then cur = 1 end
    syncDigits(cur)
    audio.play("click")
end

function betModal.setMax()
    local bal = economy.getBalance()
    syncDigits(bal)
    audio.play("coin")
end

function betModal.open(currentBet, minBet, maxBet, callback)
    betModal.active = true
    local bal = economy.getBalance()
    betModal.minBet = minBet or 100
    if bal < betModal.minBet and bal > 0 then
        betModal.minBet = 1
    end
    betModal.maxBet = math.min(maxBet or bal, bal)
    if betModal.maxBet < betModal.minBet then
        betModal.maxBet = betModal.minBet
    end
    betModal.callback = callback
    betModal.timer = 0

    local val = math.max(0, math.floor(currentBet or 100))
    if val > betModal.maxBet then
        val = betModal.maxBet
    end
    if val < betModal.minBet and bal >= betModal.minBet then
        val = betModal.minBet
    end
    syncDigits(val)

    -- Ставим курсор на первую значащую цифру в самом начале числа ставки
    betModal.cursor = 8 -- сотни по умолчанию, если 0
    for i = 1, 10 do
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

function betModal.confirm()
    local total = betModal.getTotal()
    local bal = economy.getBalance()
    total = math.min(total, bal)
    if bal >= betModal.minBet then
        total = math.max(betModal.minBet, total)
    else
        total = math.max(1, total)
    end
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

-- Вспомогательная функция для вычисления X-координаты ячейки с учетом разделительных точек
local function getCellX(startX, i, cellW, gap, dotW)
    local dotsBefore = 0
    if i >= 2 then dotsBefore = dotsBefore + 1 end
    if i >= 5 then dotsBefore = dotsBefore + 1 end
    if i >= 8 then dotsBefore = dotsBefore + 1 end
    return startX + (i - 1) * (cellW + gap) + dotsBefore * (dotW + gap)
end

function betModal.mousepressed(x, y)
    if not betModal.active then return false end

    local mw = 700
    local mh = 430
    local mx = (1024 - mw) / 2
    local my = (768 - mh) / 2

    local cellW = 46
    local cellH = 68
    local gap = 6
    local dotW = 12
    local totalGridW = 10 * cellW + 9 * gap + 3 * (dotW + gap)
    local startX = mx + (mw - totalGridW) / 2
    local startY = my + 92

    -- 1. Клик по ячейкам цифр и стрелкам
    for i = 1, 10 do
        local cx = getCellX(startX, i, cellW, gap, dotW)
        if x >= cx and x <= cx + cellW then
            if y >= startY - 26 and y < startY then
                betModal.cursor = i
                betModal.digits[i] = (betModal.digits[i] + 1) % 10
                betModal.clampToBalance()
                audio.play("click")
                return true
            elseif y >= startY and y <= startY + cellH then
                betModal.cursor = i
                audio.play("click")
                return true
            elseif y > startY + cellH and y <= startY + cellH + 26 then
                betModal.cursor = i
                betModal.digits[i] = (betModal.digits[i] + 9) % 10
                betModal.clampToBalance()
                audio.play("click")
                return true
            end
        end
    end

    -- 2. Клик по кнопкам быстрого изменения: [L2] MIN, [L1] /2, [R1] x2, [R2] MAX
    local qy = my + 242
    local qh = 36
    local qw = 138
    local qgap = 14
    local qStartX = mx + (mw - (4 * qw + 3 * qgap)) / 2

    if y >= qy and y <= qy + qh then
        if x >= qStartX and x <= qStartX + qw then
            betModal.setMin()
            return true
        elseif x >= qStartX + qw + qgap and x <= qStartX + 2 * qw + qgap then
            betModal.setHalf()
            return true
        elseif x >= qStartX + 2 * (qw + qgap) and x <= qStartX + 3 * qw + 2 * qgap then
            betModal.setDouble()
            return true
        elseif x >= qStartX + 3 * (qw + qgap) and x <= qStartX + 4 * qw + 3 * qgap then
            betModal.setMax()
            return true
        end
    end

    -- 3. Клик по кнопкам [X] CONFIRM / [B] BACK
    local by = my + 296
    local bh = 46
    local bw = 230
    local bgap = 24
    local bStartX = mx + (mw - (2 * bw + bgap)) / 2

    if y >= by and y <= by + bh then
        if x >= bStartX and x <= bStartX + bw then
            betModal.confirm()
            return true
        elseif x >= bStartX + bw + bgap and x <= bStartX + 2 * bw + bgap then
            audio.play("click")
            betModal.close()
            return true
        end
    end

    return true
end

function betModal.keypressed(key)
    if not betModal.active then return false end

    if key == "left" then
        betModal.cursor = math.max(1, betModal.cursor - 1)
        audio.play("click")
        return true
    elseif key == "right" then
        betModal.cursor = math.min(10, betModal.cursor + 1)
        audio.play("click")
        return true
    elseif key == "up" then
        betModal.digits[betModal.cursor] = (betModal.digits[betModal.cursor] + 1) % 10
        betModal.clampToBalance()
        audio.play("click")
        return true
    elseif key == "down" then
        betModal.digits[betModal.cursor] = (betModal.digits[betModal.cursor] + 9) % 10
        betModal.clampToBalance()
        audio.play("click")
        return true
    elseif key == "l1" or key == "q" then
        betModal.setHalf()
        return true
    elseif key == "r1" or key == "e" then
        betModal.setDouble()
        return true
    elseif key == "l2" or key == "z" or key == "lshift" then
        betModal.setMin()
        return true
    elseif key == "r2" or key == "c" or key == "tab" then
        betModal.setMax()
        return true
    elseif key == "x" or key == "a" or key == "return" or key == "space" then
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

    local font = love.graphics.getFont()

    -- Затемнение фона
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, 1024, 768)

    local mw = 700
    local mh = 430
    local mx = (1024 - mw) / 2
    local my = (768 - mh) / 2

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
    love.graphics.rectangle("fill", mx + 10, my + 10, mw - 20, mh - 20, 8)

    -- Заголовок модального окна
    love.graphics.setColor(1, 0.88, 0.4)
    local title = "SET YOUR BET"
    local tw = font and font:getWidth(title) or (#title * 8)
    love.graphics.print(title, mx + mw / 2 - tw / 2, my + 20)

    -- Баланс игрока
    local balStr = string.format("%s: %s", i18n.t("balance"), economy.getBalanceFormatted())
    local stw = font and font:getWidth(balStr) or (#balStr * 8)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(balStr, mx + mw / 2 - stw / 2, my + 46)

    -- 10 ячеек для цифр с разделительными точками
    local cellW = 46
    local cellH = 68
    local gap = 6
    local dotW = 12
    local totalGridW = 10 * cellW + 9 * gap + 3 * (dotW + gap)
    local startX = mx + (mw - totalGridW) / 2
    local startY = my + 82

    local pulse = 0.5 + 0.5 * math.sin(betModal.timer * 6)

    for i = 1, 10 do
        local cx = getCellX(startX, i, cellW, gap, dotW)
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

            -- Стрелочки вверх и вниз над/под выбранной ячейкой
            love.graphics.setColor(1, 0.88, 0.4, 0.8 + 0.2 * pulse)
            -- Стрелка вверх ▲
            love.graphics.polygon("fill", cx + cellW / 2, cy - 14, cx + cellW / 2 - 8, cy - 4, cx + cellW / 2 + 8, cy - 4)
            -- Стрелка вниз ▼
            love.graphics.polygon("fill", cx + cellW / 2, cy + cellH + 14, cx + cellW / 2 - 8, cy + cellH + 4, cx + cellW / 2 + 8, cy + cellH + 4)
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
        love.graphics.print(dStr, cx + cellW / 2 - dw / 2, cy + 24)

        -- Подпись разряда (1B, 100M, 10M, 1M, ...)
        love.graphics.setColor(0.7, 0.55, 0.3)
        local lbl = digitLabels[i]
        local lw = font and font:getWidth(lbl) or (#lbl * 6)
        love.graphics.print(lbl, cx + cellW / 2 - lw / 2, cy + cellH + 18)

        -- Стилистическая разделительная точка каждые 3 ячейки с правой стороны (после 1, 4, 7)
        if i == 1 or i == 4 or i == 7 then
            local dotCenterX = cx + cellW + gap + dotW / 2
            local dotCenterY = cy + cellH - 10
            love.graphics.setColor(1, 0.85, 0.25, 0.85)
            love.graphics.circle("fill", dotCenterX, dotCenterY, 3.5)
            love.graphics.setColor(0.2, 0.08, 0.02)
            love.graphics.circle("line", dotCenterX, dotCenterY, 3.5)
            love.graphics.setColor(1, 1, 0.8)
            love.graphics.circle("fill", dotCenterX - 1, dotCenterY - 1, 1.2)
        end
    end

    -- Текущая ставка и лимиты
    love.graphics.setColor(0.9, 0.8, 0.6)
    local curTotal = betModal.getTotal()
    local limStr = string.format("%s: %s   •   MIN: %s   •   MAX: %s", i18n.t("bet"), economy.format(curTotal), economy.format(betModal.minBet), economy.format(betModal.maxBet))
    local limW = font and font:getWidth(limStr) or (#limStr * 7)
    love.graphics.print(limStr, mx + mw / 2 - limW / 2, my + 198)

    -- Панель горячих клавиш: [L2] MIN, [L1] /2, [R1] x2, [R2] MAX
    local qy = my + 234
    local qh = 36
    local qw = 138
    local qgap = 14
    local qStartX = mx + (mw - (4 * qw + 3 * qgap)) / 2

    local function drawQuickBtn(bx, by, bw, bh, tagText, labelText)
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.rectangle("fill", bx, by, bw, bh, 5)
        love.graphics.setColor(0.25, 0.12, 0.04)
        love.graphics.rectangle("fill", bx + 1.5, by + 1.5, bw - 3, bh - 3, 4)
        love.graphics.setColor(0.65, 0.42, 0.12)
        love.graphics.rectangle("line", bx + 1.5, by + 1.5, bw - 3, bh - 3, 4)

        -- Тег кнопки ([L1], [R1], [L2], [R2])
        love.graphics.setColor(0.78, 0.42, 0.14)
        love.graphics.rectangle("fill", bx + 6, by + 6, 44, bh - 12, 3)
        love.graphics.setColor(1, 0.95, 0.7)
        local tW = font and font:getWidth(tagText) or (#tagText * 8)
        love.graphics.print(tagText, bx + 6 + 22 - tW / 2, by + bh / 2 - 6)

        -- Текст действия (MIN, /2, x2, MAX)
        love.graphics.setColor(1, 0.88, 0.4)
        local lW = font and font:getWidth(labelText) or (#labelText * 8)
        love.graphics.print(labelText, bx + 54 + (bw - 60) / 2 - lW / 2, by + bh / 2 - 6)
    end

    drawQuickBtn(qStartX, qy, qw, qh, "L2", "MIN")
    drawQuickBtn(qStartX + qw + qgap, qy, qw, qh, "L1", "/2")
    drawQuickBtn(qStartX + 2 * (qw + qgap), qy, qw, qh, "R1", "x2")
    drawQuickBtn(qStartX + 3 * (qw + qgap), qy, qw, qh, "R2", "MAX")

    -- Кнопка [X] CONFIRM
    local by = my + 288
    local bh = 46
    local bw = 230
    local bgap = 24
    local bStartX = mx + (mw - (2 * bw + bgap)) / 2

    local btn1X = bStartX
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.rectangle("fill", btn1X, by, bw, bh, 6)
    love.graphics.setColor(0.18, 0.38, 0.68)
    love.graphics.rectangle("fill", btn1X + 2, by + 2, bw - 4, bh - 4, 5)
    love.graphics.setColor(0.35, 0.65, 0.95)
    love.graphics.rectangle("line", btn1X + 2, by + 2, bw - 4, bh - 4, 5)

    local cx1 = btn1X + 26
    local cy1 = by + bh / 2
    love.graphics.setColor(0.32, 0.62, 0.96)
    love.graphics.circle("fill", cx1, cy1, 13)
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx1, cy1, 13)
    love.graphics.setLineWidth(1)
    love.graphics.print("X", cx1 - 4, cy1 - 7)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("CONFIRM", btn1X + 54, by + 16)

    -- Кнопка [B] BACK
    local btn2X = bStartX + bw + bgap
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.rectangle("fill", btn2X, by, bw, bh, 6)
    love.graphics.setColor(0.75, 0.16, 0.1)
    love.graphics.rectangle("fill", btn2X + 2, by + 2, bw - 4, bh - 4, 5)
    love.graphics.setColor(0.95, 0.35, 0.25)
    love.graphics.rectangle("line", btn2X + 2, by + 2, bw - 4, bh - 4, 5)

    local cx2 = btn2X + 26
    local cy2 = by + bh / 2
    love.graphics.setColor(0.95, 0.32, 0.3)
    love.graphics.circle("fill", cx2, cy2, 13)
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx2, cy2, 13)
    love.graphics.setLineWidth(1)
    love.graphics.print("B", cx2 - 4, cy2 - 7)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("BACK", btn2X + 66, by + 16)

    -- Строка подсказки навигации внизу
    love.graphics.setColor(0.75, 0.62, 0.38)
    local navHint = "< / > SELECT DIGIT   *   ^ / v ADJUST VALUE"
    local nhW = font and font:getWidth(navHint) or (#navHint * 7)
    love.graphics.print(navHint, mx + mw / 2 - nhW / 2, my + 358)
end

return betModal
