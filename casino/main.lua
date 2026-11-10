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
    if love.joystick and love.joystick.loadGamepadMappings then
        pcall(function()
            if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("gamecontrollerdb.txt") then
                love.joystick.loadGamepadMappings("gamecontrollerdb.txt")
            end
        end)
    end

    sprites.init()
    audio.init()
    slots.init()
    bj.createDeck()
    poker.initDeck()
    langModal.init()

    bankruptModal.setResetCallback(function()
        slots.bet = 100
        bj.bet = 100
        roulette.chipBet = 100
        poker.bet = 100
        slots.resetAttractMode()
        bj.resetTable()
        poker.resetTable()
        roulette.resetTable()
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
    local feltY = 82
    local feltH = 632
    love.graphics.setColor(0.05, 0.18, 0.1)
    love.graphics.rectangle("fill", 24, feltY, 976, feltH, 6)
    love.graphics.setColor(0.08, 0.28, 0.15)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 24, feltY, 976, feltH, 6)
    love.graphics.setLineWidth(1)

    -- 2. Верхняя панель: Вкладки L1/R1 + Баланс (выровнены по бокам вровень с нижним баром: x=40..984, ширина 944)
    love.graphics.setColor(0.12, 0.05, 0.02)
    love.graphics.rectangle("fill", 40, 18, 944, 66, 4)

    -- Вкладка залов (широкое окно слева от центра: 464x56 на x=40, y=23)
    local roomNames = { i18n.t("tab_slots"), i18n.t("tab_bj"), i18n.t("tab_roulette"), i18n.t("tab_poker") }
    local leftX = 40
    local winY = 23
    local winW = 464
    local winH = 56

    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", leftX, winY, winW, winH, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", leftX, winY, winW, winH, 4)
    love.graphics.setLineWidth(1)

    local btnW = 74
    local btnH = 42
    local btnY = winY + (winH - btnH) / 2

    -- Кнопка L1
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.rectangle("fill", leftX + 7, btnY, btnW, btnH, 3)
    love.graphics.setColor(0.68, 0.32, 0.1)
    love.graphics.rectangle("fill", leftX + 8, btnY + 1, btnW - 2, btnH - 2, 2)
    love.graphics.setColor(0.9, 0.5, 0.2)
    love.graphics.rectangle("line", leftX + 8, btnY + 1, btnW - 2, btnH - 2, 2)

    local font = love.graphics.getFont()
    local fontH = font and font:getHeight() or 12
    love.graphics.setColor(1, 0.95, 0.7)
    local l1Str = "L1"
    local l1w = (font and font:getWidth(l1Str) or 16) * 1.65
    local l1h = fontH * 1.65
    love.graphics.print(l1Str, leftX + 7 + btnW / 2 - l1w / 2, btnY + btnH / 2 - l1h / 2, 0, 1.65, 1.65)

    -- Название текущего зала со стрелками ◄   НАЗВАНИЕ   ► (по центру между кнопками)
    local innerCenter = leftX + winW / 2
    local curRoom = roomNames[activeTab]
    local tw = (font and font:getWidth(curRoom) or (#curRoom * 8)) * 1.7
    local th = fontH * 1.7
    local roomTextY = winY + winH / 2 - th / 2

    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("◄", innerCenter - tw / 2 - 36, roomTextY, 0, 1.55, 1.55)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(curRoom, innerCenter - tw / 2, roomTextY, 0, 1.7, 1.7)

    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print("►", innerCenter + tw / 2 + 18, roomTextY, 0, 1.55, 1.55)

    -- Кнопка R1
    local r1X = leftX + winW - btnW - 7
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.rectangle("fill", r1X, btnY, btnW, btnH, 3)
    love.graphics.setColor(0.68, 0.32, 0.1)
    love.graphics.rectangle("fill", r1X + 1, btnY + 1, btnW - 2, btnH - 2, 2)
    love.graphics.setColor(0.9, 0.5, 0.2)
    love.graphics.rectangle("line", r1X + 1, btnY + 1, btnW - 2, btnH - 2, 2)

    love.graphics.setColor(1, 0.95, 0.7)
    local r1Str = "R1"
    local r1w = (font and font:getWidth(r1Str) or 16) * 1.65
    local r1h = fontH * 1.65
    love.graphics.print(r1Str, r1X + btnW / 2 - r1w / 2, btnY + btnH / 2 - r1h / 2, 0, 1.65, 1.65)

    -- Окно баланса (широкое окно справа, край вровень с нижним баром: x=520, w=464, правый край=984)
    local balX = 520
    local balY = winY
    local balW = 464
    local balH = winH

    love.graphics.setColor(0.18, 0.08, 0.03)
    love.graphics.rectangle("fill", balX, balY, balW, balH, 4)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", balX, balY, balW, balH, 4)
    love.graphics.setLineWidth(1)

    -- Монетка и сумма баланса крупно по центру окна
    local balStr = economy.getBalanceFormatted()
    local btw = (font and font:getWidth(balStr) or (#balStr * 8)) * 1.8
    local bth = fontH * 1.8
    local coinSize = 36
    local totalContentW = coinSize + 16 + btw
    local contentStartX = balX + (balW - totalContentW) / 2

    sprites.draw("coin", contentStartX + coinSize / 2, balY + balH / 2, coinSize)
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.print(balStr, contentStartX + coinSize + 16, balY + balH / 2 - bth / 2, 0, 1.8, 1.8)

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
        if activeTab == 4 and #poker.hand == 0 then poker.deal() end
    elseif action == "next_tab" then
        activeTab = (activeTab == 4) and 1 or (activeTab + 1)
        audio.play("click")
        if activeTab == 2 and #bj.playerHand == 0 then bj.deal() end
        if activeTab == 4 and #poker.hand == 0 then poker.deal() end
    elseif action == "currency" then
        economy.toggleCurrency()
        audio.play("click")
    elseif action == "language" then
        langModal.open()
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
    elseif key == "4" then activeTab = 4; audio.play("click"); if #poker.hand == 0 then poker.deal() end
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

-- Поддержка геймпадов: SDL2 GameController + DirectInput fallback + Аналоговые стики
local stickDeadzone = 0.5
local lastStickX = 0
local lastStickY = 0

function love.gamepadpressed(joystick, button)
    if betModal.active then
        if button == "leftshoulder" then
            betModal.keypressed("l1")
            return
        elseif button == "rightshoulder" then
            betModal.keypressed("r1")
            return
        elseif button == "lefttrigger" then
            betModal.keypressed("l2")
            return
        elseif button == "righttrigger" then
            betModal.keypressed("r2")
            return
        end
    end

    if button == "leftshoulder" then
        handleGlobalInput("prev_tab")
    elseif button == "rightshoulder" then
        handleGlobalInput("next_tab")
    elseif button == "back" then
        handleGlobalInput("currency")
    elseif button == "start" then
        handleGlobalInput("language")
    elseif button == "righttrigger" then
        love.keypressed("r2")
    elseif button == "lefttrigger" then
        love.keypressed("l2")
    else
        local map = {
            dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
            a = "a", b = "b", x = "x", y = "y"
        }
        if map[button] then
            love.keypressed(map[button])
        end
    end
end

-- Навигация левым аналоговым стиком как D-pad
function love.gamepadaxis(joystick, axis, value)
    if axis == "leftx" then
        if value < -stickDeadzone and lastStickX >= -stickDeadzone then
            love.keypressed("left")
        elseif value > stickDeadzone and lastStickX <= stickDeadzone then
            love.keypressed("right")
        end
        lastStickX = value
    elseif axis == "lefty" then
        if value < -stickDeadzone and lastStickY >= -stickDeadzone then
            love.keypressed("up")
        elseif value > stickDeadzone and lastStickY <= stickDeadzone then
            love.keypressed("down")
        end
        lastStickY = value
    end
end

-- Fallback для неопознанных generic USB / DirectInput геймпадов
function love.joystickpressed(joystick, button)
    if joystick:isGamepad() then return end

    if betModal.active then
        if button == 5 then betModal.keypressed("l1"); return
        elseif button == 6 then betModal.keypressed("r1"); return
        elseif button == 7 then betModal.keypressed("l2"); return
        elseif button == 8 then betModal.keypressed("r2"); return
        end
    end

    if button == 5 or button == 7 then
        handleGlobalInput("prev_tab")
    elseif button == 6 then
        handleGlobalInput("next_tab")
    elseif button == 8 then
        love.keypressed("r2")
    elseif button == 9 then
        handleGlobalInput("currency")
    elseif button == 10 then
        handleGlobalInput("language")
    else
        local map = {
            [1] = "a", [2] = "b", [3] = "x", [4] = "y",
            [11] = "left", [12] = "right", [13] = "up", [14] = "down"
        }
        if map[button] then love.keypressed(map[button]) end
    end
end

function love.joystickhat(joystick, hat, direction)
    if joystick:isGamepad() then return end
    if direction == "u" or direction == "ru" or direction == "lu" then
        love.keypressed("up")
    elseif direction == "d" or direction == "rd" or direction == "ld" then
        love.keypressed("down")
    elseif direction == "l" then
        love.keypressed("left")
    elseif direction == "r" then
        love.keypressed("right")
    end
end

function love.joystickadded(joystick)
    audio.play("click")
end

function love.joystickremoved(joystick)
    audio.play("click")
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

    -- 2. Верхняя панель: Переключение залов и баланс
    if y >= 18 and y <= 80 then
        if x >= 34 and x <= 499 then
            if x <= 267 then
                handleGlobalInput("prev_tab")
            else
                handleGlobalInput("next_tab")
            end
            return
        elseif x >= 525 and x <= 990 then
            handleGlobalInput("currency")
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
