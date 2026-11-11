local slots = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")
local fonts = require("src.core.fonts")
local ui = require("src.core.ui")
local betModal = require("src.core.bet_modal")
local bankruptModal = require("src.core.bankrupt_modal")

slots.bet = 500
slots.lastWin = 0
slots.isSpinning = false
slots.tension = false
slots.winPulse = 0
slots.winLineTimer = 0

local reelW = 286
local reelH = 360
local reelBgImage = nil
local reelShadowImage = nil
local pillarImage = nil

local function initReelImages()
    if reelBgImage or not love or not love.image or not love.graphics then return end

    -- 1. Цилиндрическая эмалированная лента барабана (CPU-backed ImageData)
    local bgData = love.image.newImageData(reelW, reelH)
    for x = 0, reelW - 1 do
        local nx = x / (reelW - 1)
        local u = math.abs(nx - 0.5) * 2 -- 0 (центр) .. 1 (край)
        local r, g, b
        if u < 0.65 then
            local t = u / 0.65
            r = 1.0 * (1 - t) + 0.98 * t
            g = 1.0 * (1 - t) + 0.95 * t
            b = 1.0 * (1 - t) + 0.88 * t
        elseif u < 0.88 then
            local t = (u - 0.65) / 0.23
            r = 0.98 * (1 - t) + 0.61 * t
            g = 0.95 * (1 - t) + 0.50 * t
            b = 0.88 * (1 - t) + 0.35 * t
        else
            local t = (u - 0.88) / 0.12
            r = 0.61 * (1 - t) + 0.11 * t
            g = 0.50 * (1 - t) + 0.05 * t
            b = 0.35 * (1 - t) + 0.02 * t
        end
        if x == 5 or x == reelW - 6 then
            r, g, b = 0.82, 0.62, 0.22
        end
        for y = 0, reelH - 1 do
            bgData:setPixel(x, y, r, g, b, 1)
        end
    end
    reelBgImage = love.graphics.newImage(bgData)

    -- 2. Глубокие тени сводов барабанной ниши сверху и снизу (CPU-backed ImageData)
    local sData = love.image.newImageData(reelW, reelH)
    for y = 0, reelH - 1 do
        local a = 0
        if y < 95 then
            a = math.pow(1 - y / 95, 1.45) * 0.98
        elseif y >= reelH - 95 then
            a = math.pow(1 - (reelH - 1 - y) / 95, 1.45) * 0.98
        end
        for x = 0, reelW - 1 do
            if y <= 1 then
                sData:setPixel(x, y, 0.85, 0.65, 0.22, 0.7)
            elseif y >= reelH - 2 then
                sData:setPixel(x, y, 0.35, 0.18, 0.06, 0.85)
            else
                local glareA = 0
                if x >= y * 0.7 - 20 and x <= y * 0.7 + 60 then
                    glareA = 0.045
                end
                if a > 0 then
                    sData:setPixel(x, y, 0.04, 0.02, 0.01, a)
                elseif glareA > 0 then
                    sData:setPixel(x, y, 1, 1, 1, glareA)
                else
                    sData:setPixel(x, y, 0, 0, 0, 0)
                end
            end
        end
    end
    reelShadowImage = love.graphics.newImage(sData)

    -- 3. Вертикальная литая латунная колонна-стойка (CPU-backed ImageData, 14x360)
    local pw = 14
    local pData = love.image.newImageData(pw, reelH)
    for px = 0, pw - 1 do
        local u = px / (pw - 1)
        local cr, cg, cb
        if u < 0.2 then
            local t = u / 0.2
            cr = (42 * (1 - t) + 110 * t) / 255
            cg = (18 * (1 - t) + 59 * t) / 255
            cb = (4 * (1 - t) + 8 * t) / 255
        elseif u < 0.55 then
            local t = (u - 0.2) / 0.35
            cr = (110 * (1 - t) + 255 * t) / 255
            cg = (59 * (1 - t) + 234 * t) / 255
            cb = (8 * (1 - t) + 163 * t) / 255
        else
            local t = (u - 0.55) / 0.45
            cr = (255 * (1 - t) + 42 * t) / 255
            cg = (234 * (1 - t) + 18 * t) / 255
            cb = (163 * (1 - t) + 4 * t) / 255
        end
        for py = 0, reelH - 1 do
            if py <= 2 then
                pData:setPixel(px, py, 1, 0.92, 0.64, 1)
            elseif py >= reelH - 3 then
                pData:setPixel(px, py, 0.2, 0.08, 0.02, 1)
            elseif (py % 24 == 0 or py % 24 == 1) and px >= 3 and px <= pw - 4 then
                pData:setPixel(px, py, 1, 0.92, 0.6, 0.8)
            else
                pData:setPixel(px, py, cr, cg, cb, 1)
            end
        end
    end
    pillarImage = love.graphics.newImage(pData)
end

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
    initReelImages()

    -- 1. Верхняя латунная плашка таблицы выплат (с аутентичными пиксель-арт спрайтами)
    ui.drawBrassPlaque(28, 92, 968, 60, 4)

    -- Элементы таблицы выплат (увеличенные спрайты и значения xMULT)
    local payItems = {
        { sym = "stardrop", mult = "x500", col = {1, 0.88, 0.4} },
        { sym = "prism", mult = "x100", col = {1, 0.98, 0.92} },
        { sym = "ancient", mult = "x30", col = {0.38, 0.65, 0.98} },
        { sym = "cherry", mult = "x15", col = {1, 0.42, 0.42} },
        { sym = "parsnip", mult = "x3", col = {0.96, 0.69, 0.15} },
    }

    local payFont = fonts.md
    love.graphics.setFont(payFont)
    local colW = 968 / 5
    for i, item in ipairs(payItems) do
        local colX = 28 + (i - 0.5) * colW
        sprites.draw(item.sym, colX - 28, 122, 34)
        love.graphics.setColor(item.col)
        love.graphics.print(item.mult, colX + 4, 116)
    end

    -- 2. Внешняя рама автомата (массивное дерево салуна и ниша барабанов)
    ui.drawBrassPlaque(28, 166, 968, 462, 6)

    -- Внутренняя темная ниша барабанов
    love.graphics.setColor(13/255, 5/255, 2/255, 1)
    love.graphics.rectangle("fill", 40, 178, 944, 438, 12)
    love.graphics.setColor(20/255, 7/255, 2/255, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 40, 178, 944, 438, 12)
    love.graphics.setLineWidth(1)

    local startY = 217
    local centerY = startY + reelH / 2
    local cornerR = 18

    local reelPositions = { 42, 368, 694 }
    local pillarPositions = { 342, 668 }

    -- 3. Барабаны
    for r = 1, 3 do
        local rx = reelPositions[r]

        -- Саспенс-подсветка третьего барабана
        if r == 3 and slots.tension then
            local pulse = math.sin(love.timer.getTime() * 16) * 0.25 + 0.75
            love.graphics.setColor(1, 0.88, 0.2, pulse)
            love.graphics.setLineWidth(6)
            love.graphics.rectangle("line", rx - 3, startY - 3, reelW + 6, reelH + 6, cornerR + 2)
            love.graphics.setLineWidth(1)
        end

        -- Ниша барабана
        love.graphics.setColor(0.05, 0.02, 0.01)
        love.graphics.rectangle("fill", rx, startY, reelW, reelH, cornerR)

        -- Трафарет со скругленными углами и отсечение
        local function reelMask()
            love.graphics.rectangle("fill", rx, startY, reelW, reelH, cornerR)
        end
        love.graphics.stencil(reelMask, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        -- 1. Цилиндрическая эмалированная металлическая лента
        if reelBgImage then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(reelBgImage, rx, startY)
        end

        -- 2. Цилиндрическая проекция ленты символов и 3D латунных ребер
        local normOffset = slots.reels[r].offset % STRIP_HEIGHT
        local R = 175
        local maxAngle = 1.05

        -- 2.1 Разделительные литые латунные ребра барабана
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

        -- 2.2 Символы с динамическим затемнением цилиндра
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
                local distFromCenter = math.abs(projY - centerY)
                -- Глубокое аутентичное затемнение в тень сверху и снизу
                local brightness = math.max(0.24, 1.0 - math.pow(distFromCenter / 125, 1.5) * 0.76)
                local targetSize = 84 * scaleX

                -- Тень символа на цилиндрической поверхности
                sprites.draw(slots.symbols[i], rx + reelW / 2, projY + 4 * scaleY, targetSize, 0.35 * brightness, scaleY, 0.08)
                -- Сам 16-битный спрайт с динамическим ракурсным сжатием и затемнением
                sprites.draw(slots.symbols[i], rx + reelW / 2, projY, targetSize, 1.0, scaleY, brightness)
            end
        end

        -- 3. Верхняя и нижняя глубокие цилиндрические тени смотрового стекла
        if reelShadowImage then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(reelShadowImage, rx, startY)
        end

        love.graphics.setStencilTest()

        -- 4. Внешняя золотая рамка барабана со скругленными углами
        -- Темный контур
        love.graphics.setColor(92/255, 40/255, 14/255, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx - 1, startY - 1, reelW + 2, reelH + 2, cornerR + 1)

        -- Основная золотая рамка #d4af37
        love.graphics.setColor(212/255, 175/255, 55/255, 1)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", rx, startY, reelW, reelH, cornerR)

        -- Внутренний золотистый блик
        love.graphics.setColor(255/255, 240/255, 153/255, 0.75)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", rx + 2, startY + 2, reelW - 4, reelH - 4, cornerR - 2)
        love.graphics.setLineWidth(1)
    end

    -- 3.3 Литые латунные вертикальные колонны-стойки между барабанами
    for _, px in ipairs(pillarPositions) do
        -- Боковые тени
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", px - 3, startY, 3, reelH)
        love.graphics.rectangle("fill", px + 14, startY, 3, reelH)

        if pillarImage then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(pillarImage, px, startY)
        end
    end

    -- 4. Линия выплат (показывается мигающей ТОЛЬКО первые 3 секунды после выигрыша, по умолчанию скрыта)
    if slots.winLineTimer > 0 then
        local pulse = math.sin(slots.winPulse) * 0.35 + 0.65
        -- Золотая аура выигрыша
        love.graphics.setColor(1, 0.84, 0.1, pulse * 0.9)
        love.graphics.rectangle("fill", 42, centerY - 4, 940, 8)
        -- Бело-желтая яркая сердцевина
        love.graphics.setColor(1, 1, 0.85, pulse)
        love.graphics.rectangle("fill", 42, centerY - 1, 940, 2)

        -- Маркеры LINE 1 по бокам
        love.graphics.setColor(0.65, 0.12, 0.08, pulse)
        love.graphics.rectangle("fill", 42, centerY - 14, 46, 28, 4)
        love.graphics.rectangle("fill", 936, centerY - 14, 46, 28, 4)
        love.graphics.setColor(1, 0.88, 0.4, pulse)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 42, centerY - 14, 46, 28, 4)
        love.graphics.rectangle("line", 936, centerY - 14, 46, 28, 4)
        love.graphics.setLineWidth(1)
        love.graphics.setFont(fonts.xs)
        love.graphics.print("▶ 1", 50, centerY - 6)
        love.graphics.print("1 ◀", 944, centerY - 6)
    end

    -- 5. Нижняя панель управления слотов
    ui.drawBrassPlaque(28, 644, 968, 68, 4)

    -- Плашка СТАВКА [Y]
    local betX = 44
    local betY = 652
    local betW = 210
    local betH = 52
    love.graphics.setColor(27/255, 10/255, 4/255, 1)
    love.graphics.rectangle("fill", betX, betY, betW, betH, 4)
    love.graphics.setColor(120/255, 79/255, 24/255, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", betX, betY, betW, betH, 4)
    love.graphics.setLineWidth(1)

    -- Желтый значок [Y]
    ui.drawButtonBadge(betX + 24, betY + betH / 2, 13, "Y")

    -- Текст СТАВКА и сумма
    love.graphics.setFont(fonts.xs)
    love.graphics.setColor(255/255, 234/255, 173/255, 1)
    love.graphics.print(i18n.t("bet") .. ":", betX + 48, betY + 10)
    love.graphics.setFont(fonts.md)
    love.graphics.setColor(1, 0.88, 0.4, 1)
    love.graphics.print(economy.format(slots.bet), betX + 48, betY + 26)

    -- Плашка ВЫИГРЫШ
    local winX = 380
    local winY = 652
    local winW = 220
    local winH = 52
    love.graphics.setColor(27/255, 10/255, 4/255, 1)
    love.graphics.rectangle("fill", winX, winY, winW, winH, 4)
    love.graphics.setColor(92/255, 40/255, 14/255, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", winX, winY, winW, winH, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fonts.xs)
    love.graphics.setColor(255/255, 234/255, 173/255, 1)
    local lwLabel = i18n.t("last_win") .. ":"
    local lwlw = fonts.xs:getWidth(lwLabel)
    love.graphics.print(lwLabel, math.floor(winX + (winW - lwlw) / 2), winY + 10)

    love.graphics.setFont(fonts.md)
    local winValStr = economy.format(slots.lastWin)
    local vlw = fonts.md:getWidth(winValStr)
    if slots.lastWin > 0 then
        love.graphics.setColor(52/255, 211/255, 153/255, 1)
    else
        love.graphics.setColor(255/255, 248/255, 235/255, 1)
    end
    love.graphics.print(winValStr, math.floor(winX + (winW - vlw) / 2), winY + 26)

    -- 3D Рубиновая кнопка СПИН [X]
    local spinAlpha = slots.isSpinning and 0.55 or 1.0
    local bx = 724
    local by = 650
    local bw = 256
    local bh = 56

    ui.drawSaloonButtonRed(bx, by, bw, bh, slots.isSpinning, spinAlpha)

    -- Золотая круглая кнопка геймпада (X)
    ui.drawButtonBadge(bx + 30, by + bh / 2, 13, "X", spinAlpha)

    -- Текст SPIN!
    local spinFont = fonts.lg
    love.graphics.setFont(spinFont)
    local spinText = i18n.t("spin") .. "!"
    local stw = spinFont:getWidth(spinText)
    local sth = spinFont:getHeight()
    local textX = math.floor(bx + 54 + (bw - 54 - stw) / 2)
    local textY = math.floor(by + (bh - sth) / 2)

    -- Тень текста #3b0802
    love.graphics.setColor(59/255, 8/255, 2/255, spinAlpha)
    love.graphics.print(spinText, textX + 2, textY + 2)
    -- Текст белый #fffdf2
    love.graphics.setColor(255/255, 253/255, 242/255, spinAlpha)
    love.graphics.print(spinText, textX, textY)
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
    -- Окно ставки [Y] (44, 652, 210, 52)
    if x >= 40 and x <= 265 and y >= 645 and y <= 715 then
        if not slots.isSpinning then
            betModal.open(slots.bet, 100, economy.getBalance(), function(newBet)
                slots.bet = newBet
            end)
        end
        return true
    end

    -- Кнопка SPIN (724, 650, 256, 56)
    if x >= 715 and x <= 990 and y >= 645 and y <= 715 then
        slots.spin()
        return true
    end

    return false
end

return slots
