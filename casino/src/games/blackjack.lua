local bj = {}

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")

bj.bet = 1000
bj.deck = {}
bj.playerHand = {}
bj.dealerHand = {}
bj.gameOver = true
bj.statusText = "PRESS [X] TO DEAL"
bj.dealAnim = 1

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

    local p1 = table.remove(bj.deck); p1.anim = 0.0
    local d1 = table.remove(bj.deck); d1.anim = -0.15
    local p2 = table.remove(bj.deck); p2.anim = -0.30
    local d2 = table.remove(bj.deck); d2.anim = -0.45

    bj.playerHand = { p1, p2 }
    bj.dealerHand = { d1, d2 }

    bj.statusText = "[A] HIT  •  [B] STAND  •  [Y] DOUBLE"

    if bj.calculateScore(bj.playerHand) == 21 then
        bj.stand()
    end
end

function bj.hit()
    if bj.gameOver then return end
    audio.play("click")
    local c = table.remove(bj.deck)
    c.anim = 0.0
    table.insert(bj.playerHand, c)

    local score = bj.calculateScore(bj.playerHand)
    if score > 21 then
        bj.gameOver = true
        bj.statusText = i18n.t("bust")
        audio.play("fail")
    elseif score == 21 then
        bj.stand()
    end
end

function bj.stand()
    if bj.gameOver then return end
    bj.gameOver = true

    local pScore = bj.calculateScore(bj.playerHand)
    local dScore = bj.calculateScore(bj.dealerHand)
    local playerBJ = (pScore == 21 and #bj.playerHand == 2)
    local dealerBJ = (dScore == 21 and #bj.dealerHand == 2)

    -- Натуральный блэкджек (3:2)
    if playerBJ then
        if dealerBJ then
            economy.add(bj.bet)
            bj.statusText = i18n.t("push")
            audio.play("click")
        else
            local win = bj.bet * 2.5
            economy.add(win)
            bj.statusText = string.format("★ BLACKJACK! +%s ★", economy.format(win))
            audio.play("win")
        end
        return
    end

    if dealerBJ then
        bj.statusText = "DEALER BLACKJACK"
        audio.play("fail")
        return
    end

    -- Дилер добирает строго до 17 (Dealer stands on all 17s)
    local dIdx = 0
    while bj.calculateScore(bj.dealerHand) < 17 do
        dIdx = dIdx + 1
        local extraCard = table.remove(bj.deck)
        extraCard.anim = -(dIdx * 0.18)
        table.insert(bj.dealerHand, extraCard)
    end

    local p = bj.calculateScore(bj.playerHand)
    local d = bj.calculateScore(bj.dealerHand)

    if d > 21 or p > d then
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
    love.graphics.rectangle("fill", x, y, 92, 130, 6)
    love.graphics.setColor(0.55, 0.26, 0.08, 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, 92, 130, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.7, 0.5, 0.2, 0.35)
    love.graphics.print(label, x + 24, y + 56)
end

local function drawCard(c, x, y, hidden)
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", x, y, 92, 130, 6)
    
    if hidden then
        love.graphics.setColor(0.35, 0.15, 0.05)
        love.graphics.rectangle("fill", x + 3, y + 3, 86, 124, 4)
        sprites.draw("stardrop", x + 46, y + 65, 36)
        return
    end

    love.graphics.setColor(0.98, 0.93, 0.82)
    love.graphics.rectangle("fill", x + 3, y + 3, 86, 124, 4)

    local isRed = (c.suit == "heart" or c.suit == "diamond")
    if isRed then
        love.graphics.setColor(0.75, 0.15, 0.1)
    else
        love.graphics.setColor(0.1, 0.05, 0.02)
    end

    love.graphics.print(c.name, x + 8, y + 8)
    love.graphics.print(c.name, x + 70, y + 104)
    sprites.draw(c.suit, x + 46, y + 65, 28)
end

function bj.draw()
    -- Инфо-панель сверху
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 80, 944, 40, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(string.format("6-DECK SHOE (312) • BLACKJACK 3:2 • DEALER STANDS ON 17"), 60, 92)

    -- Карты дилера
    love.graphics.setColor(1, 0.88, 0.4)
    local dScore = "--"
    if #bj.dealerHand > 0 then
        dScore = bj.gameOver and tostring(bj.calculateScore(bj.dealerHand)) or (bj.dealerHand[1] and tostring(bj.dealerHand[1].val) or "??")
    end
    love.graphics.print(string.format("%s: %s", i18n.t("dealer_gus"), dScore), 60, 140)

    if #bj.dealerHand == 0 then
        drawEmptyCardSlot(60, 165, "CARD 1")
        drawEmptyCardSlot(170, 165, "CARD 2")
    else
        for i, c in ipairs(bj.dealerHand) do
            local anim = c.anim or 1
            if anim >= 0 then
                local p = math.min(1, anim)
                local ease = 1 - math.pow(1 - p, 3)
                local yOff = (1 - ease) * -65
                local xOff = (1 - ease) * 35
                drawCard(c, 60 + (i - 1) * 110 + xOff, 165 + yOff, (i == 2 and not bj.gameOver))
            end
        end
    end

    -- Статус раздачи
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 315, 944, 44, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(bj.statusText, 320, 328)

    -- Карты игрока
    love.graphics.setColor(1, 0.88, 0.4)
    local pScore = #bj.playerHand > 0 and tostring(bj.calculateScore(bj.playerHand)) or "--"
    love.graphics.print(string.format("%s: %s", i18n.t("player"), pScore), 60, 380)

    if #bj.playerHand == 0 then
        drawEmptyCardSlot(60, 405, "CARD 1")
        drawEmptyCardSlot(170, 405, "CARD 2")
    else
        for i, c in ipairs(bj.playerHand) do
            local anim = c.anim or 1
            if anim >= 0 then
                local p = math.min(1, anim)
                local ease = 1 - math.pow(1 - p, 3)
                local yOff = (1 - ease) * -65
                local xOff = (1 - ease) * 35
                drawCard(c, 60 + (i - 1) * 110 + xOff, 405 + yOff, false)
            end
        end
    end

    -- Нижняя панель действий
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
    love.graphics.print(economy.format(bj.bet), 65, 590)

    if not bj.gameOver then
        love.graphics.setColor(0.6, 0.5, 0.4)
        love.graphics.print("(LOCKED)", 180, 590)
    end

    local function drawGameBtn(bx, by, bw, bh, bCol, keyCol, keyChar, label)
        -- Темная тень
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.rectangle("fill", bx, by, bw, bh, 4)
        -- Корпус
        love.graphics.setColor(bCol[1], bCol[2], bCol[3])
        love.graphics.rectangle("fill", bx + 2, by + 2, bw - 4, bh - 4, 3)
        -- Фаска сверху
        love.graphics.setColor(bCol[1] * 1.35, bCol[2] * 1.35, bCol[3] * 1.35)
        love.graphics.rectangle("line", bx + 2, by + 2, bw - 4, bh - 4, 3)

        -- Круглая кнопка геймпада
        local cx = bx + 18
        local cy = by + bh / 2
        love.graphics.setColor(keyCol[1], keyCol[2], keyCol[3])
        love.graphics.circle("fill", cx, cy, 11)
        love.graphics.setColor(0.08, 0.03, 0.01)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, 11)
        love.graphics.setLineWidth(1)
        love.graphics.print(keyChar, cx - 4, cy - 7)

        -- Текст действия
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label, bx + 36, cy - 7)
    end

    drawGameBtn(365, 570, 135, 40, {0.68, 0.32, 0.1}, {0.2, 0.78, 0.35}, "A", "HIT")
    drawGameBtn(515, 570, 140, 40, {0.75, 0.16, 0.1}, {0.95, 0.32, 0.3}, "B", "STAND")
    drawGameBtn(670, 570, 145, 40, {0.68, 0.32, 0.1}, {0.96, 0.78, 0.2}, "Y", "DOUBLE")
    drawGameBtn(830, 570, 135, 40, {0.68, 0.32, 0.1}, {0.32, 0.62, 0.96}, "X", "DEAL")
end

function bj.keypressed(key)
    if bj.gameOver then
        if key == "up" then
            bj.bet = bj.bet + 100
            audio.play("click")
        elseif key == "down" then
            bj.bet = math.max(100, bj.bet - 100)
            audio.play("click")
        elseif key == "right" then
            bj.bet = bj.bet + 1000
            audio.play("click")
        elseif key == "left" then
            bj.bet = math.max(100, bj.bet - 1000)
            audio.play("click")
        end
    end

    if key == "a" then
        bj.hit()
    elseif key == "b" then
        bj.stand()
    elseif key == "y" then
        bj.double()
    elseif key == "x" or key == "space" or key == "return" then
        if bj.gameOver then bj.deal() end
    end
end

return bj
