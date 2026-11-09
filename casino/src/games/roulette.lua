local roulette = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")

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
roulette.history = { 32, 15 }
roulette.statusText = "D-PAD SELECT • [A] BET • [X] SPIN"

local grid = {
    { "0" },
    { "3", "6", "9", "12", "15", "18", "21", "24", "27", "30", "33", "36" },
    { "2", "5", "8", "11", "14", "17", "20", "23", "26", "29", "32", "35" },
    { "1", "4", "7", "10", "13", "16", "19", "22", "25", "28", "31", "34" },
    { "doz-1", "doz-2", "doz-3" },
    { "low", "even", "red", "black", "odd", "high" }
}
roulette.cursorRow = 2
roulette.cursorCol = 1

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
    local row = grid[roulette.cursorRow]
    local key = row[math.min(roulette.cursorCol, #row)]
    local amt = roulette.selectedChip

    -- Запрет противоположных ставок
    local conflict = checkOpposingConflict(key)
    if conflict then
        audio.play("fail")
        roulette.statusText = string.format("OPPOSING BET NOT ALLOWED! (%s)", string.upper(conflict))
        return
    end

    if economy.spend(amt) then
        roulette.bets[key] = (roulette.bets[key] or 0) + amt
        audio.play("coin")
    else
        audio.play("fail")
    end
end

function roulette.removeBet()
    local row = grid[roulette.cursorRow]
    local key = row[math.min(roulette.cursorCol, #row)]
    if roulette.bets[key] then
        economy.add(roulette.bets[key])
        roulette.bets[key] = nil
        audio.play("click")
    end
end

function roulette.spin()
    if roulette.isSpinning then return end
    if roulette.getTotalBet() == 0 then
        audio.play("fail")
        return
    end

    roulette.isSpinning = true
    roulette.statusText = "BALL IN PLAY..."
    audio.play("click")

    local winIdx = math.random(1, #roulette.wheel)
    roulette.winNum = roulette.wheel[winIdx]
    roulette.targetSlice = winIdx - 1

    roulette.spinElapsed = 0
    roulette.spinDuration = 4.5
end

function roulette.update(dt)
    if not roulette.isSpinning then return end

    roulette.spinElapsed = roulette.spinElapsed + dt
    local progress = math.min(1, roulette.spinElapsed / roulette.spinDuration)
    local slice = (math.pi * 2) / 37

    roulette.wheelAngle = roulette.wheelAngle + (0.08 * (1 - progress * 0.7))
    local targetPocketAngle = roulette.wheelAngle + roulette.targetSlice * slice + slice / 2

    if progress < 0.65 then
        roulette.ballAngle = roulette.ballAngle - 0.25 * (1 - progress * 0.4)
        roulette.ballRadius = 110
    elseif progress < 0.90 then
        local sub = (progress - 0.65) / 0.25
        roulette.ballRadius = 110 - sub * 36
        roulette.ballAngle = roulette.ballAngle - 0.08 * (1 - sub)
        if math.random() < 0.3 then audio.play("fret") end
    else
        roulette.ballRadius = 74
        roulette.ballAngle = targetPocketAngle
    end

    if progress >= 1 then
        roulette.isSpinning = false
        roulette.finishSpin()
    end
end

function roulette.finishSpin()
    local num = roulette.winNum
    local red = isRed(num)
    local colName = num == 0 and "ZERO" or (red and "RED" or "BLACK")

    table.insert(roulette.history, 1, num)
    if #roulette.history > 6 then table.remove(roulette.history) end

    -- Выплаты
    local payout = 0
    local key = tostring(num)
    if roulette.bets[key] then payout = payout + roulette.bets[key] * 36 end
    if red and roulette.bets["red"] then payout = payout + roulette.bets["red"] * 2 end
    if not red and num ~= 0 and roulette.bets["black"] then payout = payout + roulette.bets["black"] * 2 end
    if num ~= 0 then
        if num % 2 == 0 and roulette.bets["even"] then payout = payout + roulette.bets["even"] * 2 end
        if num % 2 ~= 0 and roulette.bets["odd"] then payout = payout + roulette.bets["odd"] * 2 end
        if num <= 18 and roulette.bets["low"] then payout = payout + roulette.bets["low"] * 2 end
        if num >= 19 and roulette.bets["high"] then payout = payout + roulette.bets["high"] * 2 end
    end
    if num >= 1 and num <= 12 and roulette.bets["doz-1"] then payout = payout + roulette.bets["doz-1"] * 3 end
    if num >= 13 and num <= 24 and roulette.bets["doz-2"] then payout = payout + roulette.bets["doz-2"] * 3 end
    if num >= 25 and num <= 36 and roulette.bets["doz-3"] then payout = payout + roulette.bets["doz-3"] * 3 end

    if payout > 0 then
        economy.add(payout)
        roulette.statusText = string.format("★ %d (%s)! +%s ★", num, colName, economy.format(payout))
        audio.play("win")
    else
        roulette.statusText = string.format("%d (%s). [X] SPIN", num, colName)
        audio.play("fail")
    end

    roulette.bets = {}
end

function roulette.draw()
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 80, 944, 40, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(roulette.statusText, 60, 92)

    local cx, cy, r = 180, 320, 130
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.circle("fill", cx, cy, r + 8)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.circle("line", cx, cy, r + 8)

    local slice = (math.pi * 2) / 37
    for i, num in ipairs(roulette.wheel) do
        local start = roulette.wheelAngle + (i - 1) * slice
        if num == 0 then
            love.graphics.setColor(0.1, 0.45, 0.15)
        elseif isRed(num) then
            love.graphics.setColor(0.7, 0.15, 0.1)
        else
            love.graphics.setColor(0.1, 0.05, 0.02)
        end
        love.graphics.arc("fill", cx, cy, r, start, start + slice)
    end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.circle("fill", cx, cy, 28)
    love.graphics.setColor(0.1, 0.05, 0.02)
    love.graphics.circle("fill", cx, cy, 10)

    local bx = cx + math.cos(roulette.ballAngle) * roulette.ballRadius
    local by = cy + math.sin(roulette.ballAngle) * roulette.ballRadius
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", bx, by, 6)

    local tx, ty = 340, 140
    local cellW, cellH = 48, 60

    love.graphics.setColor(0.1, 0.45, 0.15)
    love.graphics.rectangle("fill", tx, ty, cellW * 12 + 22, 38, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("0 ZERO (35:1)", tx + 240, ty + 12)

    local rows = {
        { 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36 },
        { 2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35 },
        { 1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34 }
    }
    for rowIdx, row in ipairs(rows) do
        for colIdx, num in ipairs(row) do
            local x = tx + (colIdx - 1) * (cellW + 2)
            local y = ty + 44 + (rowIdx - 1) * (cellH + 2)

            if isRed(num) then
                love.graphics.setColor(0.7, 0.15, 0.1)
            else
                love.graphics.setColor(0.12, 0.05, 0.02)
            end
            love.graphics.rectangle("fill", x, y, cellW, cellH, 3)

            love.graphics.setColor(1, 1, 1)
            love.graphics.print(tostring(num), x + 16, y + 22)

            if roulette.cursorRow == rowIdx + 1 and roulette.cursorCol == colIdx then
                love.graphics.setColor(1, 0.88, 0.2)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x - 2, y - 2, cellW + 4, cellH + 4, 4)
                love.graphics.setLineWidth(1)
            end

            if roulette.bets[tostring(num)] then
                love.graphics.setColor(1, 0.85, 0.2)
                love.graphics.circle("fill", x + cellW - 12, y + 12, 8)
            end
        end
    end

    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 560, 944, 60, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(string.format("%s: %s", i18n.t("chip"), economy.format(roulette.selectedChip)), 60, 580)
    love.graphics.print(string.format("%s: %s", i18n.t("bet"), economy.format(roulette.getTotalBet())), 280, 580)
    love.graphics.print("[A] BET  •  [B] UNDO  •  [Y] CHIP  •  [X] SPIN", 520, 580)
end

function roulette.keypressed(key)
    if key == "up" then
        roulette.cursorRow = math.max(1, roulette.cursorRow - 1)
        audio.play("click")
    elseif key == "down" then
        roulette.cursorRow = math.min(#grid, roulette.cursorRow + 1)
        audio.play("click")
    elseif key == "left" then
        roulette.cursorCol = math.max(1, roulette.cursorCol - 1)
        audio.play("click")
    elseif key == "right" then
        local maxCols = #grid[roulette.cursorRow]
        roulette.cursorCol = math.min(maxCols, roulette.cursorCol + 1)
        audio.play("click")
    elseif key == "a" then
        roulette.placeBet()
    elseif key == "b" then
        roulette.removeBet()
    elseif key == "y" then
        roulette.chipIdx = (roulette.chipIdx % #roulette.chips) + 1
        roulette.selectedChip = roulette.chips[roulette.chipIdx]
        audio.play("coin")
    elseif key == "x" or key == "space" or key == "return" then
        roulette.spin()
    end
end

return roulette
