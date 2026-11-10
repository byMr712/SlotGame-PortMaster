local bankruptModal = {}

local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local economy = require("src.core.economy")

bankruptModal.active = false
local onResetCallback = nil

function bankruptModal.setResetCallback(cb)
    onResetCallback = cb
end

function bankruptModal.open()
    bankruptModal.active = true
    audio.play("fail")
end

function bankruptModal.check()
    if economy.getBalance() <= 0 then
        bankruptModal.open()
        return true
    end
    return false
end

function bankruptModal.confirm()
    economy.balance = 10000
    if onResetCallback then
        onResetCallback()
    end
    audio.play("win")
    bankruptModal.active = false
end

function bankruptModal.keypressed(key)
    if not bankruptModal.active then return false end
    if key == "a" or key == "return" or key == "space" then
        bankruptModal.confirm()
        return true
    end
    return true
end

function bankruptModal.mousepressed(x, y)
    if not bankruptModal.active then return false end
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

local titleFont = nil
local msgFont = nil
local function getFonts()
    if not titleFont and love.graphics and love.graphics.newFont then
        pcall(function()
            titleFont = love.graphics.newFont(24)
            msgFont = love.graphics.newFont(16)
        end)
    end
    return titleFont, msgFont
end

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

    local oldFont = love.graphics.getFont()
    local tFont, mFont = getFonts()

    -- 1. "Вы проиграли!"
    if tFont then love.graphics.setFont(tFont) end
    local line1 = i18n.t("bankrupt_title")
    local curFont = love.graphics.getFont()
    local w1 = curFont:getWidth(line1)
    love.graphics.setColor(0.95, 0.25, 0.2)
    love.graphics.print(line1, mx + (mw - w1) / 2, my + 40)

    -- 2. "Вам снова начислено $10.000"
    if mFont then love.graphics.setFont(mFont) end
    curFont = love.graphics.getFont()
    local line2 = i18n.t("bankrupt_msg1")
    local w2 = curFont:getWidth(line2)
    love.graphics.setColor(1, 0.88, 0.3)
    love.graphics.print(line2, mx + (mw - w2) / 2, my + 115)

    -- 3. "Попытайте удачу вновь"
    local line3 = i18n.t("bankrupt_msg2")
    local w3 = curFont:getWidth(line3)
    love.graphics.setColor(0.92, 0.82, 0.65)
    love.graphics.print(line3, mx + (mw - w3) / 2, my + 165)

    -- Кнопка "ПОНЯЛ" (А)
    local bx = mx + (mw - 220) / 2
    local by = my + 240
    local bw = 220
    local bh = 54

    -- Тень кнопки
    love.graphics.setColor(0.06, 0.02, 0.01)
    love.graphics.rectangle("fill", bx, by + 4, bw, bh, 6)

    -- Тело кнопки (золотой салунный градиент)
    love.graphics.setColor(0.68, 0.28, 0.08)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6)
    love.graphics.setColor(0.85, 0.45, 0.12)
    love.graphics.rectangle("fill", bx + 3, by + 3, bw - 6, bh - 6, 4)

    -- Золотая обводка
    love.graphics.setColor(1, 0.88, 0.4)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", bx, by, bw, bh, 6)
    love.graphics.setLineWidth(1)

    -- Значок [A]
    love.graphics.setColor(0.2, 0.78, 0.35)
    love.graphics.circle("fill", bx + 32, by + bh / 2, 14)
    love.graphics.setColor(0.08, 0.03, 0.01)
    love.graphics.circle("line", bx + 32, by + bh / 2, 14)
    love.graphics.setColor(0.08, 0.03, 0.01)
    if tFont then love.graphics.setFont(tFont) end
    love.graphics.print("A", bx + 26, by + bh / 2 - 13)

    -- Текст "ПОНЯЛ"
    love.graphics.setColor(1, 0.95, 0.8)
    local btnLabel = i18n.t("understood")
    local bwTxt = love.graphics.getFont():getWidth(btnLabel)
    love.graphics.print(btnLabel, bx + 64 + (bw - 84 - bwTxt) / 2, by + bh / 2 - 13)

    love.graphics.setFont(oldFont)
end

return bankruptModal
