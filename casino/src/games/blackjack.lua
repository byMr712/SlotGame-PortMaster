local bj = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")
local fonts = require("src.core.fonts")
local ui = require("src.core.ui")
local betModal = require("src.core.bet_modal")
local bankruptModal = require("src.core.bankrupt_modal")

bj.bet = 1000
bj.deck = {}
bj.playerHand = {}
bj.dealerHand = {}
bj.gameOver = true
bj.hasHit = false
bj.statusKey = ""
bj.statusWin = 0
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
    if #bj.playerHand == 0 and economy.getBalance() > 0 and not bankruptModal.active then
        bj.deal()
    end

    for _, c in ipairs(bj.playerHand) do
        if c.anim and c.anim < 1 then
            c.anim = math.min(1, c.anim + dt * 4.0)
        end
    end
    for _, c in ipairs(bj.dealerHand) do
        if c.anim and c.anim < 1 then
            c.anim = math.min(1, c.anim + dt * 4.0)
        end
    end

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

    local p1 = table.remove(bj.deck)
    local p2 = table.remove(bj.deck)
    while (p1.val + p2.val) >= 21 do
        table.insert(bj.deck, math.random(1, #bj.deck), p2)
        p2 = table.remove(bj.deck)
    end
    local d1 = table.remove(bj.deck)
    local d2 = table.remove(bj.deck)

    p1.anim = 0.0
    d1.anim = -0.15
    p2.anim = -0.30
    d2.anim = -0.45

    bj.playerHand = { p1, p2 }
    bj.dealerHand = { d1, d2 }

    -- Дилер заранее имеет все карты на столе (добирает сразу, в закрытую)
    while bj.calculateScore(bj.dealerHand) < 17 do
        local c = table.remove(bj.deck)
        c.anim = -0.15 * #bj.dealerHand
        table.insert(bj.dealerHand, c)
    end
    if bj.calculateScore(bj.dealerHand) == 21 and math.random() < 0.30 then
        local c = table.remove(bj.deck)
        c.anim = -0.15 * #bj.dealerHand
        table.insert(bj.dealerHand, c)
    end

    bj.statusKey = ""
    bj.statusWin = 0
end

function bj.hit()
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
        bj.autoRestartTimer = 2.0
        bankruptModal.check()
    end
end

function bj.stand()
    if #bj.playerHand == 0 then
        bj.deal()
        return
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
    audio.play("click")

    local pScore = bj.calculateScore(bj.playerHand)
    local dScore = bj.calculateScore(bj.dealerHand)
    local playerBJ = (#bj.playerHand == 2 and pScore == 21)
    local dealerBJ = (#bj.dealerHand == 2 and dScore == 21)

    if playerBJ and not dealerBJ then
        bj.statusKey = "blackjack"
        local win = math.floor(bj.bet * 2.5)
        bj.statusWin = win
        economy.add(win)
        audio.play("jackpot")
    elseif dealerBJ and not playerBJ then
        bj.statusKey = "dealer_bj"
        audio.play("fail")
    elseif pScore > 21 then
        bj.statusKey = "bust"
        audio.play("fail")
    elseif dScore > 21 or pScore > dScore then
        bj.statusKey = "player_wins"
        local win = bj.bet * 2
        bj.statusWin = win
        economy.add(win)
        audio.play("win")
    elseif pScore == dScore then
        bj.statusKey = "push"
        economy.add(bj.bet)
        audio.play("click")
    else
        bj.statusKey = "dealer_wins"
        audio.play("fail")
    end

    bj.autoRestartTimer = 2.0
    bankruptModal.check()
end

function bj.double()
    if #bj.playerHand == 0 then
        bj.deal()
        return
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

function bj.draw()
    local cw = 136
    local ch = 196
    local gap = 16

    local numDealer = math.max(2, #bj.dealerHand)
    local dTotalW = numDealer * cw + (numDealer - 1) * gap
    local dStartX = math.floor((1024 - dTotalW) / 2)

    local numPlayer = math.max(2, #bj.playerHand)
    local pTotalW = numPlayer * cw + (numPlayer - 1) * gap
    local pStartX = math.floor((1024 - pTotalW) / 2)

    local dealerCardsY = 120
    local playerCardsY = 404

    -- 1. Подпись и карты дилера
    love.graphics.setFont(fonts.sm)
    love.graphics.setColor(1, 0.88, 0.4)
    local dScore = "--"
    if #bj.dealerHand > 0 then
        dScore = bj.gameOver and tostring(bj.calculateScore(bj.dealerHand)) or (bj.dealerHand[1] and tostring(bj.dealerHand[1].val) or "??")
    end
    local dStr = string.format("%s: %s", i18n.t("dealer_gus"), dScore)
    local dtw = fonts.sm:getWidth(dStr)
    love.graphics.print(dStr, math.floor(512 - dtw / 2), 96)

    for i, c in ipairs(bj.dealerHand) do
        local anim = c.anim or 1
        if anim >= 0 then
            local p = math.min(1, anim)
            local ease = 1 - math.pow(1 - p, 3)
            local yOff = (1 - ease) * -75
            local xOff = (1 - ease) * 35
            local x = dStartX + (i - 1) * (cw + gap) + xOff
            local isFaceDown = (i > 1 and not bj.gameOver)
            ui.drawCard(c, x, dealerCardsY + yOff, cw, ch, false, false, isFaceDown, bj.currentCardBack)
        end
    end

    -- 2. Статус раздачи
    local sTxt = bj.getStatusText()
    if bj.gameOver and #bj.playerHand > 0 and sTxt ~= "" then
        love.graphics.setFont(fonts.sm)
        local tw = fonts.sm:getWidth(sTxt)
        local pw = math.max(260, tw + 48)
        local px = math.floor(512 - pw / 2)
        ui.drawBrassPlaque(px, 332, pw, 34, 4)
        love.graphics.setColor(1, 0.88, 0.4)
        love.graphics.print(sTxt, math.floor(512 - tw / 2), 342)
    end

    -- 3. Подпись и карты игрока
    love.graphics.setFont(fonts.sm)
    love.graphics.setColor(1, 0.88, 0.4)
    local pScore = #bj.playerHand > 0 and tostring(bj.calculateScore(bj.playerHand)) or "--"
    local pStr = string.format("%s: %s", i18n.t("player"), pScore)
    local ptw = fonts.sm:getWidth(pStr)
    love.graphics.print(pStr, math.floor(512 - ptw / 2), 380)

    for i, c in ipairs(bj.playerHand) do
        local anim = c.anim or 1
        if anim >= 0 then
            local p = math.min(1, anim)
            local ease = 1 - math.pow(1 - p, 3)
            local yOff = (1 - ease) * -75
            local xOff = (1 - ease) * 35
            local x = pStartX + (i - 1) * (cw + gap) + xOff
            ui.drawCard(c, x, playerCardsY + yOff, cw, ch, false, false, false)
        end
    end

    -- 4. Нижняя панель действий (точно вровень с остальными залами)
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
    love.graphics.print(economy.format(bj.bet), betX + 44, betY + 25)

    -- Кнопки действий: HIT, STAND, DOUBLE, SWITCH
    local hitLabel = i18n.t("hit")
    local standLabel = i18n.t("stand")
    local doubleLabel = i18n.t("double")
    local switchLabel = i18n.t("switch")

    local btnY = 686
    local btnH = 48

    -- HIT
    local hitX = 360
    local hitW = 136
    ui.drawSaloonButton(hitX, btnY, hitW, btnH, "")
    local hitBadge = (bj.controlMode == 0) and "up" or "X"
    local hitBadgeCol = (bj.controlMode == 0) and "green" or "blue"
    love.graphics.setFont(fonts.lg)
    local htw = fonts.lg:getWidth(hitLabel)
    local hth = fonts.lg:getHeight()
    local totalHitW = 22 + 10 + htw
    local hitStartX = hitX + math.floor((hitW - totalHitW) / 2)
    ui.drawButtonBadge(hitStartX + 11, btnY + btnH / 2, 11, hitBadge, 1.0, hitBadgeCol)
    love.graphics.setColor(255/255, 248/255, 235/255)
    love.graphics.print(hitLabel, hitStartX + 32, math.floor(btnY + (btnH - hth) / 2))

    -- STAND
    local standX = 510
    local standW = 146
    ui.drawSaloonButtonRed(standX, btnY, standW, btnH)
    local standBadge = (bj.controlMode == 0) and "down" or "B"
    love.graphics.setFont(fonts.lg)
    local stw = fonts.lg:getWidth(standLabel)
    local sth = fonts.lg:getHeight()
    local totalStandW = 22 + 10 + stw
    local standStartX = standX + math.floor((standW - totalStandW) / 2)
    ui.drawButtonBadge(standStartX + 11, btnY + btnH / 2, 11, standBadge, 1.0, "red")
    love.graphics.setColor(255/255, 248/255, 235/255)
    love.graphics.print(standLabel, standStartX + 32, math.floor(btnY + (btnH - sth) / 2))

    -- DOUBLE
    local dblX = 670
    local dblW = 150
    ui.drawSaloonButton(dblX, btnY, dblW, btnH, "")
    local dblBadge = (bj.controlMode == 0) and "left" or "A"
    local dblBadgeCol = (bj.controlMode == 0) and "yellow" or "green"
    love.graphics.setFont(fonts.lg)
    local dtw = fonts.lg:getWidth(doubleLabel)
    local dth = fonts.lg:getHeight()
    local totalDblW = 22 + 10 + dtw
    local dblStartX = dblX + math.floor((dblW - totalDblW) / 2)
    ui.drawButtonBadge(dblStartX + 11, btnY + btnH / 2, 11, dblBadge, 1.0, dblBadgeCol)
    love.graphics.setFont(fonts.lg)
    love.graphics.setColor(255/255, 248/255, 235/255)
    love.graphics.print(doubleLabel, dblStartX + 32, math.floor(btnY + (btnH - dth) / 2))

    -- SWITCH (R2)
    local swX = 834
    local swW = 142
    ui.drawSaloonButton(swX, btnY, swW, btnH, "")
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

function bj.resetTable()
    bj.playerHand = {}
    bj.dealerHand = {}
    bj.gameOver = true
    bj.hasHit = false
    bj.betDeducted = false
    bj.autoRestartTimer = 0
    bj.statusKey = ""
    bj.statusWin = 0
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
    -- Окно ставки [Y]
    if x >= 44 and x <= 235 and y >= 680 and y <= 740 then
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
    -- HIT: 360, 686, 136, 48
    if x >= 360 and x <= 496 and y >= 680 and y <= 740 then
        bj.hit()
        return true
    -- STAND: 510, 686, 146, 48
    elseif x >= 510 and x <= 656 and y >= 680 and y <= 740 then
        bj.stand()
        return true
    -- DOUBLE: 670, 686, 150, 48
    elseif x >= 670 and x <= 820 and y >= 680 and y <= 740 then
        bj.double()
        return true
    -- SWITCH (R2): 834, 686, 142, 48
    elseif x >= 834 and x <= 976 and y >= 680 and y <= 740 then
        bj.toggleControlMode()
        return true
    end

    return false
end

return bj