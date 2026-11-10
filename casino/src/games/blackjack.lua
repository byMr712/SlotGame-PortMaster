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
bj.statusText = ""
bj.dealAnim = 1

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
    local aces = 0
    for _, c in ipairs(hand) do
        score = score + c.val
        if c.name == "A" then aces = aces + 1 end
    end
    while score > 21 and aces > 0 do
        score = score - 10
        aces = aces - 1
    end
    return score
end

function bj.update(dt)
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
end

function bj.deal()
    if not economy.spend(bj.bet) then
        audio.play("fail")
        return
    end

    if #bj.deck < 52 then bj.createDeck() end

    audio.play("click")
    bj.gameOver = false
    bj.hasHit = false
    bj.currentCardBack = pickNewCardBack()

    local p1 = table.remove(bj.deck); p1.anim = 0.0
    local d1 = table.remove(bj.deck); d1.anim = -0.15
    local p2 = table.remove(bj.deck); p2.anim = -0.30
    local d2 = table.remove(bj.deck); d2.anim = -0.45

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

    bj.statusText = ""
end

function bj.hit()
    if bj.gameOver then return end
    bj.hasHit = true
    audio.play("click")
    local c = table.remove(bj.deck)
    c.anim = 0.0
    table.insert(bj.playerHand, c)

    local score = bj.calculateScore(bj.playerHand)
    if score > 21 then
        bj.gameOver = true
        bj.statusText = i18n.t("bust")
        audio.play("fail")
        if bankruptModal.check() then
            -- открыто окно банкротства
        elseif bj.bet > economy.getBalance() then
            bj.bet = 100
        end
    end
end

function bj.stand()
    if bj.gameOver then return end
    bj.gameOver = true

    local p = bj.calculateScore(bj.playerHand)
    local d = bj.calculateScore(bj.dealerHand)
    local playerBJ = (p == 21 and #bj.playerHand == 2)
    local dealerBJ = (d == 21 and #bj.dealerHand == 2)

    -- Натуральный блэкджек (3:2)
    if playerBJ and not dealerBJ then
        local win = bj.bet * 2.5
        economy.add(win)
        bj.statusText = string.format("★ BLACKJACK! +%s ★", economy.format(win))
        audio.play("win")
    elseif dealerBJ and not playerBJ then
        bj.statusText = "DEALER BLACKJACK"
        audio.play("fail")
    elseif d > 21 or p > d then
        local win = bj.bet * 2
        economy.add(win)
        bj.statusText = string.format("%s +%s", i18n.t("player_wins"), economy.format(win))
        audio.play("win")
    elseif p == d then
        economy.add(bj.bet)
        bj.statusText = i18n.t("push")
        audio.play("click")
    else
        bj.statusText = i18n.t("dealer_wins")
        audio.play("fail")
    end

    -- Проверка банкротства или снижение ставки до остатка баланса
    if bankruptModal.check() then
        -- открыто окно банкротства
    elseif bj.bet > economy.getBalance() then
        bj.bet = 100
    end
end

function bj.double()
    if bj.gameOver or #bj.playerHand ~= 2 or not economy.canAfford(bj.bet) then return end
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
    if bj.gameOver and #bj.playerHand > 0 and bj.statusText ~= "" then
        love.graphics.setColor(0.18, 0.08, 0.03, 0.95)
        local tw = font and font:getWidth(bj.statusText) or (#bj.statusText * 8)
        local pw = math.max(260, tw + 48)
        local px = 512 - pw / 2
        love.graphics.rectangle("fill", px, 316, pw, 26, 5)
        love.graphics.setColor(0.78, 0.52, 0.12)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px, 316, pw, 26, 5)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.print(bj.statusText, 512 - tw / 2, 321)
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

        -- Стрелка D-Pad (пиксель-арт геометрия без глитчей растрирования)
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
        elseif dir == "right" then
            love.graphics.rectangle("fill", cx - 5, cy - 2, 4, 4)
            love.graphics.rectangle("fill", cx - 1, cy - 5, 2, 10)
            love.graphics.rectangle("fill", cx + 1, cy - 3, 2, 6)
            love.graphics.rectangle("fill", cx + 3, cy - 1, 2, 2)
        end

        -- Текст действия
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label, bx + 36, cy - 7)
    end

    drawGameBtn(345, 570, 140, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "up", "HIT")
    drawGameBtn(505, 570, 145, 40, {0.75, 0.16, 0.1}, {0.95, 0.32, 0.3}, "down", "STAND")
    drawGameBtn(670, 570, 150, 40, {0.68, 0.32, 0.1}, {0.96, 0.78, 0.2}, "left", "DOUBLE")
    drawGameBtn(840, 570, 140, 40, {0.68, 0.32, 0.1}, {0.32, 0.62, 0.96}, "right", "DEAL")
end

function bj.keypressed(key)
    if key == "up" then
        bj.hit()
    elseif key == "down" then
        bj.stand()
    elseif key == "left" then
        bj.double()
    elseif key == "right" then
        if bj.gameOver then bj.deal() end
    elseif key == "y" then
        if not bj.gameOver and bj.hasHit then
            audio.play("fail")
            return
        end
        betModal.open(bj.bet, 100, economy.getBalance(), function(newBet)
            bj.bet = newBet
        end)
    elseif key == "a" then
        bj.hit()
    elseif key == "b" then
        bj.stand()
    elseif key == "x" or key == "space" or key == "return" then
        if bj.gameOver then bj.deal() end
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
    -- HIT (вверх): 345, 570, 140, 40
    if x >= 345 and x <= 485 and y >= 570 and y <= 610 then
        bj.hit()
        return true
    -- STAND (вниз): 505, 570, 145, 40
    elseif x >= 505 and x <= 650 and y >= 570 and y <= 610 then
        bj.stand()
        return true
    -- DOUBLE (влево): 670, 570, 150, 40
    elseif x >= 670 and x <= 820 and y >= 570 and y <= 610 then
        bj.double()
        return true
    -- DEAL (вправо): 840, 570, 140, 40
    elseif x >= 840 and x <= 980 and y >= 570 and y <= 610 then
        if bj.gameOver then bj.deal() end
        return true
    end

    return false
end

return bj
