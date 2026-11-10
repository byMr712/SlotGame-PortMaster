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

local symbolStops = {}
for i, sym in ipairs(slots.symbols) do
    if not symbolStops[sym] then symbolStops[sym] = {} end
    table.insert(symbolStops[sym], i)
end

local CELL_H = 120
local NUM_SYMBOLS = #slots.symbols
local STRIP_HEIGHT = NUM_SYMBOLS * CELL_H

slots.reels = {
    { offset = 10 * CELL_H, speed = 0, targetStop = 11, stopped = true, delay = 0, stopping = false },
    { offset = 10 * CELL_H, speed = 0, targetStop = 11, stopped = true, delay = 0, stopping = false },
    { offset = 10 * CELL_H, speed = 0, targetStop = 11, stopped = true, delay = 0, stopping = false }
}

slots.chosen = { "stardrop", "stardrop", "stardrop" }

function slots.resetAttractMode()
    for r = 1, 3 do
        local stop = 11 -- Показ 3 топовых Stardrop по центру для привлечения
        slots.reels[r].targetStop = stop
        slots.reels[r].offset = (stop - 1) * CELL_H
        slots.reels[r].stopped = true
        slots.reels[r].stopping = false
        slots.reels[r].speed = 0
        slots.reels[r].delay = 0
        slots.chosen[r] = slots.symbols[stop]
    end
    slots.lastWin = 0
    slots.winLineTimer = 0
    slots.tension = false
    slots.isSpinning = false
end

function slots.init()
    slots.resetAttractMode()
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

    -- Настройка шансов:
    -- Stardrop (x500): 10/13824 (~1 раз в 1382)
    -- Prism (x100): ~1 раз в 500 спинов (28/13824 -> ~1 раз в 494)
    -- Ancient Fruit (x30): ~1 раз в 200 спинов (69/13824 -> ~1 раз в 200.3)
    -- Cherry (x15): 640/13824 (~1 раз в 21.6)
    local boostedSym = nil
    local boostRoll = math.random() * 13824
    if boostRoll < 9 then
        boostedSym = "stardrop" -- x500 (10/13824)
    elseif boostRoll < (9 + 20) then
        boostedSym = "prism"    -- x100 (28/13824, ~1 раз в 494)
    elseif boostRoll < (9 + 20 + 5) then
        boostedSym = "ancient"  -- x30 (69/13824, ~1 раз в 200)
    elseif boostRoll < (9 + 20 + 5 + 576) then
        boostedSym = "cherry"   -- x15 (640/13824)
    end

    for r = 1, 3 do
        local stop
        if boostedSym and symbolStops[boostedSym] then
            local stops = symbolStops[boostedSym]
            stop = stops[math.random(#stops)]
        else
            stop = math.random(1, NUM_SYMBOLS)
        end
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
    local cornerR = 18

    -- 3. Барабаны
    for r = 1, 3 do
        local rx = startX + (r - 1) * (reelW + 36)

        -- Саспенс-подсветка третьего барабана
        if r == 3 and slots.tension then
            love.graphics.setColor(1, 0.88, 0.2, 0.75)
            love.graphics.rectangle("fill", rx - 4, startY - 4, reelW + 8, reelH + 8, cornerR + 4)
        end

        -- Ниша барабана
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.rectangle("fill", rx, startY, reelW, reelH, cornerR)

        -- Трафарет со скругленными углами и отсечение
        local function reelMask()
            love.graphics.rectangle("fill", rx, startY, reelW, reelH, cornerR)
        end
        love.graphics.stencil(reelMask, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        love.graphics.setScissor(rx, startY, reelW, reelH)

        -- 1. Цилиндрическая лента барабана с градиентом освещения выпуклого барабана
        for sy = 0, reelH - 4, 4 do
            local y = startY + sy
            local norm = (y + 2 - centerY) / (reelH / 2)
            local cosY = math.cos(norm * 1.05)
            local ly = math.max(0.18, math.pow(cosY, 1.4))
            -- Аутентичный кремовый цвет барабана, плавно переходящий в тень сверху и снизу
            local cr = 0.965 * ly
            local cg = 0.937 * (ly * 0.96 + 0.04)
            local cb = 0.878 * (ly * 0.91 + 0.09)
            love.graphics.setColor(cr, cg, cb)
            love.graphics.rectangle("fill", rx, y, reelW, 4)
        end

        -- 2. Боковые тени и фаски металлической ленты (3D объем ленты барабана)
        for dx = 0, 16 do
            local a = math.pow(1 - dx / 16, 1.3) * 0.45
            love.graphics.setColor(0.08, 0.03, 0.01, a)
            love.graphics.rectangle("fill", rx + dx, startY, 1, reelH)
            love.graphics.rectangle("fill", rx + reelW - 1 - dx, startY, 1, reelH)
        end
        -- Латунная окантовка края ленты
        love.graphics.setColor(0.82, 0.62, 0.22, 0.35)
        love.graphics.line(rx + 5, startY, rx + 5, startY + reelH)
        love.graphics.line(rx + reelW - 5, startY, rx + reelW - 5, startY + reelH)

        -- 3. Цилиндрическая проекция непрерывной ленты символов и 3D ребер
        local normOffset = slots.reels[r].offset % STRIP_HEIGHT
        local R = 175
        local maxAngle = 1.03

        -- 3.1 Разделительные литые латунные ребра барабана
        for i = 1, NUM_SYMBOLS do
            local divDist = (i - 0.5) * CELL_H - normOffset
            while divDist < -STRIP_HEIGHT / 2 do divDist = divDist + STRIP_HEIGHT end
            while divDist > STRIP_HEIGHT / 2 do divDist = divDist - STRIP_HEIGHT end

            if math.abs(divDist) <= 200 then
                local theta = (divDist / 180) * maxAngle
                local divY = centerY + R * math.sin(theta)
                local divCos = math.cos(theta)
                local divBright = math.max(0.22, math.pow(divCos, 1.35))
                local ribH = math.max(2, math.floor(5 * divCos))

                -- Нижняя тень ребра
                love.graphics.setColor(0.08, 0.03, 0.01, 0.7 * divBright)
                love.graphics.rectangle("fill", rx + 6, divY + ribH / 2, reelW - 12, 2)

                -- Тело латунной планки
                love.graphics.setColor(0.72 * divBright, 0.45 * divBright, 0.14 * divBright)
                love.graphics.rectangle("fill", rx + 6, divY - ribH / 2, reelW - 12, ribH, 1)

                -- Золотая полированная фаска сверху
                love.graphics.setColor(1.0 * divBright, 0.90 * divBright, 0.55 * divBright)
                love.graphics.line(rx + 8, divY - ribH / 2, rx + reelW - 8, divY - ribH / 2)

                -- Заклепки по бокам ребра
                love.graphics.setColor(1.0 * divBright, 0.92 * divBright, 0.6 * divBright)
                love.graphics.circle("fill", rx + 14, divY, 2)
                love.graphics.circle("fill", rx + reelW - 14, divY, 2)
            end
        end

        -- 3.2 Символы с ракурсным сжатием и освещением цилиндра
        for i = 1, NUM_SYMBOLS do
            local linearDist = (i - 1) * CELL_H - normOffset
            while linearDist < -STRIP_HEIGHT / 2 do linearDist = linearDist + STRIP_HEIGHT end
            while linearDist > STRIP_HEIGHT / 2 do linearDist = linearDist - STRIP_HEIGHT end

            if math.abs(linearDist) <= 200 then
                local theta = (linearDist / 180) * maxAngle
                local projY = centerY + R * math.sin(theta)
                local cosTheta = math.cos(theta)

                -- Сжатие по вертикали и освещенность цилиндра
                local scaleY = math.max(0.48, cosTheta)
                local scaleX = 0.86 + 0.14 * cosTheta
                local brightness = math.max(0.35, math.pow(cosTheta, 1.4))
                local targetSize = 84 * scaleX

                -- Тень символа на цилиндрической поверхности
                sprites.draw(slots.symbols[i], rx + reelW / 2, projY + 4 * scaleY, targetSize, 0.3 * brightness, scaleY, 0.1)
                -- Сам 16-битный спрайт с динамическим ракурсным сжатием
                sprites.draw(slots.symbols[i], rx + reelW / 2, projY, targetSize, 1.0, scaleY, brightness)
            end
        end

        -- 4. Глубокие тени сводов барабанной ниши сверху и снизу (виньетирование кривизны)
        for d = 0, 70, 2 do
            local alpha = math.pow(1 - d / 70, 1.6) * 0.92
            love.graphics.setColor(0.06, 0.02, 0.01, alpha)
            love.graphics.rectangle("fill", rx, startY + d, reelW, 2)
            love.graphics.rectangle("fill", rx, startY + reelH - d - 2, reelW, 2)
        end

        -- 5. Тонкий стеклянный блик на смотровом стекле барабана
        love.graphics.setColor(1, 1, 1, 0.035)
        love.graphics.polygon("fill", rx, startY, rx + 80, startY, rx + reelW, startY + reelH - 80, rx + reelW, startY + reelH)

        -- 6. Латунные фаски проема барабана
        love.graphics.setColor(0.85, 0.65, 0.22, 0.7)
        love.graphics.rectangle("fill", rx, startY, reelW, 2)
        love.graphics.setColor(0.35, 0.18, 0.06, 0.85)
        love.graphics.rectangle("fill", rx, startY + reelH - 2, reelW, 2)

        love.graphics.setScissor()
        love.graphics.setStencilTest()

        -- 7. Внешняя золотая рамка барабана со скругленными углами
        love.graphics.setColor(0.92, 0.74, 0.22, 0.95)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", rx, startY, reelW, reelH, cornerR)
        love.graphics.setColor(1, 0.92, 0.55, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx + 1, startY + 1, reelW - 2, reelH - 2, cornerR - 1)
        love.graphics.setColor(0.35, 0.18, 0.06, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rx - 2, startY - 2, reelW + 4, reelH + 4, cornerR + 2)
        love.graphics.setLineWidth(1)

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
    local font = love.graphics.getFont()
    local cx, cy = 80, 568
    love.graphics.setColor(0.96, 0.78, 0.2)
    love.graphics.circle("fill", cx, cy, 12)
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, 12)
    love.graphics.setLineWidth(1)
    local kw = font and font:getWidth("Y") or 8
    local kh = font and font:getHeight() or 14
    local tx = math.floor(cx - kw / 2)
    local ty = math.floor(cy - kh / 2)
    love.graphics.print("Y", tx, ty)
    love.graphics.print("Y", tx + 1, ty)

    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print(i18n.t("bet") .. ":", 100, 550)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(economy.format(slots.bet), 100, 568)

    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 360, 544, 220, 48, 4)
    love.graphics.setColor(0.65, 0.45, 0.15)
    love.graphics.rectangle("line", 360, 544, 220, 48, 4)
    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print(i18n.t("last_win"), 370, 550)
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
    local font = love.graphics.getFont()
    local cx, cy = bx + 40, 568
    local kw = font and font:getWidth("X") or 8
    local kh = font and font:getHeight() or 14
    local tx = math.floor(cx - kw / 2)
    local ty = math.floor(cy - kh / 2)
    love.graphics.setColor(0.15, 0.05, 0.02, spinAlpha)
    love.graphics.print("X", tx, ty)
    love.graphics.print("X", tx + 1, ty)

    -- Текст SPIN!
    love.graphics.setColor(1, 0.98, 0.92, spinAlpha)
    local spinText = i18n.t("spin") .. "!"
    love.graphics.print(spinText, bx + 70, 560)
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
