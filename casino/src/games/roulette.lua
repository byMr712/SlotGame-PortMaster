local roulette = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local fonts = require("src.core.fonts")
local ui = require("src.core.ui")
local betModal = require("src.core.bet_modal")
local bankruptModal = require("src.core.bankrupt_modal")

roulette.wheel = { 0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26 }
roulette.redNumbers = { 1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36 }

roulette.bets = {}
roulette.selectedChip = 100
roulette.chips = { 100, 500, 2500, 10000 }
roulette.chipIdx = 1

roulette.isSpinning = false
roulette.wheelAngle = 0
roulette.ballAngle = 0
roulette.ballRadius = 110
roulette.history = { {num=32, won=false}, {num=15, won=true}, {num=19, won=false}, {num=4, won=false}, {num=21, won=true}, {num=2, won=false} }
roulette.statusKey = ""
roulette.statusNum = 0
roulette.statusCol = ""
roulette.statusPayout = 0
roulette.statusArg = ""
roulette.zoom = 0
roulette.targetZoom = 0
roulette.holdTimer = 0

-- Свободная 2D навигация: строки 0..5, столбцы 0..12
roulette.curRow = 2
roulette.curCol = 1

function roulette.resetTable()
    roulette.history = { {num=32, won=false}, {num=15, won=true}, {num=19, won=false}, {num=4, won=false}, {num=21, won=true}, {num=2, won=false} }
    roulette.bets = {}
    roulette.statusKey = ""
    roulette.curRow = 2
    roulette.curCol = 1
    roulette.isSpinning = false
end

function roulette.getStatusText()
    if not roulette.statusKey or roulette.statusKey == "" then return "" end
    if roulette.statusKey == "roulette_result" then
        local colLocalized = roulette.statusCol == "ZERO" and i18n.t("zero") or (roulette.statusCol == "RED" and i18n.t("red") or i18n.t("black"))
        if roulette.statusPayout and roulette.statusPayout > 0 then
            return string.format("★ %d %s! +%s ★", roulette.statusNum or 0, colLocalized, economy.format(roulette.statusPayout))
        else
            return string.format("★ %d %s ★", roulette.statusNum or 0, colLocalized)
        end
    elseif roulette.statusKey == "opposing_conflict" then
        return string.format("%s (%s)", i18n.t("opposing_conflict"), string.upper(i18n.t(roulette.statusArg or "")))
    else
        return i18n.t(roulette.statusKey)
    end
end

function roulette.getCurrentKey()
    if roulette.curRow == 0 then
        return "0"
    end
    local col = math.max(1, math.min(12, roulette.curCol or 1))
    if roulette.curRow >= 1 and roulette.curRow <= 3 then
        local rowNums = {
            { "3", "6", "9", "12", "15", "18", "21", "24", "27", "30", "33", "36" },
            { "2", "5", "8", "11", "14", "17", "20", "23", "26", "29", "32", "35" },
            { "1", "4", "7", "10", "13", "16", "19", "22", "25", "28", "31", "34" }
        }
        return rowNums[roulette.curRow][col]
    elseif roulette.curRow == 4 then
        if col <= 4 then return "doz-1"
        elseif col <= 8 then return "doz-2"
        else return "doz-3" end
    elseif roulette.curRow == 5 then
        if col <= 2 then return "low"
        elseif col <= 4 then return "even"
        elseif col <= 6 then return "red"
        elseif col <= 8 then return "black"
        elseif col <= 10 then return "odd"
        else return "high" end
    end
    return "0"
end

local function isRed(num)
    for _, r in ipairs(roulette.redNumbers) do
        if r == num then return true end
    end
    return false
end

-- Проверка взаимоисключающих ставок казино
local function checkOpposingConflict(key)
    if key == "red" and roulette.bets["black"] then return "black" end
    if key == "black" and roulette.bets["red"] then return "red" end
    if key == "even" and roulette.bets["odd"] then return "odd" end
    if key == "odd" and roulette.bets["even"] then return "even" end
    if key == "low" and roulette.bets["high"] then return "high" end
    if key == "high" and roulette.bets["low"] then return "low" end
    return nil
end

function roulette.getTotalBet()
    local t = 0
    for _, amt in pairs(roulette.bets) do t = t + amt end
    return t
end

function roulette.placeBet()
    if roulette.isSpinning then return end
    local key = roulette.getCurrentKey()
    local amt = roulette.selectedChip

    -- Запрет противоположных ставок
    local conflict = checkOpposingConflict(key)
    if conflict then
        audio.play("fail")
        roulette.statusKey = "opposing_conflict"
        roulette.statusArg = conflict
        return
    end

    if key:sub(1, 4) == "doz-" then
        local count = 0
        for k, _ in pairs(roulette.bets) do
            if k:sub(1, 4) == "doz-" then count = count + 1 end
        end
        if not roulette.bets[key] and count >= 2 then
            audio.play("fail")
            roulette.statusKey = "cant_bet_3_dozens"
            return
        end
    end

    if economy.spend(amt) then
        roulette.bets[key] = (roulette.bets[key] or 0) + amt
        audio.play("coin")
    else
        audio.play("fail")
    end
end

function roulette.clearBets()
    if roulette.isSpinning then return end
    local total = roulette.getTotalBet()
    if total > 0 then
        economy.add(total)
        roulette.bets = {}
        audio.play("click")
        roulette.statusKey = "bets_cleared"
    end
end

function roulette.removeBet()
    if roulette.isSpinning then return end
    local key = roulette.getCurrentKey()
    if roulette.bets[key] then
        economy.add(roulette.bets[key])
        roulette.bets[key] = nil
        audio.play("click")
    end
end

local T_WHEEL_ONLY = 2.0 -- Колесо запускается первым и крутится 2 секунды
local T_BALL_RUN = 5.2   -- Шарик кидают, когда колесо уже замедляется
local T_HOLD = 2.2       -- Шарик лежит в лунке на остаточном вращении колеса
local SLICE = (math.pi * 2) / 37

function roulette.spin()
    if roulette.isSpinning then return end
    if roulette.getTotalBet() == 0 then
        audio.play("fail")
        return
    end

    roulette.isSpinning = true
    roulette.targetZoom = 1
    roulette.holdTimer = 0
    roulette.statusKey = "wheel_in_motion"
    audio.play("click")

    local winIdx = math.random(1, #roulette.wheel)
    roulette.winNum = roulette.wheel[winIdx]
    roulette.targetSlice = winIdx - 1

    roulette.wheelSpeed = 0.075
    roulette.spinElapsed = 0
    roulette.ballActive = false
    roulette.ballTau = 0
    roulette.hitDeflector = false
    roulette.settled = false
    roulette.bounceClick = false

    -- Точный расчет физического импульса шарика вперед (forward integration):
    -- Вычисляем положение целевого кармана в момент посадки шарика
    local simWSpeed = roulette.wheelSpeed
    local simWAngle = roulette.wheelAngle
    local dt = 1 / 60
    local totalSpinTime = T_WHEEL_ONLY + T_BALL_RUN
    for t = 0, totalSpinTime, dt do
        simWSpeed = math.max(0.010, simWSpeed * math.pow(0.995, dt * 60))
        simWAngle = simWAngle + simWSpeed
    end

    local targetPocketAtLand = simWAngle + roulette.targetSlice * SLICE + SLICE / 2
    local ballLaunchAngle = -math.pi / 2 -- Запуск с верхней точки чаши
    local N_REV = 6
    local angleDiff = (targetPocketAtLand - ballLaunchAngle) % (math.pi * 2)
    if angleDiff > 0 then angleDiff = angleDiff - math.pi * 2 end
    local totalBallTravel = angleDiff - (N_REV * math.pi * 2)

    -- Интеграл кривой замедления шарика
    local function getFactor(tau)
        local p = tau / T_BALL_RUN
        if p < 0.6 then
            return 1 - p * 0.45
        else
            local sub = (p - 0.6) / 0.4
            return 0.73 * math.pow(1 - sub, 2.0)
        end
    end

    local factorIntegral = 0
    for s = 0, T_BALL_RUN, dt do
        factorIntegral = factorIntegral + getFactor(s) * dt
    end

    roulette.ballOmega0 = totalBallTravel / factorIntegral
    roulette.ballAngle = ballLaunchAngle
    roulette.ballRadius = 0.90
end

function roulette.update(dt)
    -- Плавная интерполяция зума и центровки колеса
    roulette.zoom = roulette.zoom + (roulette.targetZoom - roulette.zoom) * math.min(1, dt * 4.5)

    if roulette.holdTimer > 0 then
        roulette.holdTimer = roulette.holdTimer - dt
        if roulette.holdTimer <= 0 then
            roulette.targetZoom = 0
            roulette.isSpinning = false
            roulette.ballActive = false
            roulette.statusKey = ""
        end
    end

    if not roulette.isSpinning or roulette.holdTimer > 0 then return end

    roulette.spinElapsed = roulette.spinElapsed + dt

    -- 1. Колесо крутится и плавно замедляется (физика трения, строго нормализовано по dt)
    roulette.wheelSpeed = math.max(0.010, roulette.wheelSpeed * math.pow(0.995, dt * 60))
    roulette.wheelAngle = roulette.wheelAngle + roulette.wheelSpeed * (dt * 60)

    -- 2. Запуск шарика, когда колесо уже замедлилось (после 2 секунд)
    if roulette.spinElapsed >= T_WHEEL_ONLY and not roulette.ballActive then
        roulette.ballActive = true
        audio.play("coin")
        roulette.statusKey = "ball_launched"
    end

    if roulette.ballActive then
        if roulette.ballTau < T_BALL_RUN then
            local p = roulette.ballTau / T_BALL_RUN
            local factor
            if p < 0.6 then
                factor = 1 - p * 0.45
            else
                local sub = (p - 0.6) / 0.4
                factor = 0.73 * math.pow(1 - sub, 2.0)
            end

            -- ЧИСТАЯ ФИЗИЧЕСКАЯ ИНТЕГРАЦИЯ ВПЕРЕД: theta += omega * dt (НИКАКОЙ ТЕЛЕПОРТАЦИИ!)
            roulette.ballAngle = roulette.ballAngle + roulette.ballOmega0 * factor * dt

            -- Физический радиус шарика
            if p < 0.5 then
                -- Наружный трек
                roulette.ballRadius = 0.90
            elseif p < 0.72 then
                -- Сход с трека по спирали к дефлекторам
                local sub = (p - 0.5) / 0.22
                local ease = sub * sub * (3 - 2 * sub)
                roulette.ballRadius = 0.90 - ease * (0.90 - 0.72)
                if sub > 0.75 and not roulette.hitDeflector then
                    roulette.hitDeflector = true
                    audio.play("fret")
                end
            else
                -- ЗАМЕДЛЕННАЯ СЪЁМКА (SLOW-MOTION) И ОТСКОКИ ПО КАРМАНАМ
                local sub = (p - 0.72) / 0.28
                local decay = math.pow(1 - sub, 2)
                local hop = math.abs(math.sin(sub * math.pi * 5)) * decay * 0.055
                roulette.ballRadius = 0.72 - sub * (0.72 - 0.62) + hop

                local bouncePhase = (sub * 5) % 1
                if bouncePhase < 0.2 and not roulette.bounceClick then
                    roulette.bounceClick = true
                    audio.play("tick")
                elseif bouncePhase > 0.35 then
                    roulette.bounceClick = false
                end
            end
            roulette.ballTau = roulette.ballTau + dt
        else
            -- 3. Шарик надежно лежит в лунке и крутится ВМЕСТЕ с колесом на остаточном вращении
            roulette.ballRadius = 0.62

            if not roulette.settled then
                roulette.settled = true
                -- Точно определяем карман, в котором физически находится шарик:
                local rel = (roulette.ballAngle - roulette.wheelAngle) % (math.pi * 2)
                local normRel = (rel + math.pi * 2) % (math.pi * 2)
                local landedIdx = math.floor(normRel / SLICE) + 1
                if landedIdx < 1 then landedIdx = 1 end
                if landedIdx > 37 then landedIdx = 37 end
                roulette.landedIdx = landedIdx
                roulette.winNum = roulette.wheel[landedIdx]

                audio.play("click")
                local red = isRed(roulette.winNum)
                local col = roulette.winNum == 0 and "ZERO" or (red and "RED" or "BLACK")
                roulette.statusKey = "roulette_result"
                roulette.statusNum = roulette.winNum
                roulette.statusCol = col
                roulette.statusPayout = 0
            end

            -- Шарик идеально центрируется в своем кармане и вращается вместе с колесом
            roulette.ballAngle = roulette.wheelAngle + (roulette.landedIdx - 1) * SLICE + SLICE / 2

            -- Окончание вращения после наблюдения игроком
            if roulette.spinElapsed >= (T_WHEEL_ONLY + T_BALL_RUN + T_HOLD) then
                roulette.finishSpin()
            end
        end
    end
end

function roulette.finishSpin()
    local num = roulette.winNum
    local red = isRed(num)
    local colName = num == 0 and "ZERO" or (red and "RED" or "BLACK")

    -- Выплаты по стандартным европейским правилам:
    local payout = 0
    local key = tostring(num)

    -- 1. Точное число (Straight-Up 35:1 -> возврат 36x)
    if roulette.bets[key] then payout = payout + roulette.bets[key] * 36 end

    if num ~= 0 then
        -- 2. Равные шансы (Even Money 1:1 -> возврат 2x)
        if red and roulette.bets["red"] then payout = payout + roulette.bets["red"] * 2 end
        if not red and roulette.bets["black"] then payout = payout + roulette.bets["black"] * 2 end
        if num % 2 == 0 and roulette.bets["even"] then payout = payout + roulette.bets["even"] * 2 end
        if num % 2 ~= 0 and roulette.bets["odd"] then payout = payout + roulette.bets["odd"] * 2 end
        if num <= 18 and roulette.bets["low"] then payout = payout + roulette.bets["low"] * 2 end
        if num >= 19 and roulette.bets["high"] then payout = payout + roulette.bets["high"] * 2 end

        -- 3. Дюжины (Dozens 2:1 -> возврат 3x)
        if num >= 1 and num <= 12 and roulette.bets["doz-1"] then payout = payout + roulette.bets["doz-1"] * 3 end
        if num >= 13 and num <= 24 and roulette.bets["doz-2"] then payout = payout + roulette.bets["doz-2"] * 3 end
        if num >= 25 and num <= 36 and roulette.bets["doz-3"] then payout = payout + roulette.bets["doz-3"] * 3 end
    end

    local won = (payout > 0)
    table.insert(roulette.history, 1, { num = num, won = won })
    if #roulette.history > 10 then table.remove(roulette.history) end

    roulette.statusKey = "roulette_result"
    roulette.statusNum = num
    roulette.statusCol = colName
    roulette.statusPayout = payout

    if payout > 0 then
        economy.add(payout)
        audio.play("win")
    else
        audio.play("fail")
    end

    roulette.bets = {}
    roulette.holdTimer = 2.6

    -- Проверка банкротства или снижение ставки до остатка баланса
    if bankruptModal.check() then
        -- открыто окно банкротства
    elseif roulette.chipBet and roulette.chipBet > economy.getBalance() then
        roulette.chipBet = math.max(1, economy.getBalance())
    end
end

local function drawGrid(alpha)
    local tx = 364
    local tableW = 618

    -- Внешняя рамка стола рулетки
    love.graphics.setColor(9/255, 33/255, 19/255, alpha)
    love.graphics.rectangle("fill", 356, 162, 634, 498, 6)
    love.graphics.setColor(255/255, 234/255, 173/255, 0.85 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 356, 162, 634, 498, 6)
    love.graphics.setLineWidth(1)

    -- 1. Сектор 0 ZERO (x36)
    local zy = 170
    local zh = 42
    love.graphics.setColor(26/255, 92/255, 40/255, alpha)
    love.graphics.rectangle("fill", tx, zy, tableW, zh, 4)
    love.graphics.setColor(92/255, 40/255, 14/255, alpha)
    love.graphics.rectangle("line", tx, zy, tableW, zh, 4)

    love.graphics.setFont(fonts.sm)
    love.graphics.setColor(1, 1, 1, alpha)
    local zText = "0 ZERO (x36)"
    local ztw = fonts.sm:getWidth(zText)
    love.graphics.print(zText, math.floor(tx + (tableW - ztw) / 2), zy + 14)

    local curKey = roulette.getCurrentKey()
    if curKey == "0" then
        love.graphics.setColor(1, 0.88, 0.2, alpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", tx - 2, zy - 2, tableW + 4, zh + 4, 4)
        love.graphics.setLineWidth(1)
    end
    if roulette.bets["0"] then
        love.graphics.setColor(1, 0.85, 0.2, alpha)
        love.graphics.circle("fill", tx + tableW - 24, zy + zh / 2, 9)
    end

    -- 2. Сетка чисел 1-36 (3 строки по 12)
    local rows = {
        { 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36 },
        { 2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35 },
        { 1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34 }
    }
    local gy = 220
    local gh = 246
    local cellW = math.floor((tableW - 11 * 4) / 12)
    local cellH = math.floor((gh - 2 * 4) / 3)

    for rowIdx, row in ipairs(rows) do
        for colIdx, num in ipairs(row) do
            local x = tx + (colIdx - 1) * (cellW + 4)
            local y = gy + (rowIdx - 1) * (cellH + 4)

            if isRed(num) then
                love.graphics.setColor(179/255, 40/255, 26/255, alpha)
            else
                love.graphics.setColor(20/255, 7/255, 2/255, alpha)
            end
            love.graphics.rectangle("fill", x, y, cellW, cellH, 3)
            love.graphics.setColor(92/255, 40/255, 14/255, 0.8 * alpha)
            love.graphics.rectangle("line", x, y, cellW, cellH, 3)

            love.graphics.setFont(fonts.sm)
            love.graphics.setColor(1, 1, 1, alpha)
            local sNum = tostring(num)
            local ntw = fonts.sm:getWidth(sNum)
            local nth = fonts.sm:getHeight()
            love.graphics.print(sNum, math.floor(x + (cellW - ntw) / 2), math.floor(y + (cellH - nth) / 2))

            if roulette.curRow == rowIdx and roulette.curCol == colIdx and roulette.curCol > 0 then
                love.graphics.setColor(1, 0.88, 0.2, alpha)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x - 2, y - 2, cellW + 4, cellH + 4, 4)
                love.graphics.setLineWidth(1)
            end

            if roulette.bets[tostring(num)] then
                love.graphics.setColor(1, 0.85, 0.2, alpha)
                love.graphics.circle("fill", x + cellW - 10, y + 10, 7)
            end
        end
    end

    -- 3. Дюжины: 1-12, 13-24, 25-36 (x3)
    local dozY = 474
    local dozH = 42
    local dozW = math.floor((tableW - 2 * 4) / 3)
    local dozDefs = {
        { key = "doz-1", label = "1-12 (x3)" },
        { key = "doz-2", label = "13-24 (x3)" },
        { key = "doz-3", label = "25-36 (x3)" }
    }
    for colIdx, doz in ipairs(dozDefs) do
        local x = tx + (colIdx - 1) * (dozW + 4)
        love.graphics.setColor(24/255, 74/255, 40/255, alpha)
        love.graphics.rectangle("fill", x, dozY, dozW, dozH, 3)
        love.graphics.setColor(92/255, 40/255, 14/255, alpha)
        love.graphics.rectangle("line", x, dozY, dozW, dozH, 3)

        love.graphics.setFont(fonts.sm)
        love.graphics.setColor(1, 1, 1, alpha)
        local dtw = fonts.sm:getWidth(doz.label)
        local dth = fonts.sm:getHeight()
        love.graphics.print(doz.label, math.floor(x + (dozW - dtw) / 2), math.floor(dozY + (dozH - dth) / 2))

        if roulette.curRow == 4 and ((colIdx == 1 and roulette.curCol <= 4) or (colIdx == 2 and roulette.curCol >= 5 and roulette.curCol <= 8) or (colIdx == 3 and roulette.curCol >= 9)) then
            love.graphics.setColor(1, 0.88, 0.2, alpha)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 2, dozY - 2, dozW + 4, dozH + 4, 4)
            love.graphics.setLineWidth(1)
        end

        if roulette.bets[doz.key] then
            love.graphics.setColor(1, 0.85, 0.2, alpha)
            love.graphics.circle("fill", x + dozW - 12, dozY + 12, 7)
        end
    end

    -- 4. Внешние ставки: 1-18, EVEN, RED, BLACK, ODD, 19-36 (x2)
    local outY = 522
    local outH = 42
    local outW = math.floor((tableW - 5 * 4) / 6)
    local outDefs = {
        { key = "low",   label = "1-18 (x2)",  bg = { 24/255, 74/255, 40/255 } },
        { key = "even",  label = "EVEN (x2)",  bg = { 24/255, 74/255, 40/255 } },
        { key = "red",   label = "RED (x2)",   bg = { 179/255, 40/255, 26/255 } },
        { key = "black", label = "BLACK (x2)", bg = { 20/255, 7/255, 2/255 } },
        { key = "odd",   label = "ODD (x2)",   bg = { 24/255, 74/255, 40/255 } },
        { key = "high",  label = "19-36 (x2)", bg = { 24/255, 74/255, 40/255 } }
    }
    for colIdx, ob in ipairs(outDefs) do
        local x = tx + (colIdx - 1) * (outW + 4)
        love.graphics.setColor(ob.bg[1], ob.bg[2], ob.bg[3], alpha)
        love.graphics.rectangle("fill", x, outY, outW, outH, 3)
        love.graphics.setColor(92/255, 40/255, 14/255, alpha)
        love.graphics.rectangle("line", x, outY, outW, outH, 3)

        love.graphics.setFont(fonts.xs)
        love.graphics.setColor(1, 1, 1, alpha)
        local otw = fonts.xs:getWidth(ob.label)
        local oth = fonts.xs:getHeight()
        love.graphics.print(ob.label, math.floor(x + (outW - otw) / 2), math.floor(outY + (outH - oth) / 2))

        local isOutFocus = (roulette.curRow == 5 and (
            (colIdx == 1 and roulette.curCol <= 2) or
            (colIdx == 2 and roulette.curCol >= 3 and roulette.curCol <= 4) or
            (colIdx == 3 and roulette.curCol >= 5 and roulette.curCol <= 6) or
            (colIdx == 4 and roulette.curCol >= 7 and roulette.curCol <= 8) or
            (colIdx == 5 and roulette.curCol >= 9 and roulette.curCol <= 10) or
            (colIdx == 6 and roulette.curCol >= 11)
        ))
        if isOutFocus then
            love.graphics.setColor(1, 0.88, 0.2, alpha)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 2, outY - 2, outW + 4, outH + 4, 4)
            love.graphics.setLineWidth(1)
        end

        if roulette.bets[ob.key] then
            love.graphics.setColor(1, 0.85, 0.2, alpha)
            love.graphics.circle("fill", x + outW - 10, outY + 10, 7)
        end
    end

    -- 5. Нижняя панель действий (вровень с остальными залами)
    ui.drawBrassPlaque(34, 678, 956, 64, 4)

    -- Панель выбранной фишки [Y]
    local chipBoxX = 48
    local chipBoxY = 684
    local chipBoxW = 150
    local chipBoxH = 52
    love.graphics.setColor(27/255, 10/255, 4/255, alpha)
    love.graphics.rectangle("fill", chipBoxX, chipBoxY, chipBoxW, chipBoxH, 4)
    love.graphics.setColor(120/255, 79/255, 24/255, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", chipBoxX, chipBoxY, chipBoxW, chipBoxH, 4)
    love.graphics.setLineWidth(1)

    -- Желтый значок [Y]
    ui.drawButtonBadge(chipBoxX + 20, chipBoxY + chipBoxH / 2, 11, "Y", alpha)

    love.graphics.setFont(fonts.xs)
    love.graphics.setColor(255/255, 234/255, 173/255, alpha)
    love.graphics.print(i18n.t("bet") .. ":", chipBoxX + 38, chipBoxY + 9)
    love.graphics.setFont(fonts.md)
    love.graphics.setColor(1, 0.88, 0.4, alpha)
    love.graphics.print(economy.format(roulette.selectedChip), chipBoxX + 38, chipBoxY + 25)

    -- Панель общей ставки TOTAL BET
    local totBoxX = 208
    local totBoxY = 684
    local totBoxW = 170
    local totBoxH = 52
    love.graphics.setColor(27/255, 10/255, 4/255, alpha)
    love.graphics.rectangle("fill", totBoxX, totBoxY, totBoxW, totBoxH, 4)
    love.graphics.setColor(92/255, 40/255, 14/255, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", totBoxX, totBoxY, totBoxW, totBoxH, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fonts.xs)
    love.graphics.setColor(255/255, 234/255, 173/255, alpha)
    love.graphics.print(i18n.t("total") .. ":", totBoxX + 16, totBoxY + 9)
    love.graphics.setFont(fonts.md)
    love.graphics.setColor(1, 0.88, 0.4, alpha)
    love.graphics.print(economy.format(roulette.getTotalBet()), totBoxX + 16, totBoxY + 25)

    -- Кнопки действий: BET (A), CLEAR (B), SPIN! (X)
    local btnY = 686
    local btnH = 48

    -- BET (A)
    local betBtnX = 404
    local betBtnW = 130
    ui.drawSaloonButton(betBtnX, btnY, betBtnW, btnH, "", nil, false, alpha)
    local betLabel = i18n.t("bet")
    love.graphics.setFont(fonts.md)
    local btw = fonts.md:getWidth(betLabel)
    local bth = fonts.md:getHeight()
    local totalBetW = 22 + 10 + btw
    local betStartX = betBtnX + math.floor((betBtnW - totalBetW) / 2)
    ui.drawButtonBadge(betStartX + 11, btnY + btnH / 2, 11, "A", alpha, "green")
    love.graphics.setColor(255/255, 248/255, 235/255, alpha)
    love.graphics.print(betLabel, betStartX + 32, math.floor(btnY + (btnH - bth) / 2))

    -- CLEAR (B)
    local clrBtnX = 548
    local clrBtnW = 150
    ui.drawSaloonButtonRed(clrBtnX, btnY, clrBtnW, btnH, false, alpha)
    local clrLabel = i18n.t("clear")
    love.graphics.setFont(fonts.md)
    local ctw = fonts.md:getWidth(clrLabel)
    local cth = fonts.md:getHeight()
    local totalClrW = 22 + 10 + ctw
    local clrStartX = clrBtnX + math.floor((clrBtnW - totalClrW) / 2)
    ui.drawButtonBadge(clrStartX + 11, btnY + btnH / 2, 11, "B", alpha, "red")
    love.graphics.setColor(255/255, 248/255, 235/255, alpha)
    love.graphics.print(clrLabel, clrStartX + 32, math.floor(btnY + (btnH - cth) / 2))

    -- SPIN (X)
    local spinBtnX = 724
    local spinBtnY = 684
    local spinBtnW = 252
    local spinBtnH = 52
    local spinAlpha = (roulette.isSpinning and 0.55 or 1.0) * alpha
    ui.drawSaloonButtonRed(spinBtnX, spinBtnY, spinBtnW, spinBtnH, roulette.isSpinning, spinAlpha)

    local spText = i18n.t("spin") .. "!"
    love.graphics.setFont(fonts.lg)
    local sptw = fonts.lg:getWidth(spText)
    local spth = fonts.lg:getHeight()
    local totalSpW = 24 + 12 + sptw
    local spStartX = spinBtnX + math.floor((spinBtnW - totalSpW) / 2)

    ui.drawButtonBadge(spStartX + 12, spinBtnY + spinBtnH / 2, 12, "X", spinAlpha, "yellow")

    local sptx = spStartX + 36
    local spty = math.floor(spinBtnY + (spinBtnH - spth) / 2)
    love.graphics.setFont(fonts.lg)
    love.graphics.setColor(59/255, 8/255, 2/255, spinAlpha)
    love.graphics.print(spText, sptx + 2, spty + 2)
    love.graphics.setColor(255/255, 253/255, 242/255, spinAlpha)
    love.graphics.print(spText, sptx, spty)
end

function roulette.draw()
    -- 1. Верхняя латунная плашка истории
    ui.drawBrassPlaque(34, 90, 956, 56, 4)

    -- Подпись HISTORY:
    love.graphics.setFont(fonts.xs)
    love.graphics.setColor(1, 0.88, 0.4)
    local histLabel = i18n.t("history") .. ":"
    local htw = fonts.xs:getWidth(histLabel)
    love.graphics.print(histLabel, 50, 110)

    -- Значки выпавших цифр
    local badgeStartX = 50 + htw + 16
    local badgeW = 34
    local badgeH = 34
    local badgeY = 101

    for i, item in ipairs(roulette.history) do
        if i > 8 then break end
        local bx = badgeStartX + (i - 1) * (badgeW + 8)
        local n = (type(item) == "table") and item.num or item
        local won = (type(item) == "table") and item.won or false

        if n == 0 then
            love.graphics.setColor(24/255, 74/255, 40/255)
        elseif isRed(n) then
            love.graphics.setColor(179/255, 40/255, 26/255)
        else
            love.graphics.setColor(20/255, 7/255, 2/255)
        end
        love.graphics.rectangle("fill", bx, badgeY, badgeW, badgeH, 4)
        love.graphics.setColor(92/255, 40/255, 14/255)
        love.graphics.rectangle("line", bx, badgeY, badgeW, badgeH, 4)

        local nStr = tostring(n)
        love.graphics.setFont(fonts.xs)
        local ntw = fonts.xs:getWidth(nStr)
        local nth = fonts.xs:getHeight()
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(nStr, math.floor(bx + (badgeW - ntw) / 2), math.floor(badgeY + (badgeH - nth) / 2))

        if won then
            love.graphics.setColor(1, 0.88, 0.4)
            love.graphics.rectangle("fill", bx + 3, badgeY + badgeH - 3, badgeW - 6, 2, 1)
        end
    end

    -- Статус выигрыша справа
    local st = roulette.getStatusText()
    if st ~= "" then
        love.graphics.setFont(fonts.xs)
        local stw = fonts.xs:getWidth(st)
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.print(st, 970 - stw, 110)
    end

    -- Расчет колеса
    local cx = 195 + roulette.zoom * (512 - 195)
    local cy = 410 + roulette.zoom * (405 - 410)
    local r = 135 + roulette.zoom * (275 - 135)

    -- Внешняя чаша из красного дерева с латунным ободом
    love.graphics.setColor(43/255, 18/255, 6/255)
    love.graphics.circle("fill", cx, cy, r + 10)
    love.graphics.setColor(200/255, 134/255, 30/255)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", cx, cy, r + 10)
    love.graphics.setLineWidth(1)

    -- Канавка трека шарика
    love.graphics.setColor(20/255, 7/255, 2/255)
    love.graphics.circle("fill", cx, cy, r - 4)

    -- 8 латунных дефлекторов
    for d = 0, 7 do
        local dang = d * (math.pi / 4)
        local dx = cx + math.cos(dang) * (r - 12)
        local dy = cy + math.sin(dang) * (r - 12)
        love.graphics.setColor(1, 0.88, 0.5)
        love.graphics.rectangle("fill", dx - 2, dy - 2, 4, 4)
    end

    -- 37 карманов
    local slice = (math.pi * 2) / 37
    local innerR = r * 0.65
    for i, num in ipairs(roulette.wheel) do
        local start = roulette.wheelAngle + (i - 1) * slice
        if num == 0 then
            love.graphics.setColor(26/255, 92/255, 40/255)
        elseif isRed(num) then
            love.graphics.setColor(179/255, 40/255, 26/255)
        else
            love.graphics.setColor(20/255, 7/255, 2/255)
        end
        love.graphics.arc("fill", cx, cy, r - 20, start, start + slice)

        -- Латунные разделители
        love.graphics.setColor(1, 0.9, 0.5, 0.7)
        local fx1 = cx + math.cos(start) * innerR
        local fy1 = cy + math.sin(start) * innerR
        local fx2 = cx + math.cos(start) * (r - 20)
        local fy2 = cy + math.sin(start) * (r - 20)
        love.graphics.line(fx1, fy1, fx2, fy2)

        -- Номер кармана
        if roulette.zoom > 0.35 then
            local midAng = start + slice / 2
            local textR = (r - 20 + innerR) / 2
            local tx = cx + math.cos(midAng) * textR
            local ty = cy + math.sin(midAng) * textR
            love.graphics.setFont(fonts.xs)
            love.graphics.setColor(1, 0.95, 0.7)
            local sNum = tostring(num)
            love.graphics.print(sNum, tx - 5, ty - 5)
        end
    end

    -- Внутренний полированный конус и центральная турель
    love.graphics.setColor(56/255, 24/255, 10/255)
    love.graphics.circle("fill", cx, cy, innerR)
    love.graphics.setColor(212/255, 175/255, 55/255)
    love.graphics.circle("fill", cx, cy, r * 0.22)
    love.graphics.setColor(20/255, 7/255, 2/255)
    love.graphics.circle("fill", cx, cy, r * 0.08)

    -- Физический шарик
    if (roulette.isSpinning or roulette.holdTimer > 0) and roulette.ballActive then
        local actualBallR = r * roulette.ballRadius
        local bx = cx + math.cos(roulette.ballAngle) * actualBallR
        local by = cy + math.sin(roulette.ballAngle) * actualBallR

        -- Тень шарика
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.circle("fill", bx + 3, by + 3, 7)
        -- Шарик
        love.graphics.setColor(0.98, 0.96, 0.92)
        love.graphics.circle("fill", bx, by, 7)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", bx - 2, by - 2, 2.5)
    end

    -- Сетка и кнопки ставок
    if roulette.zoom < 0.65 then
        local alpha = 1 - (roulette.zoom / 0.65)
        drawGrid(alpha)
    end
end

function roulette.keypressed(key)
    if roulette.isSpinning then return end

    if key == "up" then
        if roulette.curRow == 0 then
            roulette.curRow = 5
        else
            roulette.curRow = roulette.curRow - 1
        end
        audio.play("click")
    elseif key == "down" then
        if roulette.curRow == 5 then
            roulette.curRow = 0
        else
            roulette.curRow = roulette.curRow + 1
        end
        audio.play("click")
    elseif key == "left" then
        if roulette.curRow == 4 then
            roulette.curCol = math.max(1, (roulette.curCol or 1) - 4)
        elseif roulette.curRow == 5 then
            roulette.curCol = math.max(1, (roulette.curCol or 1) - 2)
        else
            local c = (roulette.curCol or 1) - 1
            if c < 1 then c = 12 end
            roulette.curCol = c
        end
        audio.play("click")
    elseif key == "right" then
        if roulette.curRow == 4 then
            roulette.curCol = math.min(12, (roulette.curCol or 1) + 4)
        elseif roulette.curRow == 5 then
            roulette.curCol = math.min(12, (roulette.curCol or 1) + 2)
        else
            local c = (roulette.curCol or 1) + 1
            if c > 12 then c = 1 end
            roulette.curCol = c
        end
        audio.play("click")
    elseif key == "a" then
        roulette.placeBet()
    elseif key == "b" then
        roulette.clearBets()
    elseif key == "y" then
        betModal.open(roulette.selectedChip, 100, economy.getBalance(), function(newChip)
            roulette.selectedChip = newChip
        end)
    elseif key == "x" or key == "space" or key == "return" then
        roulette.spin()
    end
end

function roulette.mousepressed(x, y)
    if roulette.isSpinning then return false end

    -- Плашка фишки / ставки [Y]
    if x >= 44 and x <= 200 and y >= 680 and y <= 740 then
        betModal.open(roulette.selectedChip, 100, economy.getBalance(), function(newChip)
            roulette.selectedChip = newChip
        end)
        return true
    end

    -- Кнопки действий снизу: BET (A), CLEAR (B), SPIN! (X)
    -- BET (A): 404, 686, 130, 48
    if x >= 404 and x <= 534 and y >= 680 and y <= 740 then
        roulette.placeBet()
        return true
    -- CLEAR (B): 548, 686, 150, 48
    elseif x >= 548 and x <= 698 and y >= 680 and y <= 740 then
        roulette.clearBets()
        return true
    -- SPIN (X): 724, 684, 252, 52
    elseif x >= 724 and x <= 976 and y >= 680 and y <= 740 then
        roulette.spin()
        return true
    end

    local tx = 364
    local tableW = 618

    -- Клик по Zero
    if x >= tx and x <= tx + tableW and y >= 170 and y <= 212 then
        roulette.curRow = 0
        roulette.curCol = 1
        roulette.placeBet()
        return true
    end

    -- Клик по сетке чисел (3 строки по 12)
    local gy = 220
    local gh = 246
    local cellW = math.floor((tableW - 11 * 4) / 12)
    local cellH = math.floor((gh - 2 * 4) / 3)

    for rowIdx = 1, 3 do
        for colIdx = 1, 12 do
            local cx = tx + (colIdx - 1) * (cellW + 4)
            local cy = gy + (rowIdx - 1) * (cellH + 4)
            if x >= cx and x <= cx + cellW and y >= cy and y <= cy + cellH then
                roulette.curRow = rowIdx
                roulette.curCol = colIdx
                roulette.placeBet()
                return true
            end
        end
    end

    -- Клик по дюжинам
    local dozY = 474
    local dozH = 42
    local dozW = math.floor((tableW - 2 * 4) / 3)
    if y >= dozY and y <= dozY + dozH then
        for colIdx = 1, 3 do
            local cx = tx + (colIdx - 1) * (dozW + 4)
            if x >= cx and x <= cx + dozW then
                roulette.curRow = 4
                roulette.curCol = (colIdx == 1) and 1 or ((colIdx == 2) and 5 or 9)
                roulette.placeBet()
                return true
            end
        end
    end

    -- Клик по внешним ставкам (1-18, EVEN, RED, BLACK, ODD, 19-36)
    local outY = 522
    local outH = 42
    local outW = math.floor((tableW - 5 * 4) / 6)
    if y >= outY and y <= outY + outH then
        for colIdx = 1, 6 do
            local cx = tx + (colIdx - 1) * (outW + 4)
            if x >= cx and x <= cx + outW then
                roulette.curRow = 5
                roulette.curCol = (colIdx - 1) * 2 + 1
                roulette.placeBet()
                return true
            end
        end
    end

    return false
end

return roulette
