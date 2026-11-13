local bankruptModal = {}

local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local economy = require("src.core.economy")

bankruptModal.active = false
bankruptModal.pendingTimer = nil
bankruptModal.lockTimer = 0
local onResetCallback = nil

function bankruptModal.setResetCallback(cb)
    onResetCallback = cb
end

function bankruptModal.open()
    bankruptModal.active = true
    bankruptModal.pendingTimer = nil
    bankruptModal.lockTimer = 1.5
    audio.play("fail")
end

function bankruptModal.check()
    if economy.getBalance() <= 0 then
        if not bankruptModal.active and not bankruptModal.pendingTimer then
            bankruptModal.pendingTimer = 2.0
        end
        return true
    else
        bankruptModal.pendingTimer = nil
        return false
    end
end

function bankruptModal.update(dt)
    if bankruptModal.active then
        if bankruptModal.lockTimer > 0 then
            bankruptModal.lockTimer = math.max(0, bankruptModal.lockTimer - dt)
        end
    else
        if economy.getBalance() <= 0 then
            if not bankruptModal.pendingTimer then
                bankruptModal.pendingTimer = 2.0
            else
                bankruptModal.pendingTimer = bankruptModal.pendingTimer - dt
                if bankruptModal.pendingTimer <= 0 then
                    bankruptModal.pendingTimer = nil
                    bankruptModal.open()
                end
            end
        else
            bankruptModal.pendingTimer = nil
        end
    end
end

function bankruptModal.confirm()
    economy.balance = 10000
    bankruptModal.active = false
    bankruptModal.pendingTimer = nil
    bankruptModal.lockTimer = 0
    if onResetCallback then
        onResetCallback()
    end
    audio.play("win")
end

function bankruptModal.keypressed(key)
    if not bankruptModal.active then return false end
    if bankruptModal.lockTimer > 0 then return true end
    if key == "x" or key == "return" or key == "space" then
        bankruptModal.confirm()
        return true
    end
    return true
end

function bankruptModal.mousepressed(x, y)
    if not bankruptModal.active then return false end
    if bankruptModal.lockTimer > 0 then return true end
    local mx = 272
    local my = 200
    local mw = 480
    local mh = 330
    local bx = mx + (mw - 220) / 2
    local by = my + 240
    local bw = 220
    local bh = 54
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        bankruptModal.confirm()
        return true
    end
    return true
end

local fonts = require("src.core.fonts")
local ui = require("src.core.ui")

function bankruptModal.draw()
    if not bankruptModal.active then return end

    -- Затемнение
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, 1024, 768)

    local mx = 272
    local my = 200
    local mw = 480
    local mh = 330

    -- Внешняя темная тень
    love.graphics.setColor(0.04, 0.02, 0.01, 0.95)
    love.graphics.rectangle("fill", mx + 8, my + 8, mw, mh, 8)

    -- Корпус модального окна (салунное дерево)
    love.graphics.setColor(0.14, 0.06, 0.02)
    love.graphics.rectangle("fill", mx, my, mw, mh, 8)
    love.graphics.setColor(0.24, 0.1, 0.03)
    love.graphics.rectangle("fill", mx + 4, my + 4, mw - 8, mh - 8, 6)

    -- Латунная рамка
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", mx, my, mw, mh, 8)
    love.graphics.setLineWidth(1)

    -- Заклепки по углам
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.circle("fill", mx + 16, my + 16, 4)
    love.graphics.circle("fill", mx + mw - 16, my + 16, 4)
    love.graphics.circle("fill", mx + 16, my + mh - 16, 4)
    love.graphics.circle("fill", mx + mw - 16, my + mh - 16, 4)

    -- 1. "Вы проиграли!"
    love.graphics.setFont(fonts.xl)
    local line1 = i18n.t("bankrupt_title")
    local w1 = fonts.xl:getWidth(line1)
    love.graphics.setColor(0.95, 0.25, 0.2)
    love.graphics.print(line1, math.floor(mx + (mw - w1) / 2), my + 40)

    -- 2. "Вам начислено $10.000"
    love.graphics.setFont(fonts.md)
    local line2 = i18n.t("bankrupt_msg1")
    local w2 = fonts.md:getWidth(line2)
    love.graphics.setColor(1, 0.88, 0.3)
    love.graphics.print(line2, math.floor(mx + (mw - w2) / 2), my + 115)

    -- 3. "Попытайте удачу вновь"
    love.graphics.setFont(fonts.sm)
    local line3 = i18n.t("bankrupt_msg2")
    local w3 = fonts.sm:getWidth(line3)
    love.graphics.setColor(0.92, 0.82, 0.65)
    love.graphics.print(line3, math.floor(mx + (mw - w3) / 2), my + 165)

    -- Кнопка [X] "ПОНЯЛ"
    local bx = mx + (mw - 220) / 2
    local by = my + 240
    local bw = 220
    local bh = 54

    local isLocked = (bankruptModal.lockTimer > 0)

    if isLocked then
        love.graphics.setColor(0.06, 0.02, 0.01)
        love.graphics.rectangle("fill", bx, by + 4, bw, bh, 6)
        love.graphics.setColor(0.20, 0.20, 0.20)
        love.graphics.rectangle("fill", bx, by, bw, bh, 6)
        love.graphics.setColor(0.28, 0.28, 0.28)
        love.graphics.rectangle("fill", bx + 3, by + 3, bw - 6, bh - 6, 4)
        love.graphics.setColor(0.45, 0.45, 0.45)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, bw, bh, 6)
        love.graphics.setLineWidth(1)

        local btnLabel = i18n.t("understood")
        love.graphics.setFont(fonts.md)
        local bwTxt = fonts.md:getWidth(btnLabel)
        local bhTxt = fonts.md:getHeight()
        local totalW = 24 + 12 + bwTxt
        local startContentX = bx + math.floor((bw - totalW) / 2)

        ui.drawButtonBadge(startContentX + 12, by + bh / 2, 12, "X", 0.5, "gray")
        love.graphics.setColor(0.65, 0.65, 0.65)
        love.graphics.print(btnLabel, startContentX + 36, math.floor(by + (bh - bhTxt) / 2))
    else
        ui.drawSaloonButton(bx, by, bw, bh, "")
        local btnLabel = i18n.t("understood")
        love.graphics.setFont(fonts.md)
        local bwTxt = fonts.md:getWidth(btnLabel)
        local bhTxt = fonts.md:getHeight()
        local totalW = 24 + 12 + bwTxt
        local startContentX = bx + math.floor((bw - totalW) / 2)

        ui.drawButtonBadge(startContentX + 12, by + bh / 2, 12, "X", 1.0, "blue")
        love.graphics.setColor(255/255, 248/255, 235/255)
        love.graphics.print(btnLabel, startContentX + 36, math.floor(by + (bh - bhTxt) / 2))
    end
end

return bankruptModal
