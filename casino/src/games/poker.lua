local poker = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")
local fonts = require("src.core.fonts")
local ui = require("src.core.ui")
local betModal = require("src.core.bet_modal")
local bankruptModal = require("src.core.bankrupt_modal")

poker.bet = 500
poker.deck = {}
poker.hand = {}
poker.holds = { false, false, false, false, false }
poker.phase = "draw"
poker.focusCard = 1
poker.comboKey = "select_hold"
poker.comboWin = 0
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
    local repIdx = 0
    for i = 1, 5 do
        if not poker.holds[i] then
            local c = table.remove(poker.deck)
            c.anim = -(repIdx * 0.10)
            repIdx = repIdx + 1
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
    if #poker.hand == 0 and economy.getBalance() > 0 and not bankruptModal.active then
        poker.deal()
    end

    for _, c in ipairs(poker.hand) do
        if c.anim and c.anim < 1 then
            c.anim = math.min(1, c.anim + dt * 4.0)
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

function poker.draw()
    -- 1. Верхняя таблица комбинаций (5 утопленных плашек ровно как в HTML-макете)
    ui.drawBrassPlaque(34, 90, 956, 64, 4)

    local combos = {
        { key = "royal_flush", en = "ROYAL", ru = "РОЯЛЬ", mult = "x800" },
        { key = "straight_flush", en = "STR FLUSH", ru = "СТРИТ ФЛЕШ", mult = "x50" },
        { key = "four_of_a_kind", en = "4 OF KIND", ru = "КАРЕ", mult = "x25" },
        { key = "full_house", en = "FULL HOUSE", ru = "ФУЛЛ ХАУС", mult = "x9" },
        { key = "jacks_or_better", en = "JACKS+", ru = "ВАЛЕТЫ+", mult = "x1" }
    }

    local gap = 8
    local boxW = math.floor((956 - 16 - 4 * gap) / 5)
    local boxH = 48
    local boxY = 98

    for i, c in ipairs(combos) do
        local bx = 34 + 8 + (i - 1) * (boxW + gap)
        local isWinCombo = (poker.phase == "result" and poker.comboKey == c.key)

        -- Фон ячейки
        if isWinCombo then
            love.graphics.setColor(92/255, 40/255, 14/255)
        else
            love.graphics.setColor(32/255, 12/255, 5/255)
        end
        love.graphics.rectangle("fill", bx, boxY, boxW, boxH, 4)

        if isWinCombo then
            love.graphics.setColor(1, 0.88, 0.4)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", bx, boxY, boxW, boxH, 4)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(92/255, 40/255, 14/255)
            love.graphics.rectangle("line", bx, boxY, boxW, boxH, 4)
        end

        -- Название комбинации
        local cName = (i18n.current == "ru") and c.ru or c.en
        love.graphics.setFont(fonts.xs)
        love.graphics.setColor(1, 0.88, 0.4)
        local ntw = fonts.xs:getWidth(cName)
        love.graphics.print(cName, math.floor(bx + (boxW - ntw) / 2), boxY + 8)

        -- Множитель
        love.graphics.setFont(fonts.sm)
        love.graphics.setColor(255/255, 224/255, 102/255)
        local mtw = fonts.sm:getWidth(c.mult)
        love.graphics.print(c.mult, math.floor(bx + (boxW - mtw) / 2), boxY + 26)
    end

    -- 2. 5 карт покера (150x214, центрированы по горизонтали и вертикали)
    local cw = 150
    local ch = 214
    local cardGap = 20
    local totalCardsW = 5 * cw + 4 * cardGap
    local startX = math.floor((1024 - totalCardsW) / 2)
    local startY = 224

    for i, c in ipairs(poker.hand) do
        local anim = c.anim or 1
        if anim >= 0 then
            local p = math.min(1, anim)
            local ease = 1 - math.pow(1 - p, 3)
            local yOff = (1 - ease) * -75
            local xOff = (1 - ease) * 35
            local x = startX + (i - 1) * (cw + cardGap) + xOff
            local isFocus = (poker.phase == "draw" and i == (poker.focusCard or 1))
            ui.drawCard(c, x, startY + yOff, cw, ch, poker.holds[i], isFocus, false)
        end
    end

    -- 3. Статус / Комбинация по центру
    local cText = poker.getComboText()
    if cText and cText ~= "" then
        love.graphics.setFont(fonts.sm)
        local tw = fonts.sm:getWidth(cText)
        local pw = math.max(300, tw + 48)
        local px = math.floor(512 - pw / 2)
        ui.drawBrassPlaque(px, 480, pw, 38, 4)
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.print(cText, math.floor(512 - tw / 2), 492)
    end

    -- 4. Нижняя панель действий (точно вровень со всеми залами)
    ui.drawBrassPlaque(34, 678, 956, 64, 4)

    -- Панель ставки [Y]
    local betX = 48
    local betY = 684
    local betW = 180
    local betH = 52
    love.graphics.setColor(27/255, 10/255, 4/255, 1)
    love.graphics.rectangle("fill", betX, betY, betW, betH, 4)
    love.graphics.setColor(120/255, 79/255, 24/255, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", betX, betY, betW, betH, 4)
    love.graphics.setLineWidth(1)

    -- Желтый значок [Y]
    ui.drawButtonBadge(betX + 22, betY + betH / 2, 12, "Y")

    love.graphics.setFont(fonts.xs)
    love.graphics.setColor(255/255, 234/255, 173/255, 1)
    love.graphics.print(i18n.t("bet") .. ":", betX + 44, betY + 9)
    love.graphics.setFont(fonts.md)
    love.graphics.setColor(1, 0.88, 0.4, 1)
    love.graphics.print(economy.format(poker.bet), betX + 44, betY + 25)

    if poker.phase == "draw" and poker.betDeducted then
        love.graphics.setFont(fonts.xs)
        love.graphics.setColor(0.6, 0.5, 0.4)
        love.graphics.print("(LOCKED)", betX + 96, betY + 9)
    end

    -- Кнопки действий: HOLD (A), DRAW (X), SWITCH (R2)
    local btnY = 686
    local btnH = 48

    -- HOLD
    local holdX = 420
    local holdW = 140
    ui.drawSaloonButton(holdX, btnY, holdW, btnH, "")
    local holdLabel = i18n.t("hold")
    love.graphics.setFont(fonts.lg)
    local htw = fonts.lg:getWidth(holdLabel)
    local hth = fonts.lg:getHeight()
    local totalHldW = 22 + 10 + htw
    local hldStartX = holdX + math.floor((holdW - totalHldW) / 2)
    local holdBadge = (poker.controlMode == 0) and "A" or "down"
    ui.drawButtonBadge(hldStartX + 11, btnY + btnH / 2, 11, holdBadge, 1.0, "green")
    love.graphics.setFont(fonts.lg)
    love.graphics.setColor(255/255, 248/255, 235/255)
    love.graphics.print(holdLabel, hldStartX + 32, math.floor(btnY + (btnH - hth) / 2))

    -- DRAW
    local drawX = 574
    local drawW = 190
    ui.drawSaloonButtonRed(drawX, btnY, drawW, btnH)
    local drawLabel = i18n.t("draw")
    love.graphics.setFont(fonts.lg)
    local dtw = fonts.lg:getWidth(drawLabel)
    local dth = fonts.lg:getHeight()
    local totalDrawW = 24 + 12 + dtw
    local drawStartX = drawX + math.floor((drawW - totalDrawW) / 2)
    local drawBadge = (poker.controlMode == 0) and "X" or "up"
    ui.drawButtonBadge(drawStartX + 12, btnY + btnH / 2, 12, drawBadge, 1.0, "blue")
    love.graphics.setFont(fonts.lg)
    love.graphics.setColor(59/255, 8/255, 2/255)
    love.graphics.print(drawLabel, drawStartX + 36 + 2, math.floor(btnY + (btnH - dth) / 2) + 2)
    love.graphics.setColor(255/255, 255/255, 255/255)
    love.graphics.print(drawLabel, drawStartX + 36, math.floor(btnY + (btnH - dth) / 2))

    -- SWITCH (R2)
    local swX = 778
    local swW = 198
    ui.drawSaloonButton(swX, btnY, swW, btnH, "")
    local switchLabel = i18n.t("switch")
    love.graphics.setFont(fonts.lg)
    local swtw = fonts.lg:getWidth(switchLabel)
    local swth = fonts.lg:getHeight()
    local totalSwW = 22 + 10 + swtw
    local swStartX = swX + math.floor((swW - totalSwW) / 2)
    ui.drawButtonBadge(swStartX + 11, btnY + btnH / 2, 11, "R2", 1.0, "yellow")
    love.graphics.setFont(fonts.lg)
    love.graphics.setColor(255/255, 248/255, 235/255)
    love.graphics.print(switchLabel, swStartX + 32, math.floor(btnY + (btnH - swth) / 2))
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
    -- Окно ставки [Y]
    if x >= 44 and x <= 235 and y >= 680 and y <= 740 then
        if poker.phase == "draw" and poker.betDeducted then
            audio.play("fail")
            return true
        end
        betModal.open(poker.bet, 100, economy.getBalance(), function(newBet)
            poker.bet = newBet
        end)
        return true
    end

    -- Клик по картам
    local cw = 150
    local cardGap = 20
    local totalCardsW = 5 * cw + 4 * cardGap
    local startX = math.floor((1024 - totalCardsW) / 2)
    local startY = 224

    if poker.phase == "draw" and poker.autoRestartTimer == 0 and y >= 210 and y <= 450 then
        for i = 1, 5 do
            local cx = startX + (i - 1) * (cw + cardGap)
            if x >= cx and x <= cx + cw then
                poker.focusCard = i
                poker.toggleHold(i)
                return true
            end
        end
    end

    -- Кнопки действий:
    -- HOLD: 420, 686, 140, 48
    if poker.phase == "draw" and poker.autoRestartTimer == 0 and x >= 420 and x <= 560 and y >= 680 and y <= 740 then
        poker.toggleHold(poker.focusCard)
        return true
    end

    -- DRAW: 574, 686, 190, 48
    if poker.phase == "draw" and poker.autoRestartTimer == 0 and x >= 574 and x <= 764 and y >= 680 and y <= 740 then
        poker.doDraw()
        return true
    end

    -- SWITCH: 778, 686, 198, 48
    if x >= 778 and x <= 978 and y >= 680 and y <= 740 then
        poker.toggleControlMode()
        return true
    end

    return false
end

return poker