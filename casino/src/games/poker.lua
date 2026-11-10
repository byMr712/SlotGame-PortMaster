local poker = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")
local betModal = require("src.core.bet_modal")
local bankruptModal = require("src.core.bankrupt_modal")

local cardFont = nil
local function getCardFont()
    if not cardFont and love.graphics and love.graphics.newFont then
        pcall(function() cardFont = love.graphics.newFont(24) end)
    end
    return cardFont
end

poker.bet = 500
poker.deck = {}
poker.hand = {}
poker.holds = { false, false, false, false, false }
poker.phase = "draw"
poker.focusCard = 1
poker.comboKey = "select_hold"
poker.comboWin = 0
poker.dealAnim = 1
poker.betDeducted = false
poker.autoRestartTimer = 0
poker.controlMode = 0 -- 0: ABX (A=Hold, X=Draw), 1: D-Pad (Down=Hold, Up=Draw)

function poker.toggleControlMode()
    poker.controlMode = (poker.controlMode == 0) and 1 or 0
    audio.play("click")
end

function poker.getComboText()
    if poker.comboKey == "select_hold" then
        return i18n.t("select_hold")
    elseif poker.comboKey == "no_combo" then
        return i18n.t("no_combo")
    elseif poker.comboKey and poker.comboKey ~= "" then
        return string.format("★ %s! +%s ★", i18n.t(poker.comboKey), economy.format(poker.comboWin or 0))
    end
    return ""
end

local suits = { "spade", "heart", "diamond", "club" }
local values = {
    { name = "2", val = 2 }, { name = "3", val = 3 }, { name = "4", val = 4 },
    { name = "5", val = 5 }, { name = "6", val = 6 }, { name = "7", val = 7 },
    { name = "8", val = 8 }, { name = "9", val = 9 }, { name = "10", val = 10 },
    { name = "J", val = 11 }, { name = "Q", val = 12 }, { name = "K", val = 13 },
    { name = "A", val = 14 }
}

function poker.resetTable()
    poker.hand = {}
    poker.holds = { false, false, false, false, false }
    poker.phase = "draw"
    poker.focusCard = 1
    poker.betDeducted = false
    poker.autoRestartTimer = 0
    poker.comboKey = "select_hold"
    poker.comboWin = 0
end

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

    if isFlush and isStraight and vals[5] == 14 and vals[4] == 13 then return "royal_flush", 800 end
    if isFlush and isStraight then return "straight_flush", 50 end
    if cVals[1] == 4 then return "four_of_a_kind", 25 end
    if cVals[1] == 3 and cVals[2] == 2 then return "full_house", 9 end
    if isFlush then return "flush", 6 end
    if isStraight then return "straight", 4 end
    if cVals[1] == 3 then return "three_of_a_kind", 3 end
    if cVals[1] == 2 and cVals[2] == 2 then return "two_pair", 2 end
    if cVals[1] == 2 then
        for v, cnt in pairs(counts) do
            if cnt == 2 and v >= 11 then return "jacks_or_better", 1 end
        end
    end
    return "no_combo", 0
end

function poker.deal()
    if economy.getBalance() <= 0 then return end
    poker.initDeck()
    poker.hand = {}
    for i = 1, 5 do
        local c = table.remove(poker.deck)
        c.anim = -(i - 1) * 0.12
        table.insert(poker.hand, c)
    end
    poker.holds = { false, false, false, false, false }
    poker.focusCard = 1
    poker.phase = "draw"
    poker.betDeducted = false
    poker.autoRestartTimer = 0
    poker.comboKey = "select_hold"
    poker.comboWin = 0
end

function poker.toggleHold(idx)
    if poker.phase ~= "draw" or poker.autoRestartTimer > 0 then return end
    idx = idx or poker.focusCard
    poker.holds[idx] = not poker.holds[idx]
    audio.play("click")
end

function poker.doDraw()
    if #poker.hand == 0 then
        poker.deal()
        return
    end
    if poker.phase ~= "draw" or poker.autoRestartTimer > 0 then return end

    if not poker.betDeducted then
        if not economy.spend(poker.bet) then
            audio.play("fail")
            if bankruptModal.check() then end
            return
        end
        poker.betDeducted = true
    end

    audio.play("click")
    for i = 1, 5 do
        if not poker.holds[i] then
            local c = table.remove(poker.deck)
            c.anim = 0.0
            poker.hand[i] = c
        end
    end

    local key, mult = poker.evaluateHand()
    if mult > 0 then
        local win = poker.bet * mult
        economy.add(win)
        poker.comboKey = key
        poker.comboWin = win
        audio.play("win")
    else
        poker.comboKey = "no_combo"
        poker.comboWin = 0
        audio.play("fail")
    end

    poker.phase = "result"
    if economy.getBalance() <= 0 then
        poker.autoRestartTimer = 0
        bankruptModal.check()
    else
        poker.autoRestartTimer = 2.0
        if poker.bet > economy.getBalance() then
            poker.bet = math.max(1, economy.getBalance())
        end
    end
end

function poker.update(dt)
    -- Автоматическая сдача карт, если игра еще не запускалась или стол пуст
    if #poker.hand == 0 and economy.getBalance() > 0 and not bankruptModal.active then
        poker.deal()
    end

    for _, c in ipairs(poker.hand) do
        if c.anim and c.anim < 1 then
            c.anim = math.min(1, c.anim + dt * 2.2)
        end
    end

    if poker.autoRestartTimer > 0 then
        if economy.getBalance() <= 0 then
            poker.autoRestartTimer = 0
        else
            poker.autoRestartTimer = poker.autoRestartTimer - dt
            if poker.autoRestartTimer <= 0 then
                poker.autoRestartTimer = 0
                poker.deal()
            end
        end
    end
end

local function drawCard(c, x, y, held, focused)
    local cw, ch = 166, 236
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", x, y, cw, ch, 6)
    love.graphics.setColor(0.98, 0.93, 0.82)
    love.graphics.rectangle("fill", x + 3, y + 3, cw - 6, ch - 6, 4)

    if focused then
        -- Яркая золотая рамка фокуса карты с мягким ореолом
        love.graphics.setColor(1, 0.85, 0.15, 0.45)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", x - 4, y - 4, cw + 8, ch + 8, 8)
        love.graphics.setColor(1, 0.90, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, cw + 6, ch + 6, 7)
        love.graphics.setColor(1, 1, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x - 2, y - 2, cw + 4, ch + 4, 6)
        love.graphics.setLineWidth(1)

        -- Золотой указатель фокуса сверху карты
        love.graphics.setColor(1, 0.88, 0.2)
        local arrowX = x + cw / 2
        local arrowY = y - 8
        love.graphics.polygon("fill", arrowX - 8, arrowY - 8, arrowX + 8, arrowY - 8, arrowX, arrowY)
    end

    local isRed = (c.suit == "heart" or c.suit == "diamond")
    if isRed then love.graphics.setColor(0.75, 0.15, 0.1) else love.graphics.setColor(0.1, 0.05, 0.02) end

    local oldFont = love.graphics.getFont()
    local cFont = getCardFont()
    if cFont then love.graphics.setFont(cFont) end

    love.graphics.print(c.name, x + 10, y + 10)
    local tw = love.graphics.getFont():getWidth(c.name)
    love.graphics.print(c.name, x + cw - 12 - tw, y + ch - 34)

    love.graphics.setFont(oldFont)

    sprites.draw(c.suit, x + cw / 2, y + ch / 2, 56)

    if held then
        love.graphics.setColor(0.7, 0.15, 0.1)
        love.graphics.rectangle("fill", x + (cw - 90) / 2, y - 42, 90, 22, 4)
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x + (cw - 90) / 2, y - 42, 90, 22, 4)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1)
        local hTxt = i18n.t("hold")
        local hw = love.graphics.getFont() and love.graphics.getFont():getWidth(hTxt) or 32
        love.graphics.print(hTxt, x + (cw - 90) / 2 + (90 - hw) / 2, y - 38)
    end
end

function poker.draw()
    local font = love.graphics.getFont()

    -- Таблица комбинаций сверху (высота 52px, внутри сукна)
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 86, 944, 52, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 86, 944, 52, 4)
    love.graphics.setLineWidth(1)

    local combos = {
        { name = "ROYAL", mult = "x800" },
        { name = "STR FLUSH", mult = "x50" },
        { name = "4 OF KIND", mult = "x25" },
        { name = "FULL HOUSE", mult = "x9" },
        { name = "JACKS+", mult = "x1" },
    }

    local padX = 6
    local gap = 8
    local totalW = 944 - padX * 2
    local cellW = math.floor((totalW - (#combos - 1) * gap) / #combos)
    local cellH = 42
    local cellY = 91

    for i, c in ipairs(combos) do
        local bx = 40 + padX + (i - 1) * (cellW + gap)

        -- Фон и рамка ячейки
        love.graphics.setColor(0.12, 0.05, 0.02)
        love.graphics.rectangle("fill", bx, cellY, cellW, cellH, 4)
        love.graphics.setColor(0.36, 0.16, 0.06)
        love.graphics.rectangle("line", bx, cellY, cellW, cellH, 4)

        -- Название комбинации
        love.graphics.setColor(1, 0.88, 0.4)
        local ntw = font and font:getWidth(c.name) or (#c.name * 8)
        love.graphics.print(c.name, bx + (cellW - ntw * 1.1) / 2, cellY + 6, 0, 1.1, 1.1)

        -- Множитель крупным шрифтом
        love.graphics.setColor(1, 0.92, 0.45)
        local mtw = font and font:getWidth(c.mult) or (#c.mult * 8)
        love.graphics.print(c.mult, bx + (cellW - mtw * 1.2) / 2, cellY + 23, 0, 1.2, 1.2)
    end

    -- 5 карт одного увеличенного размера (по умолчанию стол пуст, при раздаче карты анимируются)
    local startX = 45
    local startY = 184
    local cw, ch = 166, 236
    local step = 192

    if #poker.hand == 0 then
        for i = 1, 5 do
            local x = startX + (i - 1) * step
            love.graphics.setColor(0.12, 0.05, 0.02, 0.4)
            love.graphics.rectangle("fill", x, startY, cw, ch, 6)
            love.graphics.setColor(0.55, 0.26, 0.08, 0.45)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, startY, cw, ch, 6)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.7, 0.5, 0.2, 0.35)

            local oldFont = love.graphics.getFont()
            local cFont = getCardFont()
            if cFont then love.graphics.setFont(cFont) end
            local lbl = "CARD " .. i
            local lw = love.graphics.getFont():getWidth(lbl)
            love.graphics.print(lbl, x + (cw - lw) / 2, startY + 100)
            love.graphics.setFont(oldFont)
        end
    else
        for i, c in ipairs(poker.hand) do
            local x = startX + (i - 1) * step
            local anim = c.anim or 1
            if anim >= 0 then
                local p = math.min(1, anim)
                local ease = 1 - math.pow(1 - p, 3)
                local yOff = (1 - ease) * -65
                drawCard(c, x, startY + yOff, poker.holds[i], (poker.phase == "draw" and i == (poker.focusCard or 1)))
            end
        end
    end

    -- Статус
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 450, 944, 44, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 450, 944, 44, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 0.88, 0.4)
    local font = love.graphics.getFont()
    local cText = poker.getComboText()
    local tw = font and font:getWidth(cText) or (#cText * 8)
    love.graphics.print(cText, 512 - tw / 2, 464)

    -- Нижняя панель
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 560, 944, 60, 4)

    -- Панель ставки [Y]
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 55, 566, 260, 48, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.rectangle("line", 55, 566, 260, 48, 4)

    -- Желтый значок [Y]
    local font = love.graphics.getFont()
    local cx, cy = 76, 590
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
    love.graphics.print(i18n.t("bet") .. ":", 96, 574)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(economy.format(poker.bet), 96, 590)

    if poker.phase == "draw" and poker.betDeducted then
        love.graphics.setColor(0.6, 0.5, 0.4)
        love.graphics.print("(LOCKED)", 205, 590)
    end

    local function drawGameBtn(bx, by, bw, bh, bCol, keyCol, dir, label)
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

        -- Стрелка D-Pad или буквенная метка
        love.graphics.setColor(0.08, 0.03, 0.01)
        if dir == "up" then
            love.graphics.rectangle("fill", cx - 1, cy - 5, 2, 2)
            love.graphics.rectangle("fill", cx - 3, cy - 3, 6, 2)
            love.graphics.rectangle("fill", cx - 5, cy - 1, 10, 2)
            love.graphics.rectangle("fill", cx - 2, cy + 1, 4, 4)
        elseif dir == "down" then
            love.graphics.rectangle("fill", cx - 2, cy - 5, 4, 4)
            love.graphics.rectangle("fill", cx - 5, cy - 1, 10, 2)
            love.graphics.rectangle("fill", cx - 3, cy + 1, 6, 2)
            love.graphics.rectangle("fill", cx - 1, cy + 3, 2, 2)
        else
            local font = love.graphics.getFont()
            local kw = font and font:getWidth(dir) or (#dir * 8)
            local kh = font and font:getHeight() or 14
            local tx = math.floor(cx - kw / 2)
            local ty = math.floor(cy - kh / 2)
            love.graphics.print(dir, tx, ty)
            love.graphics.print(dir, tx + 1, ty)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label, bx + 36, cy - 7)
    end

    local holdLabel = i18n.t("hold")
    local drawLabel = i18n.t("draw")
    local switchLabel = i18n.t("switch")

    if poker.phase == "draw" and poker.autoRestartTimer == 0 then
        if poker.controlMode == 0 then
            drawGameBtn(510, 570, 140, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "A", holdLabel)
            drawGameBtn(675, 570, 145, 40, {0.75, 0.16, 0.1}, {0.32, 0.62, 0.96}, "X", drawLabel)
        else
            drawGameBtn(510, 570, 140, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "down", holdLabel)
            drawGameBtn(675, 570, 145, 40, {0.75, 0.16, 0.1}, {0.32, 0.62, 0.96}, "up", drawLabel)
        end
    end

    -- Кнопка SWITCH (R2) справа всегда видна
    drawGameBtn(840, 570, 140, 40, {0.68, 0.32, 0.1}, {0.96, 0.78, 0.2}, "R2", switchLabel)
end

function poker.keypressed(key)
    if key == "r2" or key == "c" or key == "tab" then
        poker.toggleControlMode()
        return
    end

    if key == "y" then
        if poker.phase == "draw" and poker.betDeducted then
            audio.play("fail")
            return
        end
        betModal.open(poker.bet, 100, economy.getBalance(), function(newBet)
            poker.bet = newBet
        end)
        return
    end

    if poker.phase == "draw" and poker.autoRestartTimer == 0 then
        if key == "left" then
            poker.focusCard = (poker.focusCard == 1) and 5 or (poker.focusCard - 1)
            audio.play("click")
        elseif key == "right" then
            poker.focusCard = (poker.focusCard == 5) and 1 or (poker.focusCard + 1)
            audio.play("click")
        end

        if poker.controlMode == 0 then
            if key == "a" then
                poker.toggleHold(poker.focusCard)
            elseif key == "x" or key == "space" or key == "return" then
                poker.doDraw()
            end
        else
            if key == "down" then
                poker.toggleHold(poker.focusCard)
            elseif key == "up" then
                poker.doDraw()
            end
        end

        if key == "1" then poker.toggleHold(1)
        elseif key == "2" then poker.toggleHold(2)
        elseif key == "3" then poker.toggleHold(3)
        elseif key == "4" then poker.toggleHold(4)
        elseif key == "5" then poker.toggleHold(5)
        end
    end
end

function poker.mousepressed(x, y)
    -- Окно ставки [Y] (щедрая зона клика)
    if x >= 40 and x <= 335 and y >= 550 and y <= 620 then
        if poker.phase == "draw" and poker.betDeducted then
            audio.play("fail")
            return true
        end
        betModal.open(poker.bet, 100, economy.getBalance(), function(newBet)
            poker.bet = newBet
        end)
        return true
    end

    -- Клик по картам: y in 150..440
    if poker.phase == "draw" and poker.autoRestartTimer == 0 and y >= 150 and y <= 440 then
        for i = 1, 5 do
            local cx = 45 + (i - 1) * 192
            if x >= cx and x <= cx + 166 then
                poker.focusCard = i
                poker.toggleHold(i)
                return true
            end
        end
    end

    -- Кнопка HOLD: 510..650
    if poker.phase == "draw" and poker.autoRestartTimer == 0 and x >= 510 and x <= 650 and y >= 570 and y <= 610 then
        poker.toggleHold(poker.focusCard)
        return true
    end

    -- Кнопка DRAW: 675..820
    if poker.phase == "draw" and poker.autoRestartTimer == 0 and x >= 675 and x <= 820 and y >= 570 and y <= 610 then
        poker.doDraw()
        return true
    end

    -- Кнопка SWITCH: 840..980
    if x >= 840 and x <= 980 and y >= 570 and y <= 610 then
        poker.toggleControlMode()
        return true
    end

    return false
end

return poker
