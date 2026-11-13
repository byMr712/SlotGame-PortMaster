local slots = require("src.games.slots")
local bj = require("src.games.blackjack")
local roulette = require("src.games.roulette")
local poker = require("src.games.poker")

local economy = require("src.core.economy")
local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local sprites = require("src.core.sprites")
local fonts = require("src.core.fonts")
local ui = require("src.core.ui")
local viewport = require("src.core.viewport")
local betModal = require("src.core.bet_modal")
local langModal = require("src.core.lang_modal")
local bankruptModal = require("src.core.bankrupt_modal")

local activeTab = 1 -- 1: Slots (Стартуем всегда со слотов!), 2: BJ, 3: Roulette, 4: Poker

function love.load()
    viewport.init()
    if love.joystick and love.joystick.loadGamepadMappings then
        pcall(function()
            if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("gamecontrollerdb.txt") then
                love.joystick.loadGamepadMappings("gamecontrollerdb.txt")
            end
        end)
    end

    fonts.init()
    ui.init()
    sprites.init()
    audio.init()
    slots.init()
    bj.createDeck()
    bj.deal()
    poker.initDeck()
    poker.deal()
    langModal.init()

    bankruptModal.setResetCallback(function()
        slots.bet = 500
        bj.bet = 500
        roulette.selectedChip = 500
        roulette.chipBet = 500
        poker.bet = 500
        slots.resetAttractMode()
        bj.resetTable()
        poker.resetTable()
        roulette.resetTable()
        if activeTab == 2 then
            bj.deal()
        elseif activeTab == 4 then
            poker.deal()
        end
    end)
end

function love.update(dt)
    betModal.update(dt)
    bankruptModal.update(dt)
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
    viewport.startRender()

    -- 1. Фоновое дерево салуна и фактурное зеленое сукно
    ui.drawCabinet()
    ui.drawFelt(22, 78, 980, 676)

    -- 2. Верхняя панель: Вкладки L1/R1 + Баланс (выровнены по бокам: x=22..1002)
    local roomNames = { i18n.t("tab_slots"), i18n.t("tab_bj"), i18n.t("tab_roulette"), i18n.t("tab_poker") }
    local winY = 10
    local winH = 60
    local boxW = 478

    -- Вкладка залов (широкое окно слева)
    local leftX = 22
    ui.drawBrassPlaque(leftX, winY, boxW, winH, 4)

    local btnW = 68
    local btnH = 44
    local btnY = winY + (winH - btnH) / 2

    -- Кнопка L1
    ui.drawSaloonButton(leftX + 8, btnY, btnW, btnH, "L1", fonts.md)

    -- Название текущего зала со стрелками (по центру между кнопками)
    local innerCenter = leftX + boxW / 2
    local curRoom = roomNames[activeTab]
    local curFont = fonts.lg
    love.graphics.setFont(curFont)
    local tw = curFont:getWidth(curRoom)
    local th = curFont:getHeight()
    local roomTextY = math.floor(winY + (winH - th) / 2)

    -- Левая золотая стрелка
    ui.drawArrow(innerCenter - tw / 2 - 16, winY + winH / 2, 12, "left", {1, 0.88, 0.4, 0.95})

    -- Название зала с темной тенью #180802
    love.graphics.setColor(24/255, 8/255, 2/255, 1)
    love.graphics.print(curRoom, math.floor(innerCenter - tw / 2) + 2, roomTextY + 2)
    love.graphics.setColor(1, 0.88, 0.4, 1)
    love.graphics.print(curRoom, math.floor(innerCenter - tw / 2), roomTextY)

    -- Правая золотая стрелка
    ui.drawArrow(innerCenter + tw / 2 + 16, winY + winH / 2, 12, "right", {1, 0.88, 0.4, 0.95})

    -- Кнопка R1
    local r1X = leftX + boxW - btnW - 8
    ui.drawSaloonButton(r1X, btnY, btnW, btnH, "R1", fonts.md)

    -- Окно баланса (широкое окно справа)
    local balX = 524
    ui.drawBrassPlaque(balX, winY, boxW, winH, 4)

    -- Монетка и сумма баланса крупно по центру окна
    local balFont = fonts.xl
    love.graphics.setFont(balFont)
    local balStr = economy.getBalanceFormatted()
    local btw = balFont:getWidth(balStr)
    local bth = balFont:getHeight()
    local coinSize = 36
    local totalContentW = coinSize + 16 + btw
    local contentStartX = balX + (boxW - totalContentW) / 2

    sprites.draw("coin", contentStartX + coinSize / 2, winY + winH / 2, coinSize)
    -- Тень текста баланса
    love.graphics.setColor(24/255, 8/255, 2/255, 1)
    love.graphics.print(balStr, math.floor(contentStartX + coinSize + 16) + 2, math.floor(winY + (winH - bth) / 2) + 2)
    love.graphics.setColor(1, 0.88, 0.4, 1)
    love.graphics.print(balStr, math.floor(contentStartX + coinSize + 16), math.floor(winY + (winH - bth) / 2))

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

    viewport.endRender()
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
local lastTriggerL = 0
local lastTriggerR = 0

function love.gamepadpressed(joystick, button)
    if betModal.active then
        if button == "leftshoulder" then
            betModal.keypressed("l1")
            return
        elseif button == "rightshoulder" then
            betModal.keypressed("r1")
            return
        elseif button == "lefttrigger" or button == "paddle2" or button == "misc1" then
            betModal.keypressed("l2")
            return
        elseif button == "righttrigger" or button == "paddle1" then
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
    elseif button == "righttrigger" or button == "paddle1" then
        love.keypressed("r2")
    elseif button == "lefttrigger" or button == "paddle2" then
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

-- Навигация левым аналоговым стиком как D-pad и аналоговые триггеры L2/R2
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
    elseif axis == "triggerleft" then
        if value > 0.25 and lastTriggerL <= 0.25 then
            if betModal.active then
                betModal.keypressed("l2")
            else
                love.keypressed("l2")
            end
        end
        if value < 0.15 then
            lastTriggerL = 0
        else
            lastTriggerL = value
        end
    elseif axis == "triggerright" then
        if value > 0.25 and lastTriggerR <= 0.25 then
            if betModal.active then
                betModal.keypressed("r2")
            else
                love.keypressed("r2")
            end
        end
        if value < 0.15 then
            lastTriggerR = 0
        else
            lastTriggerR = value
        end
    end
end

-- Fallback для неопознанных generic USB / DirectInput геймпадов и цифровых L2/R2
function love.joystickpressed(joystick, button)
    -- В окне ставки проверяем кнопки 5, 6, 7, 8 даже если isGamepad() = true (для кнопочных L2/R2 microswitches)
    if betModal.active then
        if button == 5 or button == 9 then betModal.keypressed("l1"); return
        elseif button == 6 or button == 10 then betModal.keypressed("r1"); return
        elseif button == 7 then betModal.keypressed("l2"); return
        elseif button == 8 then betModal.keypressed("r2"); return
        end
    end

    if joystick:isGamepad() then return end

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

function love.resize(w, h)
    viewport.updateDimensions(w, h)
end

-- Обработка кликов мыши / тачскрина
function love.mousepressed(screenX, screenY, button)
    if button ~= 1 then return end
    local x, y = viewport.toVirtual(screenX, screenY)

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
    if y >= 10 and y <= 74 then
        if x >= 22 and x <= 506 then
            if x <= 265 then
                handleGlobalInput("prev_tab")
            else
                handleGlobalInput("next_tab")
            end
            return
        elseif x >= 518 and x <= 1002 then
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

-- Обработка аппаратного сенсорного экрана (TrimUI / PortMaster / touch screens)
function love.touchpressed(id, x, y, dx, dy, pressure)
    local screenW, screenH = love.graphics.getDimensions()
    love.mousepressed(x * screenW, y * screenH, 1)
end
