local roulette = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
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
roulette.history = { { num = 32, won = true }, { num = 15, won = false } }
roulette.statusText = ""
roulette.zoom = 0
roulette.targetZoom = 0
roulette.holdTimer = 0

-- Свободная 2D навигация: строки 0..5, столбцы 0..12
roulette.curRow = 2
roulette.curCol = 1

function roulette.getCurrentKey()
    if roulette.curRow == 0 or roulette.curCol == 0 then
        return "0"
    elseif roulette.curRow >= 1 and roulette.curRow <= 3 then
        local rowNums = {
            { "3", "6", "9", "12", "15", "18", "21", "24", "27", "30", "33", "36" },
            { "2", "5", "8", "11", "14", "17", "20", "23", "26", "29", "32", "35" },
            { "1", "4", "7", "10", "13", "16", "19", "22", "25", "28", "31", "34" }
        }
        return rowNums[roulette.curRow][roulette.curCol]
    elseif roulette.curRow == 4 then
        if roulette.curCol <= 4 then return "doz-1"
        elseif roulette.curCol <= 8 then return "doz-2"
        else return "doz-3" end
    elseif roulette.curRow == 5 then
        if roulette.curCol <= 2 then return "low"
        elseif roulette.curCol <= 4 then return "even"
        elseif roulette.curCol <= 6 then return "red"
        elseif roulette.curCol <= 8 then return "black"
        elseif roulette.curCol <= 10 then return "odd"
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
        roulette.statusText = string.format("OPPOSING BET NOT ALLOWED! (%s)", string.upper(conflict))
        return
    end

    if key:sub(1, 4) == "doz-" then
        local count = 0
        for k, _ in pairs(roulette.bets) do
            if k:sub(1, 4) == "doz-" then count = count + 1 end
        end
        if not roulette.bets[key] and count >= 2 then
            audio.play("fail")
            roulette.statusText = "CANNOT BET ALL 3 DOZENS AT ONCE!"
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
        roulette.statusText = "ALL BETS CLEARED"
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
    roulette.statusText = "★ WHEEL IN MOTION... ★"
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
            roulette.statusText = "PLACE YOUR BETS"
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
        roulette.statusText = "★ BALL LAUNCHED! ★"
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
                roulette.statusText = string.format("★ %d %s ★", roulette.winNum, col)
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

    if payout > 0 then
        economy.add(payout)
        roulette.statusText = string.format("★ %d %s! +%s ★", num, colName, economy.format(payout))
        audio.play("win")
    else
        roulette.statusText = string.format("★ %d %s ★", num, colName)
        audio.play("fail")
    end

    roulette.bets = {}
    roulette.holdTimer = 2.6

    -- Проверка банкротства или снижение ставки до остатка баланса
    if bankruptModal.check() then
        -- открыто окно банкротства
    elseif roulette.chipBet and roulette.chipBet > economy.getBalance() then
        roulette.chipBet = 100
    end
end

local function drawGrid(alpha)
    local tx, ty = 340, 140
    local cellW, cellH = 48, 56
    local totalW = cellW * 12 + 22

    -- 1. Сектор 0 ZERO (x36)
    love.graphics.setColor(0.1, 0.45, 0.15, alpha)
    love.graphics.rectangle("fill", tx, ty, totalW, 36, 4)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print("0 ZERO (x36)", tx + 240, ty + 10)

    local curKey = roulette.getCurrentKey()
    if curKey == "0" then
        love.graphics.setColor(1, 0.88, 0.2, alpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", tx - 2, ty - 2, totalW + 4, 40, 4)
        love.graphics.setLineWidth(1)
    end
    if roulette.bets["0"] then
        love.graphics.setColor(1, 0.85, 0.2, alpha)
        love.graphics.circle("fill", tx + totalW - 14, ty + 18, 8)
    end

    -- 2. Сетка чисел 1-36 (3 строки по 12)
    local rows = {
        { 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36 },
        { 2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35 },
        { 1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34 }
    }
    for rowIdx, row in ipairs(rows) do
        for colIdx, num in ipairs(row) do
            local x = tx + (colIdx - 1) * (cellW + 2)
            local y = ty + 40 + (rowIdx - 1) * (cellH + 2)

            if isRed(num) then
                love.graphics.setColor(0.7, 0.15, 0.1, alpha)
            else
                love.graphics.setColor(0.12, 0.05, 0.02, alpha)
            end
            love.graphics.rectangle("fill", x, y, cellW, cellH, 3)

            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.print(tostring(num), x + 16, y + 20)

            if roulette.curRow == rowIdx and roulette.curCol == colIdx and roulette.curCol > 0 then
                love.graphics.setColor(1, 0.88, 0.2, alpha)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x - 2, y - 2, cellW + 4, cellH + 4, 4)
                love.graphics.setLineWidth(1)
            end

            if roulette.bets[tostring(num)] then
                love.graphics.setColor(1, 0.85, 0.2, alpha)
                love.graphics.circle("fill", x + cellW - 12, y + 12, 8)
            end
        end
    end

    -- 3. Дюжины: 1-12, 13-24, 25-36 (x3)
    local dozY = ty + 40 + 3 * (cellH + 2) + 2
    local dozW = (totalW - 4) / 3
    local dozH = 34
    local dozDefs = {
        { key = "doz-1", label = "1-12 (x3)" },
        { key = "doz-2", label = "13-24 (x3)" },
        { key = "doz-3", label = "25-36 (x3)" }
    }
    for colIdx, doz in ipairs(dozDefs) do
        local x = tx + (colIdx - 1) * (dozW + 2)
        love.graphics.setColor(0.09, 0.29, 0.16, alpha)
        love.graphics.rectangle("fill", x, dozY, dozW, dozH, 3)

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(doz.label, x + dozW / 2 - 34, dozY + 10)

        if roulette.curRow == 4 and ((colIdx == 1 and roulette.curCol <= 4) or (colIdx == 2 and roulette.curCol >= 5 and roulette.curCol <= 8) or (colIdx == 3 and roulette.curCol >= 9)) then
            love.graphics.setColor(1, 0.88, 0.2, alpha)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 2, dozY - 2, dozW + 4, dozH + 4, 4)
            love.graphics.setLineWidth(1)
        end

        if roulette.bets[doz.key] then
            love.graphics.setColor(1, 0.85, 0.2, alpha)
            love.graphics.circle("fill", x + dozW - 12, dozY + 12, 8)
        end
    end

    -- 4. Внешние ставки: 1-18, EVEN, RED, BLACK, ODD, 19-36 (x2)
    local outY = dozY + dozH + 4
    local outW = (totalW - 10) / 6
    local outH = 34
    local outDefs = {
        { key = "low",   label = "1-18 (x2)",  bg = { 0.09, 0.29, 0.16 } },
        { key = "even",  label = "EVEN (x2)",  bg = { 0.09, 0.29, 0.16 } },
        { key = "red",   label = "RED (x2)",   bg = { 0.70, 0.15, 0.10 } },
        { key = "black", label = "BLACK (x2)", bg = { 0.12, 0.05, 0.02 } },
        { key = "odd",   label = "ODD (x2)",   bg = { 0.09, 0.29, 0.16 } },
        { key = "high",  label = "19-36 (x2)", bg = { 0.09, 0.29, 0.16 } }
    }
    for colIdx, ob in ipairs(outDefs) do
        local x = tx + (colIdx - 1) * (outW + 2)
        love.graphics.setColor(ob.bg[1], ob.bg[2], ob.bg[3], alpha)
        love.graphics.rectangle("fill", x, outY, outW, outH, 3)

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(ob.label, x + outW / 2 - (#ob.label * 4), outY + 10)

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

    love.graphics.setColor(0.22, 0.1, 0.04, alpha)
    love.graphics.rectangle("fill", 40, 560, 944, 60, 4)

    -- Панель фишки и общей ставки
    love.graphics.setColor(0.12, 0.05, 0.02, alpha)
    love.graphics.rectangle("fill", 50, 566, 360, 48, 4)
    love.graphics.setColor(0.78, 0.52, 0.12, alpha)
    love.graphics.rectangle("line", 50, 566, 360, 48, 4)

    -- Желтый значок [Y]
    love.graphics.setColor(0.96, 0.78, 0.2, alpha)
    love.graphics.circle("fill", 72, 590, 12)
    love.graphics.setColor(0.08, 0.03, 0.01, alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 72, 590, 12)
    love.graphics.setLineWidth(1)
    love.graphics.print("Y", 68, 583)

    love.graphics.setColor(0.9, 0.8, 0.55, alpha)
    love.graphics.print(i18n.t("bet") .. ":", 92, 574)
    love.graphics.setColor(1, 0.88, 0.4, alpha)
    love.graphics.print(economy.format(roulette.selectedChip), 92, 590)

    love.graphics.setColor(0.9, 0.8, 0.55, alpha)
    love.graphics.print("TOTAL:", 220, 574)
    love.graphics.setColor(1, 0.88, 0.4, alpha)
    love.graphics.print(economy.format(roulette.getTotalBet()), 220, 590)

    local function drawGameBtn(bx, by, bw, bh, bCol, keyCol, keyChar, label)
        love.graphics.setColor(0.08, 0.03, 0.01, alpha)
        love.graphics.rectangle("fill", bx, by, bw, bh, 4)
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], alpha)
        love.graphics.rectangle("fill", bx + 2, by + 2, bw - 4, bh - 4, 3)
        love.graphics.setColor(bCol[1] * 1.35, bCol[2] * 1.35, bCol[3] * 1.35, alpha)
        love.graphics.rectangle("line", bx + 2, by + 2, bw - 4, bh - 4, 3)

        local cx = bx + 18
        local cy = by + bh / 2
        love.graphics.setColor(keyCol[1], keyCol[2], keyCol[3], alpha)
        love.graphics.circle("fill", cx, cy, 11)
        love.graphics.setColor(0.08, 0.03, 0.01, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, 11)
        love.graphics.setLineWidth(1)
        love.graphics.print(keyChar, cx - 4, cy - 7)

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(label, bx + 36, cy - 7)
    end

    drawGameBtn(430, 570, 120, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "A", "BET")
    drawGameBtn(565, 570, 130, 40, {0.75, 0.16, 0.1}, {0.95, 0.32, 0.3}, "B", "CLEAR")
    drawGameBtn(710, 570, 130, 40, {0.68, 0.32, 0.1}, {0.96, 0.78, 0.2}, "Y", "SET BET")
    drawGameBtn(855, 570, 120, 40, {0.75, 0.16, 0.1}, {0.32, 0.62, 0.96}, "X", "SPIN!")
end

function roulette.draw()
    local font = love.graphics.getFont()

    -- 1. Верхняя латунная плашка истории (расширена вниз, высота 54px, без подсказок справа)
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 74, 944, 54, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 74, 944, 54, 4)
    love.graphics.setLineWidth(1)

    -- Подпись HISTORY: (золотой фирменный шрифт в стиле остальных залов)
    local histLabel = i18n.t("history") .. ":"
    local htw = font and font:getWidth(histLabel) or (#histLabel * 8)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(histLabel, 54, 92, 0, 1.15, 1.15)

    -- Увеличенные значки выпавших цифр
    local badgeStartX = 54 + htw * 1.15 + 14
    local badgeW = 38
    local badgeH = 36
    local badgeY = 83

    for i, item in ipairs(roulette.history) do
        if i > 8 then break end
        local bx = badgeStartX + (i - 1) * (badgeW + 8)
        local n = (type(item) == "table") and item.num or item
        local won = (type(item) == "table") and item.won or false

        -- Фон значка цифры
        if n == 0 then
            love.graphics.setColor(0.08, 0.36, 0.14)
        elseif isRed(n) then
            love.graphics.setColor(0.72, 0.16, 0.1)
        else
            love.graphics.setColor(0.1, 0.04, 0.02)
        end
        love.graphics.rectangle("fill", bx, badgeY, badgeW, badgeH, 4)
        love.graphics.setColor(0.3, 0.15, 0.08)
        love.graphics.rectangle("line", bx, badgeY, badgeW, badgeH, 4)

        -- Число
        local nStr = tostring(n)
        local ntw = font and font:getWidth(nStr) or (#nStr * 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(nStr, bx + badgeW / 2 - (ntw * 1.1) / 2, badgeY + 8, 0, 1.1, 1.1)

        -- Фирменное золотое нижнее подчеркивание, если победили
        if won then
            love.graphics.setColor(1, 0.88, 0.4)
            love.graphics.rectangle("fill", bx + 3, badgeY + badgeH - 3, badgeW - 6, 3, 1)
        end
    end

    -- Статус выигрыша справа (подсказки кнопок убраны)
    if roulette.statusText ~= "" then
        local stw = font and font:getWidth(roulette.statusText) or (#roulette.statusText * 8)
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.print(roulette.statusText, 960 - stw, 92)
    end

    -- Расчет плавного зума и центровки на всё свободное пространство экрана
    local cx = 175 + roulette.zoom * (512 - 175)
    local cy = 375 + roulette.zoom * (405 - 375)
    local r = 145 + roulette.zoom * (275 - 145)

    -- Внешняя чаша из красного дерева с латунным ободом
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.circle("fill", cx, cy, r + 10)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", cx, cy, r + 10)
    love.graphics.setLineWidth(1)

    -- Канавка трека шарика
    love.graphics.setColor(0.08, 0.03, 0.01)
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
            love.graphics.setColor(0.08, 0.45, 0.16)
        elseif isRed(num) then
            love.graphics.setColor(0.72, 0.12, 0.12)
        else
            love.graphics.setColor(0.08, 0.04, 0.02)
        end
        love.graphics.arc("fill", cx, cy, r - 20, start, start + slice)

        -- Латунные разделители (frets)
        love.graphics.setColor(1, 0.9, 0.5, 0.7)
        local fx1 = cx + math.cos(start) * innerR
        local fy1 = cy + math.sin(start) * innerR
        local fx2 = cx + math.cos(start) * (r - 20)
        local fy2 = cy + math.sin(start) * (r - 20)
        love.graphics.line(fx1, fy1, fx2, fy2)

        -- Номер кармана (белый / кремовый шрифт)
        if roulette.zoom > 0.35 then
            local midAng = start + slice / 2
            local textR = (r - 20 + innerR) / 2
            local tx = cx + math.cos(midAng) * textR
            local ty = cy + math.sin(midAng) * textR
            love.graphics.setColor(1, 0.95, 0.7)
            local sNum = tostring(num)
            love.graphics.print(sNum, tx - 5, ty - 6)
        end
    end

    -- Внутренний полированный конус и центральная турель
    love.graphics.setColor(0.24, 0.10, 0.04)
    love.graphics.circle("fill", cx, cy, innerR)
    love.graphics.setColor(0.85, 0.65, 0.18)
    love.graphics.circle("fill", cx, cy, r * 0.22)
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.circle("fill", cx, cy, r * 0.08)

    -- Физический шарик из слоновой кости (появляется только после броска крупье)
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

    -- СЕТКА И КНОПКИ СТАВОК СКРЫВАЮТСЯ ВО ВРЕМЯ ВРАЩЕНИЯ И ПОКА ПО ЦЕНТРУ
    if roulette.zoom < 0.65 then
        local alpha = 1 - (roulette.zoom / 0.65)
        drawGrid(alpha)
    end
end

function roulette.keypressed(key)
    if roulette.isSpinning then return end

    if key == "up" then
        roulette.curRow = math.max(0, roulette.curRow - 1)
        audio.play("click")
    elseif key == "down" then
        roulette.curRow = math.min(5, roulette.curRow + 1)
        audio.play("click")
    elseif key == "left" then
        roulette.curCol = math.max(0, roulette.curCol - 1)
        audio.play("click")
    elseif key == "right" then
        roulette.curCol = math.min(12, roulette.curCol + 1)
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

    -- Плашка фишки / ставки [Y] (щедрая зона клика)
    if x >= 40 and x <= 420 and y >= 550 and y <= 620 then
        betModal.open(roulette.selectedChip, 100, economy.getBalance(), function(newChip)
            roulette.selectedChip = newChip
        end)
        return true
    end

    -- Кнопки действий снизу
    -- BET (A): 430, 570, 120, 40
    if x >= 430 and x <= 550 and y >= 570 and y <= 610 then
        roulette.placeBet()
        return true
    -- CLEAR (B): 565, 570, 130, 40
    elseif x >= 565 and x <= 695 and y >= 570 and y <= 610 then
        roulette.clearBets()
        return true
    -- SET BET (Y): 710, 570, 130, 40
    elseif x >= 710 and x <= 840 and y >= 570 and y <= 610 then
        betModal.open(roulette.selectedChip, 100, economy.getBalance(), function(newChip)
            roulette.selectedChip = newChip
        end)
        return true
    -- SPIN (X): 855, 570, 120, 40
    elseif x >= 855 and x <= 975 and y >= 570 and y <= 610 then
        roulette.spin()
        return true
    end

    local tx, ty = 340, 140
    local cellW, cellH = 48, 56
    local totalW = cellW * 12 + 22

    -- Клик по Zero
    if x >= tx and x <= tx + totalW and y >= ty and y <= ty + 36 then
        roulette.curRow = 0
        roulette.curCol = 1
        roulette.placeBet()
        return true
    end

    -- Клик по сетке чисел (3 строки по 12)
    for rowIdx = 1, 3 do
        for colIdx = 1, 12 do
            local cx = tx + (colIdx - 1) * (cellW + 2)
            local cy = ty + 40 + (rowIdx - 1) * (cellH + 2)
            if x >= cx and x <= cx + cellW and y >= cy and y <= cy + cellH then
                roulette.curRow = rowIdx
                roulette.curCol = colIdx
                roulette.placeBet()
                return true
            end
        end
    end

    -- Клик по дюжинам
    local dozY = ty + 40 + 3 * (cellH + 2) + 2
    local dozW = (totalW - 4) / 3
    local dozH = 34
    if y >= dozY and y <= dozY + dozH then
        for colIdx = 1, 3 do
            local cx = tx + (colIdx - 1) * (dozW + 2)
            if x >= cx and x <= cx + dozW then
                roulette.curRow = 4
                roulette.curCol = (colIdx == 1) and 1 or ((colIdx == 2) and 5 or 9)
                roulette.placeBet()
                return true
            end
        end
    end

    -- Клик по внешним ставкам (1-18, EVEN, RED, BLACK, ODD, 19-36)
    local outY = dozY + dozH + 4
    local outW = (totalW - 10) / 6
    local outH = 34
    if y >= outY and y <= outY + outH then
        for colIdx = 1, 6 do
            local cx = tx + (colIdx - 1) * (outW + 2)
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
