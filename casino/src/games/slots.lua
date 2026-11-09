local slots = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")

slots.bet = 500
slots.lastWin = 0
slots.isSpinning = false
slots.tension = false

-- 24 стопа на барабан
slots.symbols = { "cherry", "parsnip", "cherry", "ancient", "parsnip", "cherry",
                 "prism", "cherry", "ancient", "parsnip", "stardrop", "cherry",
                 "ancient", "parsnip", "cherry", "prism", "parsnip", "ancient",
                 "cherry", "stardrop", "parsnip", "cherry", "ancient", "prism" }

slots.reels = {
    { offset = 0, speed = 0, targetStop = 1, stopped = true, delay = 0 },
    { offset = 0, speed = 0, targetStop = 1, stopped = true, delay = 0 },
    { offset = 0, speed = 0, targetStop = 1, stopped = true, delay = 0 }
}

slots.chosen = { "stardrop", "stardrop", "stardrop" }
local CELL_H = 110

function slots.init()
    slots.reels[1].offset = -10 * CELL_H
    slots.reels[2].offset = -10 * CELL_H
    slots.reels[3].offset = -10 * CELL_H
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

    -- Честный RNG выбор целевого стопа
    for r = 1, 3 do
        local stop = math.random(1, #slots.symbols)
        slots.reels[r].targetStop = stop
        slots.chosen[r] = slots.symbols[stop]
        slots.reels[r].stopped = false
        slots.reels[r].speed = 1200 + r * 150
        slots.reels[r].delay = 0.8 + (r - 1) * 0.8
    end

    -- Саспенс: если первые 2 барабана совпали по Stardrop или Prism
    if (slots.chosen[1] == slots.chosen[2]) and (slots.chosen[1] == "stardrop" or slots.chosen[1] == "prism") then
        slots.reels[3].delay = 3.5 -- 3-й барабан крутится долго
        slots.tension = true
    end
end

function slots.update(dt)
    if not slots.isSpinning then return end

    local allStopped = true
    for r = 1, 3 do
        local reel = slots.reels[r]
        if not reel.stopped then
            allStopped = false
            reel.delay = reel.delay - dt

            if reel.delay <= 0 then
                -- Торможение и центровка на целевой стоп
                local targetY = -(reel.targetStop * CELL_H)
                local diff = targetY - (reel.offset % (#slots.symbols * CELL_H))
                if math.abs(diff) < 15 then
                    reel.offset = targetY
                    reel.stopped = true
                    audio.play("tick")
                else
                    reel.offset = reel.offset - reel.speed * dt * 0.4
                end
            else
                reel.offset = reel.offset - reel.speed * dt
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
        economy.add(slots.lastWin)
        audio.play("win")
    else
        audio.play("fail")
    end
end

-- Отрисовка символов в стиле Stardew Valley
local function drawSymbol(sym, cx, cy, size)
    local r = size / 2
    if sym == "stardrop" then
        -- Звездная капля: пурпурный каплевидный плод с зеленым листом
        love.graphics.setColor(0.55, 0.17, 0.65)
        love.graphics.circle("fill", cx, cy + 4, r * 0.8)
        love.graphics.setColor(0.82, 0.38, 0.95)
        love.graphics.circle("fill", cx, cy, r * 0.6)
        love.graphics.setColor(0.2, 0.6, 0.15)
        love.graphics.rectangle("fill", cx - 4, cy - r * 0.9, 8, 12)
        -- Золотые искры
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.rectangle("fill", cx - r * 0.8, cy - r * 0.5, 6, 6)
        love.graphics.rectangle("fill", cx + r * 0.6, cy - r * 0.5, 6, 6)
    elseif sym == "prism" then
        -- Радужный призматический осколок
        local colors = { {1,0.2,0.3}, {1,0.6,0.1}, {1,0.9,0.2}, {0.2,0.85,0.4}, {0.15,0.7,1}, {0.6,0.3,0.9} }
        for i, col in ipairs(colors) do
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.rectangle("fill", cx - r * 0.7, cy - r * 0.8 + (i - 1) * 11, r * 1.4, 11)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", cx - 4, cy - r * 0.6, 8, 16)
    elseif sym == "ancient" then
        -- Древний синий плод
        love.graphics.setColor(0.08, 0.27, 0.49)
        love.graphics.circle("fill", cx, cy + 4, r * 0.8)
        love.graphics.setColor(0.2, 0.55, 0.9)
        love.graphics.circle("fill", cx, cy, r * 0.6)
        love.graphics.setColor(0.18, 0.55, 0.15)
        love.graphics.rectangle("fill", cx - 4, cy - r * 0.9, 8, 10)
    elseif sym == "parsnip" then
        -- Золотистый пастернак
        love.graphics.setColor(0.95, 0.68, 0.15)
        love.graphics.polygon("fill", cx - r * 0.6, cy - r * 0.4, cx + r * 0.6, cy - r * 0.4, cx, cy + r * 0.9)
        love.graphics.setColor(0.2, 0.6, 0.15)
        love.graphics.rectangle("fill", cx - 5, cy - r * 0.85, 10, 14)
    else -- cherry
        -- Двойная вишня
        love.graphics.setColor(0.85, 0.12, 0.15)
        love.graphics.circle("fill", cx - 14, cy + 6, 16)
        love.graphics.circle("fill", cx + 14, cy + 6, 16)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", cx - 18, cy + 2, 4)
        love.graphics.circle("fill", cx + 10, cy + 2, 4)
        love.graphics.setColor(0.2, 0.6, 0.15)
        love.graphics.setLineWidth(3)
        love.graphics.line(cx - 14, cy - 6, cx, cy - 24)
        love.graphics.line(cx + 14, cy - 6, cx, cy - 24)
        love.graphics.setLineWidth(1)
    end
end

-- Отрисовка литого металлического разделительного ребра барабана
local function drawRib(rx, ry, rw)
    love.graphics.setColor(0.1, 0.04, 0.01, 0.8)
    love.graphics.rectangle("fill", rx, ry - 3, rw, 6)
    love.graphics.setColor(0.78, 0.55, 0.16)
    love.graphics.rectangle("fill", rx + 2, ry - 2, rw - 4, 4)
    love.graphics.setColor(1, 0.92, 0.6)
    love.graphics.line(rx + 2, ry - 2, rx + rw - 2, ry - 2)
    -- Заклепки по краям
    love.graphics.setColor(1, 0.95, 0.7)
    love.graphics.rectangle("fill", rx + 8, ry - 1, 3, 3)
    love.graphics.rectangle("fill", rx + rw - 11, ry - 1, 3, 3)
end

function slots.draw()
    -- Таблица выплат сверху
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 80, 944, 46, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 40, 80, 944, 46, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("★ x500 STARDROP", 60, 96)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("x100 PRISM", 320, 96)
    love.graphics.setColor(0.4, 0.8, 1)
    love.graphics.print("x50 FRUIT", 520, 96)
    love.graphics.setColor(1, 0.75, 0.2)
    love.graphics.print("x30 PARSNIP", 700, 96)
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("x20 CHERRY", 850, 96)

    -- Корпус 3 барабанов
    local reelW = 276
    local reelH = 350
    local startX = 64
    local startY = 145

    -- Внешняя массивная рама автомата
    love.graphics.setColor(0.10, 0.04, 0.02)
    love.graphics.rectangle("fill", 48, startY - 10, 928, reelH + 20, 6)
    love.graphics.setColor(0.45, 0.22, 0.06)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 48, startY - 10, 928, reelH + 20, 6)
    love.graphics.setLineWidth(1)

    for r = 1, 3 do
        local rx = startX + (r - 1) * (reelW + 36)
        
        -- Подсветка саспенса для третьего барабана
        if r == 3 and slots.tension then
            love.graphics.setColor(1, 0.88, 0.2, 0.8)
            love.graphics.rectangle("fill", rx - 6, startY - 6, reelW + 12, reelH + 12, 6)
        end

        -- Внутренняя ниша барабана
        love.graphics.setColor(0.06, 0.02, 0.01)
        love.graphics.rectangle("fill", rx, startY, reelW, reelH, 6)

        -- Ножницы обрезки для вращающегося цилиндра
        love.graphics.setScissor(rx + 2, startY + 2, reelW - 4, reelH - 4)

        -- 1. Эмалированная поверхность цилиндра (горизонтальный цилиндрический блик)
        love.graphics.setColor(0.98, 0.96, 0.92)
        love.graphics.rectangle("fill", rx + 2, startY + 2, reelW - 4, reelH - 4)
        
        -- Боковые тени закругления цилиндра
        love.graphics.setColor(0.18, 0.08, 0.03, 0.85)
        love.graphics.rectangle("fill", rx + 2, startY + 2, 18, reelH - 4)
        love.graphics.rectangle("fill", rx + reelW - 20, startY + 2, 18, reelH - 4)
        love.graphics.setColor(0.5, 0.35, 0.2, 0.4)
        love.graphics.rectangle("fill", rx + 20, startY + 2, 30, reelH - 4)
        love.graphics.rectangle("fill", rx + reelW - 50, startY + 2, 30, reelH - 4)

        -- 2. Непрерывная лента с символами и литыми ребрами
        local currentY = startY + 175 + (slots.reels[r].offset % (#slots.symbols * CELL_H))
        for i, sym in ipairs(slots.symbols) do
            local sy = currentY + (i - 1) * CELL_H
            if sy > startY - CELL_H and sy < startY + reelH + CELL_H then
                local centerY = startY + reelH / 2
                local dist = math.abs(sy - centerY)
                local scaleY = math.cos(math.min(1.2, dist / 220))
                
                -- Литое разделительное ребро барабана
                drawRib(rx + 6, sy - CELL_H / 2, reelW - 12)

                -- Тень символа на цилиндре
                drawSymbol(sym, rx + reelW / 2, sy + 3, 76 * scaleY)
                -- Сам символ
                drawSymbol(sym, rx + reelW / 2, sy, 76 * scaleY)
            end
        end

        -- 3. Верхнее и нижнее стеклянное затемнение цилиндра (3D эффект свода)
        for d = 0, 70, 5 do
            local alpha = (1 - d / 70) * 0.95
            love.graphics.setColor(0.04, 0.02, 0.01, alpha)
            love.graphics.rectangle("fill", rx + 2, startY + d, reelW - 4, 6)
            love.graphics.rectangle("fill", rx + 2, startY + reelH - d - 6, reelW - 4, 6)
        end

        love.graphics.setScissor()

        -- Латунные колонны-разделители между барабанами
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

    -- Аутентичная гравированная рубиновая линия выплат
    love.graphics.setColor(0.85, 0.15, 0.1, 0.6)
    love.graphics.rectangle("fill", 50, startY + reelH / 2 - 2, 924, 4)
    love.graphics.setColor(1, 0.88, 0.4, 0.8)
    love.graphics.rectangle("line", 50, startY + reelH / 2 - 2, 924, 4)

    -- Маркеры PAYLINE 1 по бокам
    love.graphics.setColor(0.6, 0.1, 0.06)
    love.graphics.rectangle("fill", 50, startY + reelH / 2 - 14, 34, 28, 4)
    love.graphics.rectangle("fill", 940, startY + reelH / 2 - 14, 34, 28, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.rectangle("line", 50, startY + reelH / 2 - 14, 34, 28, 4)
    love.graphics.rectangle("line", 940, startY + reelH / 2 - 14, 34, 28, 4)
    love.graphics.print("▶", 62, startY + reelH / 2 - 8)
    love.graphics.print("◀", 952, startY + reelH / 2 - 8)

    -- Нижняя панель слотов
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 520, 944, 90, 6)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.rectangle("line", 40, 520, 944, 90, 6)

    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(string.format("%s: %s", i18n.t("bet"), economy.format(slots.bet)), 60, 545)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("%s: +%s", i18n.t("win"), economy.format(slots.lastWin)), 60, 575)

    -- Кнопка СПИН
    love.graphics.setColor(0.7, 0.15, 0.1)
    love.graphics.rectangle("fill", 720, 535, 240, 60, 6)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.rectangle("line", 720, 535, 240, 60, 6)
    love.graphics.print(string.format("[X] %s", i18n.t("spin")), 760, 555)
end

function slots.keypressed(key)
    if key == "up" then
        slots.bet = slots.bet + 100
        audio.play("click")
    elseif key == "down" then
        slots.bet = math.max(100, slots.bet - 100)
        audio.play("click")
    elseif key == "y" then
        slots.bet = economy.getBalance()
        audio.play("coin")
    elseif key == "x" or key == "a" or key == "space" or key == "return" then
        slots.spin()
    end
end

return slots
