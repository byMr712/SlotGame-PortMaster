local slots = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")

slots.bet = 500
slots.lastWin = 0
slots.isSpinning = false
slots.tension = false
slots.winPulse = 0

-- 24 стопа на барабан (RNG лента)
slots.symbols = {
    "cherry", "parsnip", "cherry", "ancient", "parsnip", "cherry",
    "prism", "cherry", "ancient", "parsnip", "stardrop", "cherry",
    "ancient", "parsnip", "cherry", "prism", "parsnip", "ancient",
    "cherry", "stardrop", "parsnip", "cherry", "ancient", "prism"
}

local CELL_H = 120
local NUM_SYMBOLS = #slots.symbols
local STRIP_HEIGHT = NUM_SYMBOLS * CELL_H

slots.reels = {
    { offset = 10 * CELL_H, speed = 0, targetStop = 11, stopped = true, delay = 0, stopping = false },
    { offset = 10 * CELL_H, speed = 0, targetStop = 11, stopped = true, delay = 0, stopping = false },
    { offset = 10 * CELL_H, speed = 0, targetStop = 11, stopped = true, delay = 0, stopping = false }
}

slots.chosen = { "stardrop", "stardrop", "stardrop" }

function slots.init()
    for r = 1, 3 do
        local stop = 11 -- Начальный показ: Stardrop по центру
        slots.reels[r].targetStop = stop
        slots.reels[r].offset = (stop - 1) * CELL_H
        slots.reels[r].stopped = true
        slots.reels[r].stopping = false
        slots.chosen[r] = slots.symbols[stop]
    end
end

function slots.spin()
    if slots.isSpinning then return end
    if not economy.spend(slots.bet) then
        audio.play("fail")
        return
    end

    audio.play("click")
    slots.isSpinning = true
    slots.lastWin = 0
    slots.tension = false
    slots.winPulse = 0

    for r = 1, 3 do
        local stop = math.random(1, NUM_SYMBOLS)
        slots.reels[r].targetStop = stop
        slots.chosen[r] = slots.symbols[stop]
        slots.reels[r].stopped = false
        slots.reels[r].stopping = false
        slots.reels[r].speed = 1500
        slots.reels[r].delay = 0.8 + (r - 1) * 0.7
    end

    -- Саспенс: если первые 2 совпали по топ-символам
    if (slots.chosen[1] == slots.chosen[2]) and (slots.chosen[1] == "stardrop" or slots.chosen[1] == "prism") then
        slots.reels[3].delay = 3.2
        slots.tension = true
    end
end

function slots.update(dt)
    if slots.winPulse > 0 then
        slots.winPulse = slots.winPulse + dt * 4
    end

    if not slots.isSpinning then return end

    local allStopped = true
    for r = 1, 3 do
        local reel = slots.reels[r]
        if not reel.stopped then
            allStopped = false
            reel.delay = reel.delay - dt

            if reel.delay <= 0 then
                -- Торможение и точная посадка на целевой стоп
                local targetOffset = (reel.targetStop - 1) * CELL_H
                local currentNorm = reel.offset % STRIP_HEIGHT
                local diff = (targetOffset - currentNorm) % STRIP_HEIGHT

                if diff > 0 and diff < 30 then
                    reel.offset = reel.offset + diff
                    reel.stopped = true
                    reel.speed = 0
                    audio.play("tick")
                else
                    reel.speed = math.max(300, reel.speed - dt * 2500)
                    reel.offset = reel.offset + reel.speed * dt
                end
            else
                reel.offset = reel.offset + reel.speed * dt
            end
        end
    end

    if allStopped then
        slots.isSpinning = false
        slots.tension = false
        slots.evaluateWin()
    end
end

function slots.evaluateWin()
    local s1, s2, s3 = slots.chosen[1], slots.chosen[2], slots.chosen[3]
    local mult = 0

    if s1 == s2 and s2 == s3 then
        if s1 == "stardrop" then mult = 500
        elseif s1 == "prism" then mult = 100
        elseif s1 == "ancient" then mult = 50
        elseif s1 == "parsnip" then mult = 30
        elseif s1 == "cherry" then mult = 20
        end
    else
        local cherries = 0
        for _, s in ipairs(slots.chosen) do
            if s == "cherry" then cherries = cherries + 1 end
        end
        if cherries == 2 then mult = 5
        elseif cherries == 1 then mult = 2
        end
    end

    if mult > 0 then
        slots.lastWin = slots.bet * mult
        slots.winPulse = 0.01
        economy.add(slots.lastWin)
        audio.play("win")
    else
        audio.play("fail")
    end
end

function slots.draw()
    -- 1. Верхняя латунная плашка таблицы выплат (с аутентичными пиксель-арт спрайтами)
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 80, 944, 46, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 80, 944, 46, 4)
    love.graphics.setLineWidth(1)

    -- Элементы таблицы выплат
    local payItems = {
        { sym = "stardrop", mult = "x500", label = "SUPER JACKPOT", col = {1, 0.88, 0.4}, x = 50 },
        { sym = "prism", mult = "x100", label = "SHARD", col = {1, 1, 1}, x = 275 },
        { sym = "ancient", mult = "x50", label = "FRUIT", col = {0.4, 0.8, 1}, x = 475 },
        { sym = "parsnip", mult = "x30", label = "PARSNIP", col = {1, 0.75, 0.2}, x = 655 },
        { sym = "cherry", mult = "x20", label = "CHERRY", col = {1, 0.45, 0.45}, x = 835 },
    }

    for _, item in ipairs(payItems) do
        sprites.draw(item.sym, item.x + 14, 103, 24)
        love.graphics.setColor(item.col)
        love.graphics.print(item.mult, item.x + 32, 96)
    end

    -- 2. Внешняя рама автомата (массивное дерево салуна)
    local reelW = 280
    local reelH = 360
    local startX = 64
    local startY = 142

    love.graphics.setColor(0.10, 0.04, 0.02)
    love.graphics.rectangle("fill", 48, startY - 10, 928, reelH + 20, 6)
    love.graphics.setColor(0.45, 0.22, 0.06)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 48, startY - 10, 928, reelH + 20, 6)
    love.graphics.setLineWidth(1)

    local centerY = startY + reelH / 2

    -- 3. Барабаны
    for r = 1, 3 do
        local rx = startX + (r - 1) * (reelW + 36)

        -- Саспенс-подсветка третьего барабана
        if r == 3 and slots.tension then
            love.graphics.setColor(1, 0.88, 0.2, 0.75)
            love.graphics.rectangle("fill", rx - 4, startY - 4, reelW + 8, reelH + 8, 4)
        end

        -- Ниша барабана
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.rectangle("fill", rx, startY, reelW, reelH, 4)

        -- Ограничение отрисовки окном барабана
        love.graphics.setScissor(rx, startY, reelW, reelH)

        -- Чистый аутентичный кремовый фон барабана (как в Stardew Valley)
        love.graphics.setColor(0.965, 0.937, 0.878)
        love.graphics.rectangle("fill", rx, startY, reelW, reelH)

        -- Непрерывная лента символов
        local normOffset = slots.reels[r].offset % STRIP_HEIGHT

        for i = 1, NUM_SYMBOLS do
            local itemY = centerY + (i - 1) * CELL_H - normOffset
            -- Зацикливание координат для непрерывного скролла
            while itemY < startY - CELL_H do itemY = itemY + STRIP_HEIGHT end
            while itemY > startY + reelH + CELL_H do itemY = itemY - STRIP_HEIGHT end

            if itemY > startY - CELL_H and itemY < startY + reelH + CELL_H then
                -- Разделительное латунное ребро ячейки
                love.graphics.setColor(0.85, 0.78, 0.65)
                love.graphics.line(rx + 6, itemY - CELL_H / 2, rx + reelW - 6, itemY - CELL_H / 2)
                love.graphics.setColor(1, 1, 1, 0.6)
                love.graphics.line(rx + 6, itemY - CELL_H / 2 + 1, rx + reelW - 6, itemY - CELL_H / 2 + 1)

                -- Тень символа
                sprites.draw(slots.symbols[i], rx + reelW / 2, itemY + 3, 84, 0.25)
                -- Сам четкий 16-битный спрайт
                sprites.draw(slots.symbols[i], rx + reelW / 2, itemY, 84, 1.0)
            end
        end

        -- Мягкое виньетирование свода цилиндра сверху и снизу (25px, без черного пятна)
        for d = 0, 25, 3 do
            local alpha = (1 - d / 25) * 0.7
            love.graphics.setColor(0.08, 0.04, 0.01, alpha)
            love.graphics.rectangle("fill", rx, startY + d, reelW, 3)
            love.graphics.rectangle("fill", rx, startY + reelH - d - 3, reelW, 3)
        end

        love.graphics.setScissor()

        -- Разделительные латунные стойки между барабанами
        if r < 3 then
            local colX = rx + reelW + 10
            love.graphics.setColor(0.15, 0.06, 0.02)
            love.graphics.rectangle("fill", colX, startY - 4, 16, reelH + 8, 2)
            love.graphics.setColor(0.85, 0.6, 0.18)
            love.graphics.rectangle("fill", colX + 3, startY, 10, reelH, 2)
            love.graphics.setColor(1, 0.92, 0.6)
            love.graphics.line(colX + 4, startY, colX + 4, startY + reelH)
        end
    end

    -- 4. Линия выплат (Payline 1)
    local isWin = (slots.lastWin > 0)
    if isWin then
        local pulse = math.sin(slots.winPulse) * 0.3 + 0.7
        love.graphics.setColor(1, 0.88, 0.2, pulse)
        love.graphics.rectangle("fill", 50, centerY - 3, 924, 6)
    else
        love.graphics.setColor(0.85, 0.15, 0.1, 0.65)
        love.graphics.rectangle("fill", 50, centerY - 2, 924, 4)
        love.graphics.setColor(1, 0.88, 0.4, 0.75)
        love.graphics.rectangle("line", 50, centerY - 2, 924, 4)
    end

    -- Маркеры LINE 1 по бокам
    love.graphics.setColor(0.65, 0.12, 0.08)
    love.graphics.rectangle("fill", 48, centerY - 14, 46, 28, 4)
    love.graphics.rectangle("fill", 930, centerY - 14, 46, 28, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 48, centerY - 14, 46, 28, 4)
    love.graphics.rectangle("line", 930, centerY - 14, 46, 28, 4)
    love.graphics.setLineWidth(1)
    love.graphics.print("▶ 1", 58, centerY - 8)
    love.graphics.print("1 ◀", 940, centerY - 8)

    -- 5. Нижняя панель управления слотов
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 524, 944, 88, 6)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.rectangle("line", 40, 524, 944, 88, 6)

    -- Кнопки ставок с тактильными D-Pad/кнопочными колпачками
    local betBtns = {
        { dir = "▼", label = "-100", x = 52, w = 64, isKey = false },
        { dir = "▲", label = "+100", x = 120, w = 64, isKey = false },
        { dir = "►", label = "+1K",  x = 188, w = 64, isKey = false },
        { dir = "Y", label = "MAX",  x = 256, w = 68, isKey = true },
    }
    for _, btn in ipairs(betBtns) do
        -- Тень
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.rectangle("fill", btn.x, 544, btn.w, 48, 4)
        -- Корпус кнопки
        love.graphics.setColor(0.65, 0.30, 0.10)
        love.graphics.rectangle("fill", btn.x + 2, 546, btn.w - 4, 44, 3)
        -- Фаска
        love.graphics.setColor(0.85, 0.45, 0.18)
        love.graphics.rectangle("line", btn.x + 2, 546, btn.w - 4, 44, 3)

        -- Колпачок D-pad или круглая кнопка Y
        if btn.isKey then
            love.graphics.setColor(0.95, 0.78, 0.20)
            love.graphics.circle("fill", btn.x + 16, 568, 9)
            love.graphics.setColor(0.15, 0.05, 0.02)
            love.graphics.print(btn.dir, btn.x + 12, 561)
        else
            love.graphics.setColor(0.18, 0.08, 0.04)
            love.graphics.rectangle("fill", btn.x + 6, 558, 18, 20, 2)
            love.graphics.setColor(0.78, 0.52, 0.12)
            love.graphics.rectangle("line", btn.x + 6, 558, 18, 20, 2)
            love.graphics.setColor(1, 0.88, 0.4)
            love.graphics.print(btn.dir, btn.x + 10, 561)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(btn.label, btn.x + 28, 561)
    end

    -- Информационные плашки: СТАВКА и ВЫИГРЫШ
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 335, 544, 180, 48, 4)
    love.graphics.setColor(0.65, 0.45, 0.15)
    love.graphics.rectangle("line", 335, 544, 180, 48, 4)
    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print("BET", 345, 550)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(economy.format(slots.bet), 345, 568)

    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 530, 544, 180, 48, 4)
    love.graphics.setColor(0.65, 0.45, 0.15)
    love.graphics.rectangle("line", 530, 544, 180, 48, 4)
    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print("WIN", 540, 550)
    if isWin then
        love.graphics.setColor(0.2, 0.95, 0.4)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.print(economy.format(slots.lastWin), 540, 568)

    -- Кнопка СПИН
    local spinAlpha = slots.isSpinning and 0.5 or 1.0
    -- Темный внешний контур и тень
    love.graphics.setColor(0.08, 0.03, 0.01, spinAlpha)
    love.graphics.rectangle("fill", 730, 540, 234, 56, 6)

    -- Рубиновый корпус кнопки
    love.graphics.setColor(0.78, 0.16, 0.10, spinAlpha)
    love.graphics.rectangle("fill", 733, 543, 228, 50, 4)

    -- Внутренняя золотисто-светлая фаска блика сверху
    love.graphics.setColor(0.96, 0.45, 0.35, spinAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 734, 544, 226, 48, 4)
    love.graphics.setLineWidth(1)

    -- Золотая круглая кнопка геймпада (X)
    love.graphics.setColor(0.95, 0.78, 0.25, spinAlpha)
    love.graphics.circle("fill", 800, 568, 14)
    love.graphics.setColor(0.15, 0.05, 0.02, spinAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 800, 568, 14)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.15, 0.05, 0.02, spinAlpha)
    love.graphics.print("X", 796, 560)

    -- Текст SPIN!
    love.graphics.setColor(1, 0.98, 0.92, spinAlpha)
    love.graphics.print("SPIN!", 830, 560)
end

function slots.keypressed(key)
    if key == "up" then
        slots.bet = slots.bet + 100
        audio.play("click")
    elseif key == "down" then
        slots.bet = math.max(100, slots.bet - 100)
        audio.play("click")
    elseif key == "right" then
        slots.bet = slots.bet + 1000
        audio.play("click")
    elseif key == "left" then
        slots.bet = math.max(100, slots.bet - 1000)
        audio.play("click")
    elseif key == "y" then
        slots.bet = economy.getBalance()
        audio.play("coin")
    elseif key == "x" or key == "a" or key == "space" or key == "return" then
        slots.spin()
    end
end

return slots
