local langModal = {}

local i18n = require("src.core.i18n")
local audio = require("src.core.audio")

langModal.active = false
langModal.selectedLang = "en"
langModal.cursorFocus = 1 -- 1: язык (кнопки), 2: чекбокс, 3: кнопка играть
langModal.langCol = 1     -- 1: English, 2: Русский
langModal.remember = false

local CONFIG_FILE = "casino_config.json"

function langModal.init()
    -- Проверяем сохраненные настройки
    if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(CONFIG_FILE) then
        local content = love.filesystem.read(CONFIG_FILE)
        if content then
            local ok, data = pcall(function()
                -- Простой парсер JSON для { "lang": "...", "remember": true/false }
                local lang = content:match('"lang"%s*:%s*"([^"]+)"')
                local rem = content:match('"remember"%s*:%s*(true)')
                return { lang = lang, remember = (rem ~= nil) }
            end)
            if ok and data and data.remember and data.lang then
                i18n.setLanguage(data.lang)
                langModal.active = false
                return
            end
        end
    end

    -- Если не сохранено, открываем окно выбора языка при старте
    langModal.active = true
    langModal.selectedLang = i18n.current or "en"
    langModal.langCol = (langModal.selectedLang == "ru") and 2 or 1
    langModal.cursorFocus = 1
    langModal.remember = false
end

function langModal.open()
    langModal.active = true
    langModal.selectedLang = i18n.current or "en"
    langModal.langCol = (langModal.selectedLang == "ru") and 2 or 1
    langModal.cursorFocus = 1
    langModal.remember = false
end

function langModal.saveChoice()
    if not love.filesystem then return end
    local json = string.format('{\n  "lang": "%s",\n  "remember": %s\n}', langModal.selectedLang, tostring(langModal.remember))
    love.filesystem.write(CONFIG_FILE, json)
end

function langModal.confirmPlay()
    i18n.setLanguage(langModal.selectedLang)
    if langModal.remember then
        langModal.saveChoice()
    else
        if love.filesystem and love.filesystem.remove then
            pcall(function() love.filesystem.remove(CONFIG_FILE) end)
        end
    end
    audio.play("click")
    langModal.active = false
end

function langModal.mousepressed(x, y)
    if not langModal.active then return false end

    local mx = 262
    local my = 194
    local mw = 500
    local mh = 360

    local btnW = 180
    local btnH = 52
    local gap = 40
    local startBtnX = mx + (mw - (btnW * 2 + gap)) / 2
    local btnY = my + 85
    local ruX = startBtnX + btnW + gap

    -- Клик по кнопке English
    if x >= startBtnX and x <= startBtnX + btnW and y >= btnY and y <= btnY + btnH then
        langModal.cursorFocus = 1
        langModal.langCol = 1
        langModal.selectedLang = "en"
        i18n.setLanguage("en")
        audio.play("click")
        return true
    end

    -- Клик по кнопке Русский
    if x >= ruX and x <= ruX + btnW and y >= btnY and y <= btnY + btnH then
        langModal.cursorFocus = 1
        langModal.langCol = 2
        langModal.selectedLang = "ru"
        i18n.setLanguage("ru")
        audio.play("click")
        return true
    end

    -- Клик по чекбоксу "Запомнить мой выбор"
    local cbY = my + 175
    local cbBoxX = mx + 90
    if x >= cbBoxX and x <= cbBoxX + 320 and y >= cbY - 4 and y <= cbY + 28 then
        langModal.cursorFocus = 2
        langModal.remember = not langModal.remember
        audio.play("click")
        return true
    end

    -- Клик по кнопке "ИГРАТЬ" / "PLAY"
    local playW = 220
    local playH = 46
    local playX = mx + (mw - playW) / 2
    local playY = my + 230
    if x >= playX and x <= playX + playW and y >= playY and y <= playY + playH then
        langModal.cursorFocus = 3
        langModal.confirmPlay()
        return true
    end

    return true
end

function langModal.keypressed(key)
    if not langModal.active then return false end

    if key == "up" then
        if langModal.cursorFocus > 1 then
            langModal.cursorFocus = langModal.cursorFocus - 1
            audio.play("click")
        end
        return true
    elseif key == "down" then
        if langModal.cursorFocus < 3 then
            langModal.cursorFocus = langModal.cursorFocus + 1
            audio.play("click")
        end
        return true
    elseif key == "left" or key == "right" then
        if langModal.cursorFocus == 1 then
            langModal.langCol = (langModal.langCol == 1) and 2 or 1
            langModal.selectedLang = (langModal.langCol == 1) and "en" or "ru"
            i18n.setLanguage(langModal.selectedLang)
            audio.play("click")
        end
        return true
    elseif key == "a" or key == "space" or key == "return" then
        if langModal.cursorFocus == 1 then
            langModal.confirmPlay()
        elseif langModal.cursorFocus == 2 then
            langModal.remember = not langModal.remember
            audio.play("click")
        elseif langModal.cursorFocus == 3 then
            langModal.confirmPlay()
        end
        return true
    elseif key == "b" or key == "escape" or key == "start" then
        langModal.confirmPlay()
        return true
    end

    return true
end

function langModal.draw()
    if not langModal.active then return end

    -- Затемнение экрана
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1024, 768)

    local mx = 262
    local my = 194
    local mw = 500
    local mh = 360

    -- Тень окна
    love.graphics.setColor(0.04, 0.02, 0.01)
    love.graphics.rectangle("fill", mx + 6, my + 6, mw, mh, 10)

    -- Корпус окна (темный орех + золотая рамка)
    love.graphics.setColor(0.16, 0.07, 0.02)
    love.graphics.rectangle("fill", mx, my, mw, mh, 10)
    love.graphics.setColor(0.78, 0.52, 0.12)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", mx, my, mw, mh, 10)
    love.graphics.setLineWidth(1)

    -- Внутреннее поле
    love.graphics.setColor(0.09, 0.04, 0.01)
    love.graphics.rectangle("fill", mx + 12, my + 12, mw - 24, mh - 24, 8)

    -- Заголовок
    love.graphics.setColor(1, 0.88, 0.4)
    local title = "SELECT LANGUAGE / ВЫБЕРИТЕ ЯЗЫК"
    local font = love.graphics.getFont()
    local tw = font and font:getWidth(title) or (#title * 8)
    love.graphics.print(title, mx + mw / 2 - tw / 2, my + 30)

    -- Ряд 1: Кнопки выбора языка друг напротив друга
    local btnW = 180
    local btnH = 52
    local gap = 40
    local startBtnX = mx + (mw - (btnW * 2 + gap)) / 2
    local btnY = my + 85

    -- Кнопка English
    local isEnSel = (langModal.selectedLang == "en")
    local isEnFocus = (langModal.cursorFocus == 1 and langModal.langCol == 1)
    if isEnSel then
        love.graphics.setColor(0.25, 0.14, 0.04)
    else
        love.graphics.setColor(0.12, 0.05, 0.02)
    end
    love.graphics.rectangle("fill", startBtnX, btnY, btnW, btnH, 6)

    if isEnFocus then
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", startBtnX, btnY, btnW, btnH, 6)
        love.graphics.setLineWidth(1)
    elseif isEnSel then
        love.graphics.setColor(0.78, 0.52, 0.12)
        love.graphics.rectangle("line", startBtnX, btnY, btnW, btnH, 6)
    else
        love.graphics.setColor(0.4, 0.2, 0.08)
        love.graphics.rectangle("line", startBtnX, btnY, btnW, btnH, 6)
    end

    love.graphics.setColor(isEnSel and {1, 0.95, 0.7} or {0.7, 0.6, 0.45})
    local enText = isEnFocus and "► English ◄" or "English"
    local etw = font and font:getWidth(enText) or (#enText * 8)
    love.graphics.print(enText, startBtnX + btnW / 2 - etw / 2, btnY + 18)

    -- Кнопка Русский
    local ruX = startBtnX + btnW + gap
    local isRuSel = (langModal.selectedLang == "ru")
    local isRuFocus = (langModal.cursorFocus == 1 and langModal.langCol == 2)
    if isRuSel then
        love.graphics.setColor(0.25, 0.14, 0.04)
    else
        love.graphics.setColor(0.12, 0.05, 0.02)
    end
    love.graphics.rectangle("fill", ruX, btnY, btnW, btnH, 6)

    if isRuFocus then
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", ruX, btnY, btnW, btnH, 6)
        love.graphics.setLineWidth(1)
    elseif isRuSel then
        love.graphics.setColor(0.78, 0.52, 0.12)
        love.graphics.rectangle("line", ruX, btnY, btnW, btnH, 6)
    else
        love.graphics.setColor(0.4, 0.2, 0.08)
        love.graphics.rectangle("line", ruX, btnY, btnW, btnH, 6)
    end

    love.graphics.setColor(isRuSel and {1, 0.95, 0.7} or {0.7, 0.6, 0.45})
    local ruText = isRuFocus and "► Русский ◄" or "Русский"
    local rtw = font and font:getWidth(ruText) or (#ruText * 8)
    love.graphics.print(ruText, ruX + btnW / 2 - rtw / 2, btnY + 18)

    -- Ряд 2: Чекбокс "Запомнить мой выбор" на выбранном языке
    local cbY = my + 175
    local isCbFocus = (langModal.cursorFocus == 2)
    local cbBoxSize = 22
    local cbBoxX = mx + 90

    -- Квадрат чекбокса
    love.graphics.setColor(0.14, 0.06, 0.02)
    love.graphics.rectangle("fill", cbBoxX, cbY, cbBoxSize, cbBoxSize, 4)
    if isCbFocus then
        love.graphics.setColor(1, 0.88, 0.3)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", cbBoxX, cbY, cbBoxSize, cbBoxSize, 4)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0.65, 0.45, 0.15)
        love.graphics.rectangle("line", cbBoxX, cbY, cbBoxSize, cbBoxSize, 4)
    end

    -- Галочка
    if langModal.remember then
        love.graphics.setColor(0.2, 0.95, 0.4)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(cbBoxX + 4, cbY + 11, cbBoxX + 9, cbY + 17, cbBoxX + 18, cbY + 5)
        love.graphics.setLineWidth(1)
    end

    -- Текст чекбокса на текущем языке
    local remText = (langModal.selectedLang == "ru") and "Запомнить мой выбор" or "Remember my choice"
    love.graphics.setColor(isCbFocus and {1, 0.95, 0.7} or {0.85, 0.75, 0.6})
    love.graphics.print(remText, cbBoxX + 34, cbY + 3)

    -- Ряд 3: Кнопка "Играть" / "Play"
    local playW = 220
    local playH = 46
    local playX = mx + (mw - playW) / 2
    local playY = my + 230
    local isPlayFocus = (langModal.cursorFocus == 3)

    -- Корпус кнопки Play (салунный рубин / орех)
    love.graphics.setColor(0.65, 0.18, 0.12)
    love.graphics.rectangle("fill", playX, playY, playW, playH, 6)
    if isPlayFocus then
        love.graphics.setColor(1, 0.88, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", playX, playY, playW, playH, 6)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0.85, 0.45, 0.25)
        love.graphics.rectangle("line", playX, playY, playW, playH, 6)
    end

    love.graphics.setColor(1, 1, 1)
    local playLabel = (langModal.selectedLang == "ru") and "ИГРАТЬ" or "PLAY"
    if isPlayFocus then playLabel = "► " .. playLabel .. " ◄" end
    local ptw = font and font:getWidth(playLabel) or (#playLabel * 8)
    love.graphics.print(playLabel, playX + playW / 2 - ptw / 2, playY + 16)

    -- Подсказка управления
    love.graphics.setColor(0.7, 0.55, 0.3)
    local hint = "[◄/▲/▼/►] SELECT   •   [A] CONFIRM"
    local htw = font and font:getWidth(hint) or (#hint * 7)
    love.graphics.print(hint, mx + mw / 2 - htw / 2, my + 305)
end

return langModal
