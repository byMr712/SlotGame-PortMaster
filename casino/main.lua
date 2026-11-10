local slots = require("src.games.slots")
local bj = require("src.games.blackjack")
local roulette = require("src.games.roulette")
local poker = require("src.games.poker")

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")
local betModal = require("src.core.bet_modal")
local langModal = require("src.core.lang_modal")
local bankruptModal = require("src.core.bankrupt_modal")

local activeTab = 1 -- 1: Slots (Стартуем всегда со слотов!), 2: BJ, 3: Roulette, 4: Poker

function love.load()
    sprites.init()
    audio.init()
    slots.init()
    bj.createDeck()
    poker.initDeck()
    langModal.init()

    bankruptModal.setResetCallback(function()
        if slots.bet > 10000 then slots.bet = 10000 end
        if bj.bet > 10000 then bj.bet = 10000 end
        if roulette.chipBet > 10000 then roulette.chipBet = 10000 end
        if poker.bet > 10000 then poker.bet = 10000 end
    end)
end

function love.update(dt)
    betModal.update(dt)
    if activeTab == 1 then
        slots.update(dt)
    elseif activeTab == 2 then
        bj.update(dt)
    elseif activeTab == 3 then
        roulette.update(dt)
    elseif activeTab == 4 then
        poker.update(dt)
    end
end

function love.draw()
    -- 1. Фоновое дерево салуна и зеленое сукно
    love.graphics.setColor(0.04, 0.02, 0.01)
    love.graphics.rectangle("fill", 0, 0, 1024, 768)

    love.graphics.setColor(0.17, 0.07, 0.02)
    love.graphics.rectangle("fill", 10, 10, 1004, 748, 8)
    love.graphics.setColor(0.55, 0.26, 0.08)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 10, 10, 1004, 748, 8)
    love.graphics.setLineWidth(1)

    -- Сукно зала
    love.graphics.setColor(0.05, 0.18, 0.1)
    love.graphics.rectangle("fill", 24, 68, 976, 646, 6)
    love.graphics.setColor(0.08, 0.28, 0.15)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 24, 68, 976, 646, 6)
    love.graphics.setLineWidth(1)

    -- 2. Верхняя панель: Вкладки L1/R1 + Баланс
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 24, 18, 976, 44, 4)

    -- Вкладка залов в одну ячейку: меняется по L1 / R1, без цифр
    local roomNames = { i18n.t("tab_slots"), i18n.t("tab_bj"), i18n.t("tab_roulette"), i18n.t("tab_poker") }
    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", 30, 24, 360, 32, 4)
    love.graphics.setColor(0.55, 0.26, 0.08)
    love.graphics.rectangle("line", 30, 24, 360, 32, 4)

    -- Кнопка [L1]
    love.graphics.setColor(0.24, 0.1, 0.03)
    love.graphics.rectangle("fill", 35, 27, 50, 26, 3)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("[L1]", 46, 33)

    -- Название текущего зала со стрелками ◄   НАЗВАНИЕ   ►
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("◄", 96, 33)

    love.graphics.setColor(1, 1, 1)
    local curRoom = roomNames[activeTab]
    local font = love.graphics.getFont()
    local tw = font and font:getWidth(curRoom) or (#curRoom * 8)
    love.graphics.print(curRoom, 210 - tw / 2, 33)

    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("►", 314, 33)

    -- Кнопка [R1]
    love.graphics.setColor(0.24, 0.1, 0.03)
    love.graphics.rectangle("fill", 335, 27, 50, 26, 3)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("[R1]", 346, 33)

    -- Баланс
    love.graphics.setColor(0.22, 0.1, 0.04)
    love.graphics.rectangle("fill", 690, 24, 210, 32, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.rectangle("line", 690, 24, 210, 32, 4)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(economy.getBalanceFormatted(), 710, 32)

    -- Переключатели Валюты / Языка
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("[SEL]", 915, 32)
    love.graphics.print("[STR]", 965, 32)

    -- 3. Отрисовка активной комнаты
    if activeTab == 1 then
        slots.draw()
    elseif activeTab == 2 then
        bj.draw()
    elseif activeTab == 3 then
        roulette.draw()
    elseif activeTab == 4 then
        poker.draw()
    end

    -- 4. Модальные окна (настройка ставки, выбор языка и банкротство)
    betModal.draw()
    langModal.draw()
    bankruptModal.draw()
end

local function handleGlobalInput(action)
    if action == "prev_tab" then
        activeTab = (activeTab == 1) and 4 or (activeTab - 1)
        audio.play("click")
        if activeTab == 2 and #bj.playerHand == 0 then bj.deal() end
        if activeTab == 4 and #poker.hand == 0 then poker.drawOrDeal() end
    elseif action == "next_tab" then
        activeTab = (activeTab == 4) and 1 or (activeTab + 1)
        audio.play("click")
        if activeTab == 2 and #bj.playerHand == 0 then bj.deal() end
        if activeTab == 4 and #poker.hand == 0 then poker.drawOrDeal() end
    elseif action == "currency" then
        economy.toggleCurrency()
        audio.play("click")
    elseif action == "language" then
        i18n.toggle()
        audio.play("click")
    end
end

function love.keypressed(key)
    -- Если открыто окно банкротства, весь ввод идет в него
    if bankruptModal.active then
        bankruptModal.keypressed(key)
        return
    end

    -- Если открыто окно выбора языка, ввод идет в него
    if langModal.active then
        langModal.keypressed(key)
        return
    end

    -- Если открыто окно ставки, весь ввод идет в него
    if betModal.active then
        betModal.keypressed(key)
        return
    end

    if key == "q" or key == "[" then
        handleGlobalInput("prev_tab")
    elseif key == "e" or key == "]" then
        handleGlobalInput("next_tab")
    elseif key == "1" then activeTab = 1; audio.play("click")
    elseif key == "2" then activeTab = 2; audio.play("click"); if #bj.playerHand == 0 then bj.deal() end
    elseif key == "3" then activeTab = 3; audio.play("click")
    elseif key == "4" then activeTab = 4; audio.play("click"); if #poker.hand == 0 then poker.drawOrDeal() end
    elseif key == "c" or key == "rshift" or key == "lshift" then
        handleGlobalInput("currency")
    elseif key == "m" or key == "tab" or key == "escape" then
        handleGlobalInput("language")
    else
        -- Делегируем ввод активной игре
        if activeTab == 1 then
            slots.keypressed(key)
        elseif activeTab == 2 then
            bj.keypressed(key)
        elseif activeTab == 3 then
            roulette.keypressed(key)
        elseif activeTab == 4 then
            poker.keypressed(key)
        end
    end
end

-- SDL2 GameController для TrimUI Brick
function love.gamepadpressed(joystick, button)
    if button == "leftshoulder" then
        handleGlobalInput("prev_tab")
    elseif button == "rightshoulder" then
        handleGlobalInput("next_tab")
    elseif button == "back" then
        handleGlobalInput("currency")
    elseif button == "start" then
        handleGlobalInput("language")
    else
        -- Трансляция кнопок геймпада в keypressed
        local map = {
            dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
            a = "a", b = "b", x = "x", y = "y"
        }
        if map[button] then
            love.keypressed(map[button])
        end
    end
end

-- Обработка кликов мыши / тачскрина
function love.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- 1. Модальные окна имеют абсолютный приоритет
    if bankruptModal.active then
        bankruptModal.mousepressed(x, y)
        return
    end

    if langModal.active then
        langModal.mousepressed(x, y)
        return
    end

    if betModal.active then
        betModal.mousepressed(x, y)
        return
    end

    -- 2. Верхняя панель: Переключение залов и глобальные кнопки
    if y >= 18 and y <= 62 then
        if x >= 30 and x <= 390 then
            if x <= 210 then
                handleGlobalInput("prev_tab")
            else
                handleGlobalInput("next_tab")
            end
            return
        elseif x >= 690 and x <= 950 then
            handleGlobalInput("currency")
            return
        elseif x >= 955 and x <= 1000 then
            handleGlobalInput("language")
            return
        end
    end

    -- 3. Делегирование клика активной игре
    if activeTab == 1 and slots.mousepressed then
        slots.mousepressed(x, y)
    elseif activeTab == 2 and bj.mousepressed then
        bj.mousepressed(x, y)
    elseif activeTab == 3 and roulette.mousepressed then
        roulette.mousepressed(x, y)
    elseif activeTab == 4 and poker.mousepressed then
        poker.mousepressed(x, y)
    end
end
