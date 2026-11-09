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

function bj.deal()
    if not economy.spend(bj.bet) then
        audio.play("fail")
        return
    end

    if #bj.deck < 52 then bj.createDeck() end

    audio.play("click")
    bj.gameOver = false
    bj.playerHand = { table.remove(bj.deck), table.remove(bj.deck) }
    bj.dealerHand = { table.remove(bj.deck), table.remove(bj.deck) }

    bj.statusText = "[A] HIT  •  [B] STAND  •  [Y] DOUBLE"

    if bj.calculateScore(bj.playerHand) == 21 then
        bj.stand()
    end
end

function bj.hit()
    if bj.gameOver then return end
    audio.play("click")
    table.insert(bj.playerHand, table.remove(bj.deck))

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
    while bj.calculateScore(bj.dealerHand) < 17 do
        table.insert(bj.dealerHand, table.remove(bj.deck))
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
    local dScore = bj.gameOver and bj.calculateScore(bj.dealerHand) or (bj.dealerHand[1] and bj.dealerHand[1].val or "??")
    love.graphics.print(string.format("%s: %s", i18n.t("dealer_gus"), tostring(dScore)), 60, 140)

    for i, c in ipairs(bj.dealerHand) do
        drawCard(c, 60 + (i - 1) * 110, 165, (i == 2 and not bj.gameOver))
    end

    -- Статус раздачи
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 40, 315, 944, 44, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(bj.statusText, 320, 328)

    -- Карты игрока
    love.graphics.setColor(1, 0.88, 0.4)
    local pScore = bj.calculateScore(bj.playerHand)
    love.graphics.print(string.format("%s: %d", i18n.t("player"), pScore), 60, 380)

    for i, c in ipairs(bj.playerHand) do
        drawCard(c, 60 + (i - 1) * 110, 405, false)
    end

    -- Нижняя панель действий
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 40, 560, 944, 60, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(string.format("%s: %s", i18n.t("bet"), economy.format(bj.bet)), 60, 580)

    love.graphics.print("[A] HIT", 380, 580)
    love.graphics.print("[B] STAND", 540, 580)
    love.graphics.print("[Y] DOUBLE", 700, 580)
    love.graphics.print("[X] DEAL", 860, 580)
end

function bj.keypressed(key)
    if key == "up" then
        bj.bet = bj.bet + 100
        audio.play("click")
    elseif key == "down" then
        bj.bet = math.max(100, bj.bet - 100)
        audio.play("click")
    elseif key == "a" then
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
