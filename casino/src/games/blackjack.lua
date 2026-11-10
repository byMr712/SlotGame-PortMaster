local bj = {}

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

bj.bet = 1000
bj.deck = {}
bj.playerHand = {}
bj.dealerHand = {}
bj.gameOver = true
bj.hasHit = false
bj.statusKey = ""
bj.statusWin = 0
bj.dealAnim = 1
bj.betDeducted = false
bj.autoRestartTimer = 0
bj.controlMode = 0 -- 0: D-Pad (Up/Down/Left), 1: ABX (X=Hit, B=Stand, A=Double)

function bj.toggleControlMode()
    bj.controlMode = (bj.controlMode == 0) and 1 or 0
    audio.play("click")
end

function bj.getStatusText()
    if not bj.statusKey or bj.statusKey == "" then return "" end
    if bj.statusKey == "blackjack" then
        return string.format("★ %s! +%s ★", i18n.t("blackjack"), economy.format(bj.statusWin or 0))
    elseif bj.statusKey == "player_wins" then
        return string.format("%s +%s", i18n.t("player_wins"), economy.format(bj.statusWin or 0))
    else
        return i18n.t(bj.statusKey)
    end
end

local cardBackSymbols = { "stardrop", "prism", "ancient", "cherry", "parsnip" }
bj.currentCardBack = "stardrop"

local function pickNewCardBack()
    local available = {}
    for _, s in ipairs(cardBackSymbols) do
        if s ~= bj.currentCardBack then
            table.insert(available, s)
        end
    end
    return available[math.random(#available)]
end

local suits = { "spade", "heart", "diamond", "club" }
local values = {
    { name = "2", val = 2 }, { name = "3", val = 3 }, { name = "4", val = 4 },
    { name = "5", val = 5 }, { name = "6", val = 6 }, { name = "7", val = 7 },
    { name = "8", val = 8 }, { name = "9", val = 9 }, { name = "10", val = 10 },
    { name = "J", val = 10 }, { name = "Q", val = 10 }, { name = "K", val = 10 },
    { name = "A", val = 11 }
}

function bj.createDeck()
    bj.deck = {}
    for d = 1, 6 do
        for _, s in ipairs(suits) do
            for _, v in ipairs(values) do
                table.insert(bj.deck, { suit = s, name = v.name, val = v.val })
            end
        end
    end
    -- Fisher-Yates
    for i = #bj.deck, 2, -1 do
        local j = math.random(1, i)
        bj.deck[i], bj.deck[j] = bj.deck[j], bj.deck[i]
    end
end

function bj.calculateScore(hand)
    local score = 0
    for _, c in ipairs(hand) do
        score = score + c.val
    end
    return score
end

function bj.update(dt)
    -- Автоматическая сдача карт, если игра еще не запускалась или стол пуст
    if #bj.playerHand == 0 and economy.getBalance() > 0 and not bankruptModal.active then
        bj.deal()
    end

    for _, c in ipairs(bj.playerHand) do
        if c.anim and c.anim < 1 then
            c.anim = math.min(1, c.anim + dt * 2.2)
        end
    end
    for _, c in ipairs(bj.dealerHand) do
        if c.anim and c.anim < 1 then
            c.anim = math.min(1, c.anim + dt * 2.2)
        end
    end

    -- Авто-раскладка новой партии через 2 секунды после завершения
    if bj.gameOver and bj.autoRestartTimer and bj.autoRestartTimer > 0 then
        if economy.getBalance() <= 0 then
            bj.autoRestartTimer = 0
        else
            bj.autoRestartTimer = bj.autoRestartTimer - dt
            if bj.autoRestartTimer <= 0 then
                bj.autoRestartTimer = 0
                bj.deal()
            end
        end
    end
end

function bj.deal()
    if economy.getBalance() <= 0 then return end
    if #bj.deck < 52 then bj.createDeck() end

    audio.play("click")
    bj.gameOver = false
    bj.hasHit = false
    bj.betDeducted = false
    bj.autoRestartTimer = 0
    bj.currentCardBack = pickNewCardBack()

    local function dealInitialTwo(anim1, anim2)
        local c1 = table.remove(bj.deck)
        local c2 = table.remove(bj.deck)
        while (c1.val + c2.val) >= 21 do
            table.insert(bj.deck, math.random(1, #bj.deck), c2)
            c2 = table.remove(bj.deck)
        end
        c1.anim = anim1
        c2.anim = anim2
        return c1, c2
    end

    local p1, p2 = dealInitialTwo(0.0, -0.30)
    local d1, d2 = dealInitialTwo(-0.15, -0.45)

    bj.playerHand = { p1, p2 }
    bj.dealerHand = { d1, d2 }

    -- Бот заранее имеет все карты на столе (добирает сразу при сдаче, в закрытую)
    local dIdx = 2
    while bj.calculateScore(bj.dealerHand) < 17 do
        dIdx = dIdx + 1
        local extraCard = table.remove(bj.deck)
        extraCard.anim = -(dIdx * 0.15)
        table.insert(bj.dealerHand, extraCard)
    end

    -- Если у дилера выпало 21, то он с шансом 30% добавляет себе еще карту
    if bj.calculateScore(bj.dealerHand) == 21 and math.random() < 0.30 then
        dIdx = dIdx + 1
        local extraCard = table.remove(bj.deck)
        extraCard.anim = -(dIdx * 0.15)
        table.insert(bj.dealerHand, extraCard)
    end

    bj.statusKey = ""
    bj.statusWin = 0
end

function bj.hit()
    if #bj.playerHand == 0 then
        bj.deal()
    end
    if bj.gameOver then return end

    -- Ставка забирается только когда игрок решил взять карту (подкинуть)
    if not bj.betDeducted then
        if not economy.spend(bj.bet) then
            audio.play("fail")
            bj.autoRestartTimer = 0
            bankruptModal.check()
            return
        end
        bj.betDeducted = true
    end

    bj.hasHit = true
    audio.play("click")
    local c = table.remove(bj.deck)
    c.anim = 0.0
    table.insert(bj.playerHand, c)

    local score = bj.calculateScore(bj.playerHand)
    if score > 21 then
        bj.gameOver = true
        bj.statusKey = "bust"
        audio.play("fail")
        if economy.getBalance() <= 0 then
            bj.autoRestartTimer = 0
            bankruptModal.check()
        else
            bj.autoRestartTimer = 2.0
            if bj.bet > economy.getBalance() then
                bj.bet = math.max(1, economy.getBalance())
            end
        end
    end
end

function bj.stand()
    if #bj.playerHand == 0 then
        bj.deal()
    end
    if bj.gameOver then return end

    if not bj.betDeducted then
        if not economy.spend(bj.bet) then
            audio.play("fail")
            bj.autoRestartTimer = 0
            bankruptModal.check()
            return
        end
        bj.betDeducted = true
    end

    bj.gameOver = true

    local p = bj.calculateScore(bj.playerHand)
    local d = bj.calculateScore(bj.dealerHand)
    local playerBJ = (p == 21 and #bj.playerHand == 2)
    local dealerBJ = (d == 21 and #bj.dealerHand == 2)

    -- Натуральный блэкджек (3:2)
    if playerBJ and not dealerBJ then
        local win = bj.bet * 2.5
        economy.add(win)
        bj.statusKey = "blackjack"
        bj.statusWin = win
        audio.play("win")
    elseif dealerBJ and not playerBJ then
        bj.statusKey = "dealer_bj"
        audio.play("fail")
    elseif p > 21 then
        bj.statusKey = "bust"
        audio.play("fail")
    elseif d > 21 or p > d then
        local win = bj.bet * 2
        economy.add(win)
        bj.statusKey = "player_wins"
        bj.statusWin = win
        audio.play("win")
    elseif p == d then
        economy.add(bj.bet)
        bj.statusKey = "push"
        audio.play("click")
    else
        bj.statusKey = "dealer_wins"
        audio.play("fail")
    end

    -- Проверка банкротства или снижение ставки до остатка баланса
    if economy.getBalance() <= 0 then
        bj.autoRestartTimer = 0
        bankruptModal.check()
    else
        bj.autoRestartTimer = 2.0
        if bj.bet > economy.getBalance() then
            bj.bet = math.max(1, economy.getBalance())
        end
    end
end

function bj.double()
    if #bj.playerHand == 0 then
        bj.deal()
    end
    if bj.gameOver or #bj.playerHand ~= 2 then return end
    local needed = bj.betDeducted and bj.bet or (bj.bet * 2)
    if not economy.canAfford(needed) then
        audio.play("fail")
        return
    end

    if not bj.betDeducted then
        economy.spend(bj.bet)
        bj.betDeducted = true
    end

    economy.spend(bj.bet)
    bj.bet = bj.bet * 2
    bj.hit()
    if not bj.gameOver then bj.stand() end
    bj.bet = bj.bet / 2
end

local function drawEmptyCardSlot(x, y, label)
    love.graphics.setColor(0.12, 0.05, 0.02, 0.4)
    love.graphics.rectangle("fill", x, y, 152, 212, 6)
    love.graphics.setColor(0.55, 0.26, 0.08, 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, 152, 212, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.7, 0.5, 0.2, 0.35)
    local oldFont = love.graphics.getFont()
    local cFont = getCardFont()
    if cFont then love.graphics.setFont(cFont) end
    local tw = love.graphics.getFont():getWidth(label)
    love.graphics.print(label, x + (152 - tw) / 2, y + 90)
    love.graphics.setFont(oldFont)
end

local function drawCard(c, x, y, hidden)
    local cw, ch = 152, 212
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", x, y, cw, ch, 6)
    
    if hidden then
        love.graphics.setColor(0.35, 0.15, 0.05)
        love.graphics.rectangle("fill", x + 3, y + 3, cw - 6, ch - 6, 4)
        sprites.draw(bj.currentCardBack or "stardrop", x + cw / 2, y + ch / 2, 64)
        return
    end

    love.graphics.setColor(0.98, 0.93, 0.82)
    love.graphics.rectangle("fill", x + 3, y + 3, cw - 6, ch - 6, 4)

    local isRed = (c.suit == "heart" or c.suit == "diamond")
    if isRed then
        love.graphics.setColor(0.75, 0.15, 0.1)
    else
        love.graphics.setColor(0.1, 0.05, 0.02)
    end

    local oldFont = love.graphics.getFont()
    local cFont = getCardFont()
    if cFont then love.graphics.setFont(cFont) end

    love.graphics.print(c.name, x + 10, y + 10)
    local tw = love.graphics.getFont():getWidth(c.name)
    love.graphics.print(c.name, x + cw - 12 - tw, y + ch - 34)

    love.graphics.setFont(oldFont)

    sprites.draw(c.suit, x + cw / 2, y + ch / 2, 54)
end

function bj.draw()
    local font = love.graphics.getFont()
    local cw = 148
    local gap = 16

    local numDealer = math.max(2, #bj.dealerHand)
    local dTotalW = numDealer * cw + (numDealer - 1) * gap
    local dStartX = math.floor((1024 - dTotalW) / 2)

    local numPlayer = math.max(2, #bj.playerHand)
    local pTotalW = numPlayer * cw + (numPlayer - 1) * gap
    local pStartX = math.floor((1024 - pTotalW) / 2)

    local dealerCardsY = 105
    local playerCardsY = 345

    -- 1. Подпись и карты дилера
    love.graphics.setColor(1, 0.88, 0.4)
    local dScore = "--"
    if #bj.dealerHand > 0 then
        dScore = bj.gameOver and tostring(bj.calculateScore(bj.dealerHand)) or (bj.dealerHand[1] and tostring(bj.dealerHand[1].val) or "??")
    end
    local dStr = string.format("%s: %s", i18n.t("dealer_gus"), dScore)
    local dtw = font and font:getWidth(dStr) or (#dStr * 8)
    love.graphics.print(dStr, 512 - dtw / 2, dealerCardsY - 24)

    if #bj.dealerHand == 0 then
        drawEmptyCardSlot(dStartX, dealerCardsY, "CARD 1")
        drawEmptyCardSlot(dStartX + cw + gap, dealerCardsY, "CARD 2")
    else
        for i, c in ipairs(bj.dealerHand) do
            local anim = c.anim or 1
            if anim >= 0 then
                local p = math.min(1, anim)
                local ease = 1 - math.pow(1 - p, 3)
                local yOff = (1 - ease) * -65
                local xOff = (1 - ease) * 35
                drawCard(c, dStartX + (i - 1) * (cw + gap) + xOff, dealerCardsY + yOff, (i > 1 and not bj.gameOver))
            end
        end
    end

    -- 2. Результат раздачи (появляется только после завершения руки)
    local sTxt = bj.getStatusText()
    if bj.gameOver and #bj.playerHand > 0 and sTxt ~= "" then
        love.graphics.setColor(0.18, 0.08, 0.03, 0.95)
        local tw = font and font:getWidth(sTxt) or (#sTxt * 8)
        local pw = math.max(260, tw + 48)
        local px = 512 - pw / 2
        love.graphics.rectangle("fill", px, 316, pw, 26, 5)
        love.graphics.setColor(0.78, 0.52, 0.12)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, 316, pw, 26, 5)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.print(sTxt, 512 - tw / 2, 321)
    end

    -- 3. Подпись и карты игрока
    love.graphics.setColor(1, 0.88, 0.4)
    local pScore = #bj.playerHand > 0 and tostring(bj.calculateScore(bj.playerHand)) or "--"
    local pStr = string.format("%s: %s", i18n.t("player"), pScore)
    local ptw = font and font:getWidth(pStr) or (#pStr * 8)
    love.graphics.print(pStr, 512 - ptw / 2, playerCardsY - 24)

    if #bj.playerHand == 0 then
        drawEmptyCardSlot(pStartX, playerCardsY, "CARD 1")
        drawEmptyCardSlot(pStartX + cw + gap, playerCardsY, "CARD 2")
    else
        for i, c in ipairs(bj.playerHand) do
            local anim = c.anim or 1
            if anim >= 0 then
                local p = math.min(1, anim)
                local ease = 1 - math.pow(1 - p, 3)
                local yOff = (1 - ease) * -65
                local xOff = (1 - ease) * 35
                drawCard(c, pStartX + (i - 1) * (cw + gap) + xOff, playerCardsY + yOff, false)
            end
        end
    end

    -- Нижняя панель действий
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 560, 944, 60, 4)

    -- Панель ставки [Y]
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 55, 566, 260, 48, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.rectangle("line", 55, 566, 260, 48, 4)

    -- Желтый значок [Y]
    love.graphics.setColor(0.96, 0.78, 0.2)
    love.graphics.circle("fill", 76, 590, 12)
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 76, 590, 12)
    love.graphics.setLineWidth(1)
    love.graphics.print("Y", 72, 583)

    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print(i18n.t("bet") .. ":", 96, 574)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(economy.format(bj.bet), 96, 590)

    if not bj.gameOver and bj.hasHit then
        love.graphics.setColor(0.6, 0.5, 0.4)
        love.graphics.print("(LOCKED)", 205, 590)
    end

    local function drawGameBtn(bx, by, bw, bh, bCol, keyCol, dir, label)
        -- Темная тень
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.rectangle("fill", bx, by, bw, bh, 4)
        -- Корпус
        love.graphics.setColor(bCol[1], bCol[2], bCol[3])
        love.graphics.rectangle("fill", bx + 2, by + 2, bw - 4, bh - 4, 3)
        -- Фаска сверху
        love.graphics.setColor(bCol[1] * 1.35, bCol[2] * 1.35, bCol[3] * 1.35)
        love.graphics.rectangle("line", bx + 2, by + 2, bw - 4, bh - 4, 3)

        -- Круглая кнопка направления D-Pad
        local cx = bx + 18
        local cy = by + bh / 2
        love.graphics.setColor(keyCol[1], keyCol[2], keyCol[3])
        love.graphics.circle("fill", cx, cy, 11)
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, 11)
        love.graphics.setLineWidth(1)

        -- Стрелка D-Pad или буквенная метка (пиксель-арт геометрия)
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
        elseif dir == "left" then
            love.graphics.rectangle("fill", cx - 5, cy - 1, 2, 2)
            love.graphics.rectangle("fill", cx - 3, cy - 3, 2, 6)
            love.graphics.rectangle("fill", cx - 1, cy - 5, 2, 10)
            love.graphics.rectangle("fill", cx + 1, cy - 2, 4, 4)
        else
            local font = love.graphics.getFont()
            local kw = font and font:getWidth(dir) or (#dir * 8)
            local kh = font and font:getHeight() or 14
            local tx = math.floor(cx - kw / 2)
            local ty = math.floor(cy - kh / 2)
            love.graphics.print(dir, tx, ty)
            love.graphics.print(dir, tx + 1, ty)
        end

        -- Текст действия
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label, bx + 36, cy - 7)
    end

    local hitLabel = i18n.t("hit")
    local standLabel = i18n.t("stand")
    local doubleLabel = i18n.t("double")
    local switchLabel = i18n.t("switch")

    if bj.controlMode == 0 then
        drawGameBtn(345, 570, 140, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "up", hitLabel)
        drawGameBtn(505, 570, 145, 40, {0.75, 0.16, 0.1}, {0.95, 0.32, 0.3}, "down", standLabel)
        drawGameBtn(670, 570, 150, 40, {0.68, 0.32, 0.1}, {0.96, 0.78, 0.2}, "left", doubleLabel)
    else
        drawGameBtn(345, 570, 140, 40, {0.68, 0.32, 0.1}, {0.32, 0.62, 0.96}, "X", hitLabel)
        drawGameBtn(505, 570, 145, 40, {0.75, 0.16, 0.1}, {0.95, 0.32, 0.3}, "B", standLabel)
        drawGameBtn(670, 570, 150, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "A", doubleLabel)
    end
    -- Первая справа кнопка SWITCH (R2), не меняется никогда
    drawGameBtn(840, 570, 140, 40, {0.68, 0.32, 0.1}, {0.96, 0.78, 0.2}, "R2", switchLabel)
end

function bj.resetTable()
    bj.playerHand = {}
    bj.dealerHand = {}
    bj.gameOver = true
    bj.hasHit = false
    bj.betDeducted = false
    bj.autoRestartTimer = 0
    bj.statusKey = ""
    bj.statusWin = 0
    bj.result = nil
    bj.state = "betting"
end

function bj.keypressed(key)
    if key == "r2" or key == "c" or key == "tab" then
        bj.toggleControlMode()
        return
    end

    if bj.controlMode == 0 then
        if key == "up" then
            bj.hit()
        elseif key == "down" then
            bj.stand()
        elseif key == "left" then
            bj.double()
        end
    else
        if key == "x" then
            bj.hit()
        elseif key == "b" then
            bj.stand()
        elseif key == "a" then
            bj.double()
        end
    end

    if key == "y" then
        if not bj.gameOver and bj.hasHit then
            audio.play("fail")
            return
        end
        betModal.open(bj.bet, 100, economy.getBalance(), function(newBet)
            bj.bet = newBet
        end)
    end
end

function bj.mousepressed(x, y)
    -- Окно ставки [Y] (щедрая зона клика)
    if x >= 40 and x <= 335 and y >= 550 and y <= 620 then
        if not bj.gameOver and bj.hasHit then
            audio.play("fail")
            return true
        end
        betModal.open(bj.bet, 100, economy.getBalance(), function(newBet)
            bj.bet = newBet
        end)
        return true
    end

    -- Кнопки действий:
    -- HIT: 345, 570, 140, 40
    if x >= 345 and x <= 485 and y >= 570 and y <= 610 then
        bj.hit()
        return true
    -- STAND: 505, 570, 145, 40
    elseif x >= 505 and x <= 650 and y >= 570 and y <= 610 then
        bj.stand()
        return true
    -- DOUBLE: 670, 570, 150, 40
    elseif x >= 670 and x <= 820 and y >= 570 and y <= 610 then
        bj.double()
        return true
    -- SWITCH (R2, первая справа): 840, 570, 140, 40
    elseif x >= 840 and x <= 980 and y >= 570 and y <= 610 then
        bj.toggleControlMode()
        return true
    end

    return false
end

return bj
