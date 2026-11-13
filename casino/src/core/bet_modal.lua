local betModal = {}

local economy = require("src.core.economy")
local audio = require("src.core.audio")
local i18n = require("src.core.i18n")
local fonts = require("src.core.fonts")
local ui = require("src.core.ui")

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
    for i = 1, 10 do
        if betModal.digits[i] > 0 then
            betModal.cursor = i
            break
        end
    end
    audio.play("click")
end

function betModal.setDouble()
    local cur = betModal.getTotal() * 2
    local bal = economy.getBalance()
    cur = math.min(bal, cur)
    if cur > 9999999999 then cur = 9999999999 end
    syncDigits(cur)
    for i = 1, 10 do
        if betModal.digits[i] > 0 then
            betModal.cursor = i
            break
        end
    end
    audio.play("click")
end

function betModal.setMin()
    local cur = betModal.minBet
    local bal = economy.getBalance()
    if bal < cur and bal > 0 then cur = 1 end
    syncDigits(cur)
    for i = 1, 10 do
        if betModal.digits[i] > 0 then
            betModal.cursor = i
            break
        end
    end
    audio.play("click")
end

function betModal.setMax()
    local bal = economy.getBalance()
    local target = math.min(bal, (betModal.maxBet and betModal.maxBet > 0) and betModal.maxBet or bal)
    if target > 9999999999 then target = 9999999999 end
    syncDigits(target)
    betModal.cursor = 10
    for i = 1, 10 do
        if betModal.digits[i] > 0 then
            betModal.cursor = i
            break
        end
    end
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
    local startY = my + 82 -- Точное совпадение с draw()

    -- 1. Клик / тачскрин по ячейкам цифр и стрелкам с увеличенной зоной захвата
    for i = 1, 10 do
        local cx = getCellX(startX, i, cellW, gap, dotW)
        if x >= cx - 3 and x <= cx + cellW + 3 then
            -- Стрелка вверх ▲
            if y >= startY - 26 and y < startY then
                betModal.cursor = i
                betModal.digits[i] = (betModal.digits[i] + 1) % 10
                betModal.clampToBalance()
                audio.play("click")
                return true
            -- Сама ячейка с цифрой
            elseif y >= startY and y <= startY + cellH then
                betModal.cursor = i
                audio.play("click")
                return true
            -- Стрелка вниз ▼
            elseif y > startY + cellH and y <= startY + cellH + 26 then
                betModal.cursor = i
                betModal.digits[i] = (betModal.digits[i] + 9) % 10
                betModal.clampToBalance()
                audio.play("click")
                return true
            end
        end
    end

    -- 2. Клик / тачскрин по кнопкам быстрого изменения: [L1] /2, [L2] MIN, [R2] MAX, [R1] x2
    local qy = my + 234
    local qh = 36
    local qw = 138
    local qgap = 14
    local qStartX = mx + (mw - (4 * qw + 3 * qgap)) / 2

    -- Щедрая вертикальная зона для пальцев тачскрина (+-10px) и непрерывное покрытие зазоров
    if y >= qy - 10 and y <= qy + qh + 10 then
        -- [L1] /2
        if x >= qStartX - 10 and x < qStartX + qw + qgap / 2 then
            betModal.setHalf()
            return true
        -- [L2] MIN
        elseif x >= qStartX + qw + qgap / 2 and x < qStartX + 2 * qw + 1.5 * qgap then
            betModal.setMin()
            return true
        -- [R2] MAX (гарантированное срабатывание всей плашки MAX и зазоров)
        elseif x >= qStartX + 2 * qw + 1.5 * qgap and x < qStartX + 3 * qw + 2.5 * qgap then
            betModal.setMax()
            return true
        -- [R1] x2
        elseif x >= qStartX + 3 * qw + 2.5 * qgap and x <= qStartX + 4 * qw + 3 * qgap + 10 then
            betModal.setDouble()
            return true
        end
    end

    -- 3. Клик / тачскрин по кнопкам [X] CONFIRM / [B] BACK
    local by = my + 288 -- Точное совпадение с draw() (было 296)
    local bh = 46
    local bw = 230
    local bgap = 24
    local bStartX = mx + (mw - (2 * bw + bgap)) / 2

    if y >= by - 8 and y <= by + bh + 8 then
        if x >= bStartX - 10 and x <= bStartX + bw + bgap / 2 then
            betModal.confirm()
            return true
        elseif x > bStartX + bw + bgap / 2 and x <= bStartX + 2 * bw + bgap + 10 then
            audio.play("click")
            betModal.close()
            return true
        end
    end

    return true
end

function betModal.keypressed(key)
    if not betModal.active then return false end

    -- Прямой ввод цифр с клавиатуры и Numpad (0-9)
    local digit = tonumber(key)
    if not digit and key:sub(1, 2) == "kp" then
        digit = tonumber(key:sub(3))
    end
    if digit and digit >= 0 and digit <= 9 then
        betModal.digits[betModal.cursor] = digit
        betModal.clampToBalance()
        betModal.cursor = math.min(10, betModal.cursor + 1)
        audio.play("click")
        return true
    end

    if key == "backspace" then
        betModal.digits[betModal.cursor] = 0
        betModal.cursor = math.max(1, betModal.cursor - 1)
        audio.play("click")
        return true
    elseif key == "left" then
        betModal.cursor = math.max(1, betModal.cursor - 1)
        audio.play("click")
        return true
    elseif key == "right" then
        betModal.cursor = math.min(10, betModal.cursor + 1)
        audio.play("click")
        return true
    elseif key == "up" or key == "w" then
        betModal.digits[betModal.cursor] = (betModal.digits[betModal.cursor] + 1) % 10
        betModal.clampToBalance()
        audio.play("click")
        return true
    elseif key == "down" or key == "s" then
        betModal.digits[betModal.cursor] = (betModal.digits[betModal.cursor] + 9) % 10
        betModal.clampToBalance()
        audio.play("click")
        return true
    -- [L1] /2: клавиши l1, q, h, /
    elseif key == "l1" or key == "q" or key == "h" or key == "/" then
        betModal.setHalf()
        return true
    -- [R1] x2: клавиши r1, e, *
    elseif key == "r1" or key == "e" or key == "*" then
        betModal.setDouble()
        return true
    -- [L2] MIN: клавиши l2, z, lshift, rshift, n, home
    elseif key == "l2" or key == "z" or key == "lshift" or key == "rshift" or key == "n" or key == "home" then
        betModal.setMin()
        return true
    -- [R2] MAX: клавиши r2, c, tab, m, end
    elseif key == "r2" or key == "c" or key == "tab" or key == "m" or key == "end" then
        betModal.setMax()
        return true
    -- Подтверждение: X, A, Enter, Space, Y
    elseif key == "x" or key == "a" or key == "return" or key == "kpenter" or key == "space" or key == "y" then
        betModal.confirm()
        return true
    -- Назад / Отмена: B, Escape
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
    love.graphics.setFont(fonts.lg)
    love.graphics.setColor(1, 0.88, 0.4)
    local title = i18n.t("set_your_bet")
    local tw = fonts.lg:getWidth(title)
    love.graphics.print(title, math.floor(mx + (mw - tw) / 2), my + 20)

    -- Баланс игрока
    love.graphics.setFont(fonts.sm)
    local balStr = string.format("%s: %s", i18n.t("balance"), economy.getBalanceFormatted())
    local stw = fonts.sm:getWidth(balStr)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(balStr, math.floor(mx + (mw - stw) / 2), my + 46)

    -- 10 ячеек для цифр с разделительными точками
    local cellW = 46
    local cellH = 68
    local gap = 6
    local dotW = 12
    local totalGridW = 10 * cellW + 9 * gap + 3 * (dotW + gap)
    local startX = mx + (mw - totalGridW) / 2
    local startY = my + 82

    local pulse = 0.5 + 0.5 * math.sin(betModal.timer * 6)

    local firstSig = 10
    for k = 1, 10 do
        if betModal.digits[k] > 0 then
            firstSig = k
            break
        end
    end

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
        love.graphics.setFont(fonts.xl)
        local dStr = tostring(betModal.digits[i])
        local dw = fonts.xl:getWidth(dStr)
        local dh = fonts.xl:getHeight()
        if isSelected then
            love.graphics.setColor(1, 1, 1)
        else
            if i >= firstSig then
                love.graphics.setColor(1, 0.88, 0.4)
            else
                love.graphics.setColor(0.55, 0.42, 0.25)
            end
        end
        love.graphics.print(dStr, math.floor(cx + (cellW - dw) / 2), math.floor(cy + (cellH - dh) / 2))

        -- Подпись разряда (1B, 100M, 10M, 1M, ...)
        love.graphics.setFont(fonts.xs)
        love.graphics.setColor(0.7, 0.55, 0.3)
        local lbl = digitLabels[i]
        local lw = fonts.xs:getWidth(lbl)
        love.graphics.print(lbl, math.floor(cx + (cellW - lw) / 2), cy + cellH + 18)

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
    love.graphics.setFont(fonts.sm)
    love.graphics.setColor(0.9, 0.8, 0.6)
    local curTotal = betModal.getTotal()
    local limStr = string.format("%s: %s   •   MIN: %s   •   MAX: %s", i18n.t("bet"), economy.format(curTotal), economy.format(betModal.minBet), economy.format(betModal.maxBet))
    local limW = fonts.sm:getWidth(limStr)
    love.graphics.print(limStr, math.floor(mx + (mw - limW) / 2), my + 198)

    -- Панель горячих клавиш: [L1] /2, [L2] MIN, [R2] MAX, [R1] x2
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

        -- Тег кнопки ([L1], [L2], [R2], [R1])
        love.graphics.setColor(0.78, 0.42, 0.14)
        love.graphics.rectangle("fill", bx + 6, by + 6, 44, bh - 12, 3)
        love.graphics.setFont(fonts.sm)
        love.graphics.setColor(1, 0.95, 0.7)
        local tW = fonts.sm:getWidth(tagText)
        local tH = fonts.sm:getHeight()
        local tx = math.floor(bx + 6 + 22 - tW / 2)
        local ty = math.floor(by + bh / 2 - tH / 2)
        love.graphics.print(tagText, tx, ty)

        -- Текст действия (/2, MIN, MAX, x2)
        love.graphics.setFont(fonts.sm)
        love.graphics.setColor(1, 0.88, 0.4)
        local lW = fonts.sm:getWidth(labelText)
        love.graphics.print(labelText, math.floor(bx + 54 + (bw - 60 - lW) / 2), math.floor(by + bh / 2 - 6))
    end

    drawQuickBtn(qStartX, qy, qw, qh, "L1", "/2")
    drawQuickBtn(qStartX + qw + qgap, qy, qw, qh, "L2", "MIN")
    drawQuickBtn(qStartX + 2 * (qw + qgap), qy, qw, qh, "R2", "MAX")
    drawQuickBtn(qStartX + 3 * (qw + qgap), qy, qw, qh, "R1", "x2")

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

    local cTxt = i18n.t("confirm")
    love.graphics.setFont(fonts.md)
    local cwTxt = fonts.md:getWidth(cTxt)
    local chTxt = fonts.md:getHeight()
    local totalBtn1W = 22 + 10 + cwTxt
    local btn1StartX = btn1X + math.floor((bw - totalBtn1W) / 2)
    ui.drawButtonBadge(btn1StartX + 11, by + bh / 2, 11, "X", 1.0, "blue")
    love.graphics.setFont(fonts.md)
    love.graphics.setColor(255/255, 255/255, 255/255)
    love.graphics.print(cTxt, btn1StartX + 32, math.floor(by + (bh - chTxt) / 2))

    -- Кнопка [B] BACK
    local btn2X = bStartX + bw + bgap
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.rectangle("fill", btn2X, by, bw, bh, 6)
    love.graphics.setColor(0.75, 0.16, 0.1)
    love.graphics.rectangle("fill", btn2X + 2, by + 2, bw - 4, bh - 4, 5)
    love.graphics.setColor(0.95, 0.35, 0.25)
    love.graphics.rectangle("line", btn2X + 2, by + 2, bw - 4, bh - 4, 5)

    local bTxt = i18n.t("back")
    love.graphics.setFont(fonts.md)
    local bwTxt = fonts.md:getWidth(bTxt)
    local bhTxt = fonts.md:getHeight()
    local totalBtn2W = 22 + 10 + bwTxt
    local btn2StartX = btn2X + math.floor((bw - totalBtn2W) / 2)
    ui.drawButtonBadge(btn2StartX + 11, by + bh / 2, 11, "B", 1.0, "red")
    love.graphics.setFont(fonts.md)
    love.graphics.setColor(255/255, 255/255, 255/255)
    love.graphics.print(bTxt, btn2StartX + 32, math.floor(by + (bh - bhTxt) / 2))
end

return betModal
