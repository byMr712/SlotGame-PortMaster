local langModal = {}

local i18n = require("src.core.i18n")
local audio = require("src.core.audio")
local ui = require("src.core.ui")
local fonts = require("src.core.fonts")

langModal.active = false
langModal.selectedLang = "en"
langModal.cursorFocus = 1 -- 1: язык, 2: чекбокс, 3: кнопка играть
langModal.langCol = 1     -- 1: English, 2: Русский
langModal.remember = false

local CONFIG_FILE = "casino_config.json"

function langModal.init()
    if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(CONFIG_FILE) then
        local content = love.filesystem.read(CONFIG_FILE)
        if content then
            local ok, data = pcall(function()
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

    local mw = 540
    local mh = 360
    local mx = math.floor((1024 - mw) / 2)
    local my = math.floor((768 - mh) / 2)

    local btnW = 190
    local btnH = 50
    local gap = 32
    local startBtnX = mx + math.floor((mw - (btnW * 2 + gap)) / 2)
    local btnY = my + 82
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

    -- Клик по чекбоксу
    local cbY = my + 162
    local cbBoxX = mx + 60
    if x >= cbBoxX and x <= cbBoxX + 420 and y >= cbY - 4 and y <= cbY + 28 then
        langModal.cursorFocus = 2
        langModal.remember = not langModal.remember
        audio.play("click")
        return true
    end

    -- Клик по кнопке PLAY
    local playW = 260
    local playH = 50
    local playX = mx + math.floor((mw - playW) / 2)
    local playY = my + 220
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

    -- Затемнение экрана с салонной атмосферой
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, 1024, 768)

    local mw = 540
    local mh = 360
    local mx = math.floor((1024 - mw) / 2)
    local my = math.floor((768 - mh) / 2)

    -- Внешняя глубокая тень
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", mx + 8, my + 8, mw, mh, 14)

    -- Корпус из темного ореха (#220d04)
    love.graphics.setColor(34/255, 13/255, 4/255, 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, 12)

    -- Массивная золотая кайма (#c8861e)
    love.graphics.setColor(200/255, 134/255, 30/255, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", mx, my, mw, mh, 12)
    love.graphics.setLineWidth(1)

    -- 1. Заголовок модального окна (SELECT LANGUAGE / ВЫБЕРИТЕ ЯЗЫК)
    love.graphics.setFont(fonts.md)
    local title = "SELECT LANGUAGE / ВЫБЕРИТЕ ЯЗЫК"
    local tw = fonts.md:getWidth(title)
    local th = fonts.md:getHeight()
    local tx = math.floor(mx + (mw - tw) / 2)
    local ty = my + 30
    love.graphics.setColor(40/255, 16/255, 4/255, 1)
    love.graphics.print(title, tx + 2, ty + 2)
    love.graphics.setColor(1, 0.88, 0.4, 1)
    love.graphics.print(title, tx, ty)

    -- 2. Кнопки языков
    local btnW = 190
    local btnH = 50
    local gap = 32
    local startBtnX = mx + math.floor((mw - (btnW * 2 + gap)) / 2)
    local btnY = my + 82
    local ruX = startBtnX + btnW + gap

    local isEnSel = (langModal.selectedLang == "en")
    local isRuSel = (langModal.selectedLang == "ru")
    local isLangFocus = (langModal.cursorFocus == 1)

    -- Кнопка English
    ui.drawSaloonButton(startBtnX, btnY, btnW, btnH, "", fonts.lg, false, isEnSel and 1.0 or 0.72)
    if isEnSel then
        love.graphics.setColor(1, 0.88, 0.4, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", startBtnX - 1, btnY - 1, btnW + 2, btnH + 2, 5)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setFont(fonts.lg)
    local enStr = "English"
    local enW = fonts.lg:getWidth(enStr)
    local enH = fonts.lg:getHeight()
    local enTx = math.floor(startBtnX + (btnW - enW) / 2)
    local enTy = math.floor(btnY + (btnH - enH) / 2)
    love.graphics.setColor(58/255, 21/255, 2/255, 1)
    love.graphics.print(enStr, enTx + 2, enTy + 2)
    love.graphics.setColor(255/255, 248/255, 235/255, 1)
    love.graphics.print(enStr, enTx, enTy)

    if isLangFocus and isEnSel then
        ui.drawArrow(enTx - 16, btnY + btnH / 2, 10, "right", { 1, 0.88, 0.4, 1 })
        ui.drawArrow(enTx + enW + 16, btnY + btnH / 2, 10, "left", { 1, 0.88, 0.4, 1 })
    end

    -- Кнопка Русский
    ui.drawSaloonButton(ruX, btnY, btnW, btnH, "", fonts.lg, false, isRuSel and 1.0 or 0.72)
    if isRuSel then
        love.graphics.setColor(1, 0.88, 0.4, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", ruX - 1, btnY - 1, btnW + 2, btnH + 2, 5)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setFont(fonts.lg)
    local ruStr = "Русский"
    local ruW = fonts.lg:getWidth(ruStr)
    local ruH = fonts.lg:getHeight()
    local ruTx = math.floor(ruX + (btnW - ruW) / 2)
    local ruTy = math.floor(btnY + (btnH - ruH) / 2)
    love.graphics.setColor(58/255, 21/255, 2/255, 1)
    love.graphics.print(ruStr, ruTx + 2, ruTy + 2)
    love.graphics.setColor(255/255, 248/255, 235/255, 1)
    love.graphics.print(ruStr, ruTx, ruTy)

    if isLangFocus and isRuSel then
        ui.drawArrow(ruTx - 16, btnY + btnH / 2, 10, "right", { 1, 0.88, 0.4, 1 })
        ui.drawArrow(ruTx + ruW + 16, btnY + btnH / 2, 10, "left", { 1, 0.88, 0.4, 1 })
    end

    -- 3. Чекбокс "Запомнить мой выбор"
    local cbY = my + 162
    local isCbFocus = (langModal.cursorFocus == 2)
    local cbBoxSize = 22
    local cbBoxX = mx + 68

    love.graphics.setColor(26/255, 8/255, 2/255, 1)
    love.graphics.rectangle("fill", cbBoxX, cbY, cbBoxSize, cbBoxSize, 4)
    love.graphics.setColor(200/255, 134/255, 30/255, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cbBoxX, cbY, cbBoxSize, cbBoxSize, 4)
    love.graphics.setLineWidth(1)

    if langModal.remember then
        love.graphics.setColor(74/255, 222/255, 128/255, 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(cbBoxX + 4, cbY + 11, cbBoxX + 9, cbY + 16, cbBoxX + 17, cbY + 5)
        love.graphics.setLineWidth(1)
    end

    local remText = (langModal.selectedLang == "ru") and "Запомнить мой выбор" or "Remember my choice"
    love.graphics.setFont(fonts.sm)
    local rth = fonts.sm:getHeight()
    local rty = math.floor(cbY + (cbBoxSize - rth) / 2)
    love.graphics.setColor(40/255, 16/255, 4/255, 1)
    love.graphics.print(remText, cbBoxX + cbBoxSize + 14 + 1, rty + 1)
    if isCbFocus then
        love.graphics.setColor(1, 0.88, 0.4, 1)
    else
        love.graphics.setColor(255/255, 234/255, 173/255, 1)
    end
    love.graphics.print(remText, cbBoxX + cbBoxSize + 14, rty)

    if isCbFocus then
        ui.drawArrow(cbBoxX - 14, cbY + cbBoxSize / 2, 8, "right", { 1, 0.88, 0.4, 1 })
    end

    -- 4. Кнопка PLAY / ИГРАТЬ
    local playW = 260
    local playH = 50
    local playX = mx + math.floor((mw - playW) / 2)
    local playY = my + 220
    local isPlayFocus = (langModal.cursorFocus == 3)

    ui.drawSaloonButtonRed(playX, playY, playW, playH, isPlayFocus and love.keyboard.isDown("a", "space", "return"))

    love.graphics.setFont(fonts.lg)
    local playLabel = (langModal.selectedLang == "ru") and "ИГРАТЬ" or "PLAY"
    local plw = fonts.lg:getWidth(playLabel)
    local plh = fonts.lg:getHeight()
    local plTx = math.floor(playX + (playW - plw) / 2)
    local plTy = math.floor(playY + (playH - plh) / 2)

    love.graphics.setColor(59/255, 8/255, 2/255, 1)
    love.graphics.print(playLabel, plTx + 2, plTy + 2)
    love.graphics.setColor(255/255, 250/255, 240/255, 1)
    love.graphics.print(playLabel, plTx, plTy)

    if isPlayFocus then
        love.graphics.setColor(1, 0.88, 0.4, 0.95)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", playX - 2, playY - 2, playW + 4, playH + 4, 6)
        love.graphics.setLineWidth(1)
        ui.drawArrow(playX - 16, playY + playH / 2, 10, "right", { 1, 0.88, 0.4, 1 })
        ui.drawArrow(playX + playW + 16, playY + playH / 2, 10, "left", { 1, 0.88, 0.4, 1 })
    end

    -- 5. Подсказка управления внизу
    love.graphics.setFont(fonts.xs)
    local hint = (langModal.selectedLang == "ru") and "[◀/▲/▼/▶] ВЫБОР   •   [A] ПОДТВЕРДИТЬ" or "[◀/▲/▼/▶] SELECT   •   [A] CONFIRM"
    local hw = fonts.xs:getWidth(hint)
    local hx = math.floor(mx + (mw - hw) / 2)
    local hy = my + mh - 30
    love.graphics.setColor(40/255, 16/255, 4/255, 1)
    love.graphics.print(hint, hx + 1, hy + 1)
    love.graphics.setColor(255/255, 234/255, 173/255, 0.8)
    love.graphics.print(hint, hx, hy)
end

return langModal
