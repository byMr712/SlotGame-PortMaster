local poker = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")

poker.bet = 500
poker.deck = {}
poker.hand = {}
poker.holds = { false, false, false, false, false }
poker.phase = "deal"
poker.focusCard = 1
poker.comboText = "PRESS [X] TO DEAL"
poker.dealAnim = 1

local suits = { "spade", "heart", "diamond", "club" }
local values = {
    { name = "2", val = 2 }, { name = "3", val = 3 }, { name = "4", val = 4 },
    { name = "5", val = 5 }, { name = "6", val = 6 }, { name = "7", val = 7 },
    { name = "8", val = 8 }, { name = "9", val = 9 }, { name = "10", val = 10 },
    { name = "J", val = 11 }, { name = "Q", val = 12 }, { name = "K", val = 13 },
    { name = "A", val = 14 }
}

function poker.initDeck()
    poker.deck = {}
    for _, s in ipairs(suits) do
        for _, v in ipairs(values) do
            table.insert(poker.deck, { suit = s, name = v.name, val = v.val })
        end
    end
    for i = #poker.deck, 2, -1 do
        local j = math.random(1, i)
        poker.deck[i], poker.deck[j] = poker.deck[j], poker.deck[i]
    end
end

function poker.evaluateHand()
    local counts = {}
    local suitCounts = {}
    local vals = {}
    for _, c in ipairs(poker.hand) do
        counts[c.val] = (counts[c.val] or 0) + 1
        suitCounts[c.suit] = (suitCounts[c.suit] or 0) + 1
        table.insert(vals, c.val)
    end
    table.sort(vals)

    local isFlush = false
    for _, sc in pairs(suitCounts) do
        if sc == 5 then isFlush = true end
    end

    local isStraight = false
    if vals[5] - vals[1] == 4 and #vals == 5 then
        local unique = true
        for i = 1, 4 do if vals[i] == vals[i+1] then unique = false end end
        if unique then isStraight = true end
    end
    if vals[1] == 2 and vals[2] == 3 and vals[3] == 4 and vals[4] == 5 and vals[5] == 14 then
        isStraight = true
    end

    local cVals = {}
    for _, v in pairs(counts) do table.insert(cVals, v) end
    table.sort(cVals, function(a,b) return a > b end)

    if isFlush and isStraight and vals[5] == 14 and vals[4] == 13 then return "ROYAL FLUSH", 800 end
    if isFlush and isStraight then return "STRAIGHT FLUSH", 50 end
    if cVals[1] == 4 then return "FOUR OF A KIND", 25 end
    if cVals[1] == 3 and cVals[2] == 2 then return "FULL HOUSE", 9 end
    if isFlush then return "FLUSH", 6 end
    if isStraight then return "STRAIGHT", 4 end
    if cVals[1] == 3 then return "THREE OF A KIND", 3 end
    if cVals[1] == 2 and cVals[2] == 2 then return "TWO PAIR", 2 end
    if cVals[1] == 2 then
        for v, cnt in pairs(counts) do
            if cnt == 2 and v >= 11 then return "JACKS OR BETTER", 1 end
        end
    end
    return "NO COMBINATION", 0
end

function poker.update(dt)
    for _, c in ipairs(poker.hand) do
        if c.anim and c.anim < 1 then
            c.anim = math.min(1, c.anim + dt * 2.2)
        end
    end
end

function poker.drawOrDeal()
    if poker.phase == "deal" then
        if not economy.spend(poker.bet) then
            audio.play("fail")
            return
        end

        audio.play("click")
        poker.initDeck()
        poker.hand = {}
        for i = 1, 5 do
            local c = table.remove(poker.deck)
            c.anim = -(i - 1) * 0.12
            table.insert(poker.hand, c)
        end
        poker.holds = { false, false, false, false, false }
        poker.phase = "draw"
        poker.comboText = "SELECT CARDS TO HOLD • [X] DRAW"
    else
        audio.play("click")
        for i = 1, 5 do
            if not poker.holds[i] then
                local c = table.remove(poker.deck)
                c.anim = 0.0
                poker.hand[i] = c
            end
        end

        local name, mult = poker.evaluateHand()
        if mult > 0 then
            local win = poker.bet * mult
            economy.add(win)
            poker.comboText = string.format("★ %s! +%s ★", name, economy.format(win))
            audio.play("win")
        else
            poker.comboText = "NO COMBINATION. [X] DEAL"
            audio.play("fail")
        end

        poker.phase = "deal"
    end
end

local function drawCard(c, x, y, held, focused)
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", x, y, 100, 140, 6)
    love.graphics.setColor(0.98, 0.93, 0.82)
    love.graphics.rectangle("fill", x + 3, y + 3, 94, 134, 4)

    if focused then
        love.graphics.setColor(1, 0.88, 0.2)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", x - 3, y - 3, 106, 146, 6)
        love.graphics.setLineWidth(1)
    end

    local isRed = (c.suit == "heart" or c.suit == "diamond")
    if isRed then love.graphics.setColor(0.7, 0.15, 0.1) else love.graphics.setColor(0.1, 0.1, 0.1) end

    love.graphics.print(c.name, x + 8, y + 8)
    love.graphics.print(c.name, x + 76, y + 114)
    sprites.draw(c.suit, x + 50, y + 70, 28)

    if held then
        love.graphics.setColor(0.7, 0.15, 0.1)
        love.graphics.rectangle("fill", x + 16, y - 24, 68, 20, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("HOLD", x + 24, y - 20)
    end
end

function poker.draw()
    -- Таблица комбинаций 9/6 сверху
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 80, 944, 40, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("ROYAL x800 • STR FLUSH x50 • 4-KIND x25 • FULL HOUSE x9 • FLUSH x6 • JACKS+ x1", 60, 92)

    -- 5 карт (по умолчанию стол пуст, при раздаче карты анимируются)
    local startX = 140
    local startY = 260
    if #poker.hand == 0 then
        for i = 1, 5 do
            local x = startX + (i - 1) * 150
            love.graphics.setColor(0.12, 0.05, 0.02, 0.4)
            love.graphics.rectangle("fill", x, startY, 100, 140, 6)
            love.graphics.setColor(0.55, 0.26, 0.08, 0.45)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, startY, 100, 140, 6)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.7, 0.5, 0.2, 0.35)
            love.graphics.print(string.format("[%d]", i), x + 40, startY + 60)
        end
    else
        for i, c in ipairs(poker.hand) do
            local x = startX + (i - 1) * 150
            local anim = c.anim or 1
            if anim >= 0 then
                local p = math.min(1, anim)
                local ease = 1 - math.pow(1 - p, 3)
                local yOff = (1 - ease) * -65
                drawCard(c, x, startY + yOff, poker.holds[i], i == poker.focusCard)
            end
        end
    end

    -- Статус
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 480, 944, 40, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(poker.comboText, 320, 492)

    -- Нижняя панель
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 560, 944, 60, 4)

    -- Панель ставки (D-Pad)
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 55, 566, 280, 48, 4)
    love.graphics.setColor(0.65, 0.45, 0.15)
    love.graphics.rectangle("line", 55, 566, 280, 48, 4)

    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print("BET [▲/▼ ±100, ◄/► ±1K]", 65, 572)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(economy.format(poker.bet), 65, 590)

    if poker.phase == "draw" then
        love.graphics.setColor(0.6, 0.5, 0.4)
        love.graphics.print("(LOCKED)", 180, 590)
    end

    local function drawGameBtn(bx, by, bw, bh, bCol, keyCol, keyChar, label)
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.rectangle("fill", bx, by, bw, bh, 4)
        love.graphics.setColor(bCol[1], bCol[2], bCol[3])
        love.graphics.rectangle("fill", bx + 2, by + 2, bw - 4, bh - 4, 3)
        love.graphics.setColor(bCol[1] * 1.35, bCol[2] * 1.35, bCol[3] * 1.35)
        love.graphics.rectangle("line", bx + 2, by + 2, bw - 4, bh - 4, 3)

        local cx = bx + 18
        local cy = by + bh / 2
        love.graphics.setColor(keyCol[1], keyCol[2], keyCol[3])
        love.graphics.circle("fill", cx, cy, 11)
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, 11)
        love.graphics.setLineWidth(1)
        love.graphics.print(keyChar, cx - 4, cy - 7)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label, bx + 36, cy - 7)
    end

    drawGameBtn(580, 570, 160, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "A", "HOLD/UNHOLD")
    local drawLabel = (poker.phase == "draw") and "DRAW" or "DEAL"
    drawGameBtn(760, 570, 150, 40, {0.75, 0.16, 0.1}, {0.32, 0.62, 0.96}, "X", drawLabel)
end

function poker.keypressed(key)
    if poker.phase == "deal" then
        if key == "up" then
            poker.bet = poker.bet + 100
            audio.play("click")
        elseif key == "down" then
            poker.bet = math.max(100, poker.bet - 100)
            audio.play("click")
        elseif key == "right" then
            poker.bet = poker.bet + 1000
            audio.play("click")
        elseif key == "left" then
            poker.bet = math.max(100, poker.bet - 1000)
            audio.play("click")
        end
    else
        if key == "left" then
            poker.focusCard = (poker.focusCard == 1) and 5 or (poker.focusCard - 1)
            audio.play("click")
        elseif key == "right" then
            poker.focusCard = (poker.focusCard == 5) and 1 or (poker.focusCard + 1)
            audio.play("click")
        elseif key == "a" then
            poker.holds[poker.focusCard] = not poker.holds[poker.focusCard]
            audio.play("click")
        end
    end

    if key == "1" then poker.holds[1] = not poker.holds[1]
    elseif key == "2" then poker.holds[2] = not poker.holds[2]
    elseif key == "3" then poker.holds[3] = not poker.holds[3]
    elseif key == "4" then poker.holds[4] = not poker.holds[4]
    elseif key == "5" then poker.holds[5] = not poker.holds[5]
    elseif key == "x" or key == "space" or key == "return" then
        poker.drawOrDeal()
    end
end

return poker
