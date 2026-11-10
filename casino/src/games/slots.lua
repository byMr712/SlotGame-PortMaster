local slots = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")
local betModal = require("src.core.bet_modal")
local bankruptModal = require("src.core.bankrupt_modal")

slots.bet = 500
slots.lastWin = 0
slots.isSpinning = false
slots.tension = false
slots.winPulse = 0
slots.winLineTimer = 0

-- 24 стопа на барабан (RNG лента: сбалансированное казино-распределение)
slots.symbols = {
    "parsnip", "cherry", "parsnip", "ancient", "parsnip", "prism",
    "parsnip", "cherry", "parsnip", "ancient", "stardrop", "parsnip",
    "parsnip", "cherry", "parsnip", "ancient", "parsnip", "prism",
    "parsnip", "cherry", "parsnip", "ancient", "parsnip", "parsnip"
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
    slots.winLineTimer = 0

    for r = 1, 3 do
        local stop = math.random(1, NUM_SYMBOLS)
        slots.reels[r].targetStop = stop
        slots.chosen[r] = slots.symbols[stop]
        slots.reels[r].stopped = false
        slots.reels[r].settling = false
        slots.reels[r].settleTimer = 0
        slots.reels[r].speed = 350
        slots.reels[r].targetSpeed = 1550
        slots.reels[r].delay = 0.85 + (r - 1) * 0.75
    end

    -- Саспенс: если первые 2 совпали по топ-символам
    if (slots.chosen[1] == slots.chosen[2]) and (slots.chosen[1] == "stardrop" or slots.chosen[1] == "prism") then
        slots.reels[3].delay = 3.2
        slots.tension = true
    end
end

function slots.update(dt)
    if slots.winLineTimer > 0 then
        slots.winLineTimer = math.max(0, slots.winLineTimer - dt)
        slots.winPulse = slots.winPulse + dt * 8
    else
        slots.winPulse = 0
    end

    if not slots.isSpinning then return end

    local allStopped = true
    for r = 1, 3 do
        local reel = slots.reels[r]
        if not reel.stopped then
            allStopped = false

            if reel.settling then
                reel.settleTimer = reel.settleTimer + dt
                local t = reel.settleTimer
                -- Плавный пружинящий отскок при посадке
                local bounce = 16 * math.exp(-10 * t) * math.sin(20 * t)
                reel.offset = reel.baseOffset + bounce
                if t >= 0.35 then
                    reel.offset = reel.baseOffset
                    reel.settling = false
                    reel.stopped = true
                end
            else
                reel.delay = reel.delay - dt
                -- Плавный разгон барабанов в начале спина
                reel.speed = reel.speed + (reel.targetSpeed - reel.speed) * math.min(1, dt * 7)

                if reel.delay <= 0 then
                    local targetOffset = (reel.targetStop - 1) * CELL_H
                    local currentNorm = reel.offset % STRIP_HEIGHT
                    local diff = (targetOffset - currentNorm) % STRIP_HEIGHT

                    if diff > 0 and diff < 36 then
                        reel.baseOffset = reel.offset + diff
                        reel.settling = true
                        reel.settleTimer = 0
                        audio.play("tick")
                    else
                        reel.speed = math.max(350, reel.speed - dt * 2000)
                        reel.offset = reel.offset + reel.speed * dt
                    end
                else
                    reel.offset = reel.offset + reel.speed * dt
                end
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
        elseif s1 == "ancient" then mult = 30
        elseif s1 == "cherry" then mult = 15
        elseif s1 == "parsnip" then mult = 3
        end
    elseif s1 == "cherry" and s2 == "cherry" then
        -- 2 вишни слева направо (барабаны 1 и 2)
        mult = 3
    elseif s1 == "cherry" then
        -- 1 вишня на первом барабане
        mult = 1
    end

    if mult > 0 then
        slots.lastWin = slots.bet * mult
        slots.winPulse = 0.01
        slots.winLineTimer = 3.0
        economy.add(slots.lastWin)
        audio.play("win")
    else
        slots.lastWin = 0
        slots.winLineTimer = 0
        audio.play("fail")
    end

    -- Проверка банкротства или снижение ставки до остатка баланса
    if bankruptModal.check() then
        -- открыто окно банкротства
    elseif slots.bet > economy.getBalance() then
        slots.bet = math.max(1, economy.getBalance())
    end
end

function slots.draw()
    -- 1. Верхняя латунная плашка таблицы выплат (с аутентичными пиксель-арт спрайтами)
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 72, 944, 58, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 72, 944, 58, 4)
    love.graphics.setLineWidth(1)

    -- Элементы таблицы выплат (увеличенные спрайты и значения xMULT)
    local payItems = {
        { sym = "stardrop", mult = "x500", col = {1, 0.88, 0.4} },
        { sym = "prism", mult = "x100", col = {1, 1, 1} },
        { sym = "ancient", mult = "x30", col = {0.4, 0.8, 1} },
        { sym = "cherry", mult = "x15", col = {1, 0.45, 0.45} },
        { sym = "parsnip", mult = "x3", col = {1, 0.75, 0.2} },
    }

    local colW = 944 / 5
    for i, item in ipairs(payItems) do
        local colX = 40 + (i - 0.5) * colW
        sprites.draw(item.sym, colX - 28, 101, 36)
        love.graphics.setColor(item.col)
        love.graphics.print(item.mult, colX + 2, 92, 0, 1.35, 1.35)
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

    -- 4. Линия выплат (показывается мигающей ТОЛЬКО первые 3 секунды после выигрыша, по умолчанию скрыта)
    if slots.winLineTimer > 0 then
        local pulse = math.sin(slots.winPulse) * 0.35 + 0.65
        -- Золотая аура выигрыша
        love.graphics.setColor(1, 0.84, 0.1, pulse * 0.9)
        love.graphics.rectangle("fill", 50, centerY - 4, 924, 8)
        -- Бело-желтая яркая сердцевина
        love.graphics.setColor(1, 1, 0.85, pulse)
        love.graphics.rectangle("fill", 50, centerY - 1, 924, 2)

        -- Маркеры LINE 1 по бокам
        love.graphics.setColor(0.65, 0.12, 0.08, pulse)
        love.graphics.rectangle("fill", 48, centerY - 14, 46, 28, 4)
        love.graphics.rectangle("fill", 930, centerY - 14, 46, 28, 4)
        love.graphics.setColor(1, 0.88, 0.4, pulse)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 48, centerY - 14, 46, 28, 4)
        love.graphics.rectangle("line", 930, centerY - 14, 46, 28, 4)
        love.graphics.setLineWidth(1)
        love.graphics.print("▶ 1", 58, centerY - 8)
        love.graphics.print("1 ◀", 940, centerY - 8)
    end

    -- 5. Нижняя панель управления слотов
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 524, 944, 88, 6)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.rectangle("line", 40, 524, 944, 88, 6)

    -- Информационные плашки: СТАВКА [Y] и ВЫИГРЫШ
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 60, 544, 270, 48, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.rectangle("line", 60, 544, 270, 48, 4)

    -- Желтый значок [Y]
    love.graphics.setColor(0.96, 0.78, 0.2)
    love.graphics.circle("fill", 80, 568, 12)
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 80, 568, 12)
    love.graphics.setLineWidth(1)
    love.graphics.print("Y", 76, 561)

    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print(i18n.t("bet") .. ":", 100, 550)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(economy.format(slots.bet), 100, 568)

    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 360, 544, 220, 48, 4)
    love.graphics.setColor(0.65, 0.45, 0.15)
    love.graphics.rectangle("line", 360, 544, 220, 48, 4)
    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print("LAST WIN", 370, 550)
    if isWin then
        love.graphics.setColor(0.2, 0.95, 0.4)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.print(economy.format(slots.lastWin), 370, 568)

    -- Кнопка СПИН
    local spinAlpha = slots.isSpinning and 0.5 or 1.0
    local bx = 710
    -- Темный внешний контур и тень
    love.graphics.setColor(0.08, 0.03, 0.01, spinAlpha)
    love.graphics.rectangle("fill", bx, 540, 254, 56, 6)

    -- Рубиновый корпус кнопки
    love.graphics.setColor(0.78, 0.16, 0.10, spinAlpha)
    love.graphics.rectangle("fill", bx + 3, 543, 248, 50, 4)

    -- Внутренняя золотисто-светлая фаска блика сверху
    love.graphics.setColor(0.96, 0.45, 0.35, spinAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx + 4, 544, 246, 48, 4)
    love.graphics.setLineWidth(1)

    -- Золотая круглая кнопка геймпада (X)
    love.graphics.setColor(0.95, 0.78, 0.25, spinAlpha)
    love.graphics.circle("fill", bx + 40, 568, 14)
    love.graphics.setColor(0.15, 0.05, 0.02, spinAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", bx + 40, 568, 14)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.15, 0.05, 0.02, spinAlpha)
    love.graphics.print("X", bx + 36, 560)

    -- Текст SPIN!
    love.graphics.setColor(1, 0.98, 0.92, spinAlpha)
    love.graphics.print("SPIN!", bx + 70, 560)
end

function slots.keypressed(key)
    if key == "y" then
        if not slots.isSpinning then
            betModal.open(slots.bet, 100, economy.getBalance(), function(newBet)
                slots.bet = newBet
            end)
        end
    elseif key == "x" or key == "a" or key == "space" or key == "return" then
        slots.spin()
    end
end

function slots.mousepressed(x, y)
    -- Окно ставки [Y]
    if x >= 40 and x <= 345 and y >= 530 and y <= 610 then
        if not slots.isSpinning then
            betModal.open(slots.bet, 100, economy.getBalance(), function(newBet)
                slots.bet = newBet
            end)
        end
        return true
    end

    -- Кнопка SPIN (710, 540, 254, 56)
    if x >= 700 and x <= 970 and y >= 535 and y <= 605 then
        slots.spin()
        return true
    end

    return false
end

return slots
