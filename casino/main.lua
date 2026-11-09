local slots = require("src.games.slots")
local bj = require("src.games.blackjack")
local roulette = require("src.games.roulette")
local poker = require("src.games.poker")

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")

local activeTab = 1 -- 1: Slots (Стартуем всегда со слотов!), 2: BJ, 3: Roulette, 4: Poker

function love.load()
    audio.init()
    slots.init()
    bj.createDeck()
    poker.initDeck()
end

function love.update(dt)
    if activeTab == 1 then
        slots.update(dt)
    elseif activeTab == 3 then
        roulette.update(dt)
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

    -- Вкладки
    local tabsList = { "[1] SLOTS", "[2] BLACKJACK", "[3] ROULETTE", "[4] POKER" }
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("[L1] ◄", 36, 32)
    for i, tName in ipairs(tabsList) do
        local tx = 110 + (i - 1) * 125
        if i == activeTab then
            love.graphics.setColor(0.77, 0.39, 0.11)
            love.graphics.rectangle("fill", tx - 4, 24, 118, 30, 3)
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.85, 0.75, 0.55)
        end
        love.graphics.print(tName, tx, 32)
    end
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("► [R1]", 616, 32)

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

    -- 4. Нижняя строка подсказок
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 24, 718, 976, 28, 4)
    love.graphics.setColor(0.9, 0.8, 0.55)
    love.graphics.print("[L1/R1] ROOMS  •  [D-PAD] NAVIGATE  •  [A] ACTION  •  [X] SPIN/DEAL", 36, 725)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("TRIMUI BRICK (1024x768) • 60 FPS", 730, 725)
end

local function handleGlobalInput(action)
    if action == "prev_tab" then
        activeTab = (activeTab == 1) and 4 or (activeTab - 1)
        audio.play("click")
    elseif action == "next_tab" then
        activeTab = (activeTab == 4) and 1 or (activeTab + 1)
        audio.play("click")
    elseif action == "currency" then
        economy.toggleCurrency()
        audio.play("click")
    elseif action == "language" then
        i18n.toggle()
        audio.play("click")
    end
end

function love.keypressed(key)
    if key == "q" or key == "[" then
        handleGlobalInput("prev_tab")
    elseif key == "e" or key == "]" then
        handleGlobalInput("next_tab")
    elseif key == "1" then activeTab = 1; audio.play("click")
    elseif key == "2" then activeTab = 2; audio.play("click")
    elseif key == "3" then activeTab = 3; audio.play("click")
    elseif key == "4" then activeTab = 4; audio.play("click")
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
