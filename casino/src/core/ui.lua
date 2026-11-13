local ui = {}
local fonts = require("src.core.fonts")
local sprites = require("src.core.sprites")
local i18n = require("src.core.i18n")

local feltImage = nil

function ui.init()
    if feltImage then return end
    if not love or not love.image or not love.graphics then return end

    -- CPU-backed ImageData texture for saloon felt (8x8 tile pattern matching HTML mockup)
    local fw, fh = 1024, 768
    local feltData = love.image.newImageData(fw, fh)
    feltData:mapPixel(function(x, y, r, g, b, a)
        local tx = x % 8
        local ty = y % 8
        -- Subtle rich casino cloth weave: highlight at (0,0) group, shadow at (4,4) group
        if (tx <= 1 and ty <= 1) or (tx == 0 and ty == 7) or (tx == 7 and ty == 0) then
            return 18/255, 68/255, 34/255, 1 -- #124422 felt weave highlight
        elseif (math.abs(tx - 4) <= 1 and math.abs(ty - 4) <= 1) then
            return 7/255, 28/255, 14/255, 1  -- #071c0e felt weave shadow
        else
            return 11/255, 41/255, 21/255, 1 -- #0b2915 deep saloon felt
        end
    end)
    feltImage = love.graphics.newImage(feltData)
    feltImage:setFilter("nearest", "nearest")
end

function ui.drawCabinet()
    -- Outer cabinet frame: 1024x768
    -- Outer border #140702
    love.graphics.setColor(20/255, 7/255, 2/255, 1)
    love.graphics.rectangle("fill", 0, 0, 1024, 768)

    -- Mahogany wood #240e04
    love.graphics.setColor(36/255, 14/255, 4/255, 1)
    love.graphics.rectangle("fill", 6, 6, 1012, 756)

    -- Inset bevels: top/left #7e3911, bottom/right #3a1403
    love.graphics.setColor(126/255, 57/255, 17/255, 1)
    love.graphics.rectangle("fill", 6, 6, 1012, 4)
    love.graphics.rectangle("fill", 6, 6, 4, 756)
    love.graphics.setColor(58/255, 20/255, 3/255, 1)
    love.graphics.rectangle("fill", 6, 758, 1012, 4)
    love.graphics.rectangle("fill", 1014, 6, 4, 756)
end

function ui.drawFelt(x, y, w, h)
    if not feltImage then ui.init() end

    -- Inset felt drop shadow/border #140702
    love.graphics.setColor(20/255, 7/255, 2/255, 1)
    love.graphics.rectangle("fill", x - 4, y - 4, w + 8, h + 8, 6)

    -- Draw textured felt clamped to bounds
    if feltImage then
        love.graphics.setScissor(x, y, w, h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(feltImage, x, y)
        love.graphics.setScissor()
    else
        love.graphics.setColor(11/255, 41/255, 21/255, 1)
        love.graphics.rectangle("fill", x, y, w, h, 4)
    end

    -- Inner bevel of felt: top/left deep dark #05140a, bottom/right highlight #18522b
    love.graphics.setColor(5/255, 20/255, 10/255, 0.95)
    love.graphics.rectangle("fill", x, y, w, 5)
    love.graphics.rectangle("fill", x, y, 5, h)
    love.graphics.setColor(24/255, 82/255, 43/255, 0.85)
    love.graphics.rectangle("fill", x, y + h - 5, w, 5)
    love.graphics.rectangle("fill", x + w - 5, y, 5, h)
end

function ui.drawBrassPlaque(x, y, w, h, r)
    r = r or 4
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x, y + 2, w, h, r)

    -- Outer border #140702
    love.graphics.setColor(20/255, 7/255, 2/255, 1)
    love.graphics.rectangle("fill", x - 3, y - 3, w + 6, h + 6, r + 2)

    -- Linear gradient fill: #38180a -> #220d04
    for dy = 0, h - 1, 2 do
        local t = dy / h
        local cr = (56 * (1 - t) + 34 * t) / 255
        local cg = (24 * (1 - t) + 13 * t) / 255
        local cb = (10 * (1 - t) + 4 * t) / 255
        love.graphics.setColor(cr, cg, cb)
        love.graphics.rectangle("fill", x, y + dy, w, 2, r)
    end

    -- Inner bevel: top/left gold #c8861e, bottom/right dark #5c280e
    love.graphics.setColor(200/255, 134/255, 30/255, 0.9)
    love.graphics.rectangle("fill", x, y, w, 2)
    love.graphics.rectangle("fill", x, y, 2, h)
    love.graphics.setColor(92/255, 40/255, 14/255, 0.9)
    love.graphics.rectangle("fill", x, y + h - 2, w, 2)
    love.graphics.rectangle("fill", x + w - 2, y, 2, h)
end

function ui.drawSaloonButton(x, y, w, h, text, font, isPressed, alpha)
    font = font or fonts.lg
    alpha = alpha or 1.0
    local yOffset = isPressed and 2 or 0

    -- Drop shadow
    if not isPressed then
        love.graphics.setColor(0, 0, 0, 0.75 * alpha)
        love.graphics.rectangle("fill", x, y + 4, w, h, 4)
    end

    -- Outer border #140702
    love.graphics.setColor(20/255, 7/255, 2/255, alpha)
    love.graphics.rectangle("fill", x - 3, y + yOffset - 3, w + 6, h + 6, 5)

    -- Gradient #c7661b -> #a24b0f -> #753106
    for dy = 0, h - 1, 2 do
        local t = dy / h
        local cr = (199 * (1 - t) + 117 * t) / 255
        local cg = (102 * (1 - t) + 49 * t) / 255
        local cb = (27 * (1 - t) + 6 * t) / 255
        love.graphics.setColor(cr, cg, cb, alpha)
        love.graphics.rectangle("fill", x, y + yOffset + dy, w, 2, 4)
    end

    -- Inner bevels: top #fca868, bottom #521e02
    love.graphics.setColor(252/255, 168/255, 104/255, 0.85 * alpha)
    love.graphics.rectangle("fill", x + 1, y + yOffset + 1, w - 2, 2)
    love.graphics.rectangle("fill", x + 1, y + yOffset + 1, 2, h - 2)
    love.graphics.setColor(82/255, 30/255, 2/255, 0.85 * alpha)
    love.graphics.rectangle("fill", x + 1, y + yOffset + h - 3, w - 2, 2)
    love.graphics.rectangle("fill", x + w - 3, y + yOffset + 1, 2, h - 2)

    -- White hairline
    love.graphics.setColor(1, 1, 1, 0.4 * alpha)
    love.graphics.rectangle("fill", x + 2, y + yOffset + 1, w - 4, 1)

    -- Text
    if text and text ~= "" then
        love.graphics.setFont(font)
        local tw = font:getWidth(text)
        local th = font:getHeight()
        local tx = math.floor(x + (w - tw) / 2)
        local ty = math.floor(y + yOffset + (h - th) / 2)
        -- Text shadow #3a1502
        love.graphics.setColor(58/255, 21/255, 2/255, alpha)
        love.graphics.print(text, tx + 2, ty + 2)
        -- Text color #fff8eb
        love.graphics.setColor(255/255, 248/255, 235/255, alpha)
        love.graphics.print(text, tx, ty)
    end
end

function ui.drawSaloonButtonRed(x, y, w, h, isPressed, alpha)
    alpha = alpha or 1.0
    local yOffset = isPressed and 2 or 0

    -- Drop shadow
    if not isPressed then
        love.graphics.setColor(0, 0, 0, 0.8 * alpha)
        love.graphics.rectangle("fill", x, y + 4, w, h, 4)
    end

    -- Outer border #140702
    love.graphics.setColor(20/255, 7/255, 2/255, alpha)
    love.graphics.rectangle("fill", x - 3, y + yOffset - 3, w + 6, h + 6, 5)

    -- Gradient #d63220 -> #aa1e10 -> #7e1207
    for dy = 0, h - 1, 2 do
        local t = dy / h
        local cr = (214 * (1 - t) + 126 * t) / 255
        local cg = (50 * (1 - t) + 18 * t) / 255
        local cb = (32 * (1 - t) + 7 * t) / 255
        love.graphics.setColor(cr, cg, cb, alpha)
        love.graphics.rectangle("fill", x, y + yOffset + dy, w, 2, 4)
    end

    -- Inner bevels: top #f76857, bottom #520b04
    love.graphics.setColor(247/255, 104/255, 87/255, 0.9 * alpha)
    love.graphics.rectangle("fill", x + 1, y + yOffset + 1, w - 2, 2)
    love.graphics.rectangle("fill", x + 1, y + yOffset + 1, 2, h - 2)
    love.graphics.setColor(82/255, 11/255, 4/255, 0.9 * alpha)
    love.graphics.rectangle("fill", x + 1, y + yOffset + h - 3, w - 2, 2)
    love.graphics.rectangle("fill", x + w - 3, y + yOffset + 1, 2, h - 2)

    -- White top hairline
    love.graphics.setColor(1, 1, 1, 0.45 * alpha)
    love.graphics.rectangle("fill", x + 2, y + yOffset + 1, w - 4, 1)
end

function ui.drawArrow(cx, cy, size, direction, color)
    color = color or { 1, 0.88, 0.4, 1 }
    love.graphics.setColor(color)
    local s = size or 10
    local half = s / 2
    if direction == "left" then
        love.graphics.polygon("fill", cx + half, cy - half, cx - half, cy, cx + half, cy + half)
    else
        love.graphics.polygon("fill", cx - half, cy - half, cx + half, cy, cx - half, cy + half)
    end
end

function ui.drawButtonBadge(cx, cy, r, label, alpha, colorScheme)
    alpha = alpha or 1.0
    r = r or 12
    colorScheme = colorScheme or "yellow"

    -- Drop shadow under badge
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.circle("fill", cx, cy + 1.5, r)

    if colorScheme == "green" then
        for dy = -r, r do
            local t = (dy + r) / (2 * r)
            local cr = (74 * (1 - t) + 21 * t) / 255
            local cg = (222 * (1 - t) + 128 * t) / 255
            local cb = (128 * (1 - t) + 61 * t) / 255
            local w = math.sqrt(math.max(0, r * r - dy * dy))
            love.graphics.setColor(cr, cg, cb, alpha)
            love.graphics.rectangle("fill", cx - w, cy + dy, w * 2, 1)
        end
        love.graphics.setColor(15/255, 61/255, 30/255, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, r)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(5/255, 36/255, 16/255, alpha)
    elseif colorScheme == "red" then
        for dy = -r, r do
            local t = (dy + r) / (2 * r)
            local cr = (248 * (1 - t) + 185 * t) / 255
            local cg = (113 * (1 - t) + 28 * t) / 255
            local cb = (113 * (1 - t) + 28 * t) / 255
            local w = math.sqrt(math.max(0, r * r - dy * dy))
            love.graphics.setColor(cr, cg, cb, alpha)
            love.graphics.rectangle("fill", cx - w, cy + dy, w * 2, 1)
        end
        love.graphics.setColor(69/255, 10/255, 10/255, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, r)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(41/255, 5/255, 5/255, alpha)
    elseif colorScheme == "blue" then
        for dy = -r, r do
            local t = (dy + r) / (2 * r)
            local cr = (96 * (1 - t) + 29 * t) / 255
            local cg = (165 * (1 - t) + 78 * t) / 255
            local cb = (250 * (1 - t) + 216 * t) / 255
            local w = math.sqrt(math.max(0, r * r - dy * dy))
            love.graphics.setColor(cr, cg, cb, alpha)
            love.graphics.rectangle("fill", cx - w, cy + dy, w * 2, 1)
        end
        love.graphics.setColor(30/255, 58/255, 138/255, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, r)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, alpha)
    else -- yellow / gold (HTML mockup: #fde047 -> #eab308 -> #a16207)
        for dy = -r, r do
            local t = (dy + r) / (2 * r)
            local cr, cg, cb
            if t < 0.65 then
                local u = t / 0.65
                cr = (253 * (1 - u) + 234 * u) / 255
                cg = (224 * (1 - u) + 179 * u) / 255
                cb = (71 * (1 - u) + 8 * u) / 255
            else
                local u = (t - 0.65) / 0.35
                cr = (234 * (1 - u) + 161 * u) / 255
                cg = (179 * (1 - u) + 98 * u) / 255
                cb = (8 * (1 - u) + 7 * u) / 255
            end
            local w = math.sqrt(math.max(0, r * r - dy * dy))
            love.graphics.setColor(cr, cg, cb, alpha)
            love.graphics.rectangle("fill", cx - w, cy + dy, w * 2, 1)
        end
        love.graphics.setColor(66/255, 32/255, 6/255, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, r)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 0.55 * alpha)
        love.graphics.arc("line", cx, cy, r - 1, -math.pi * 0.85, -math.pi * 0.15)
        love.graphics.setColor(37/255, 19/255, 3/255, alpha)
    end

    -- Direction arrow or text label
    if label == "up" then
        love.graphics.polygon("fill", cx, cy - 4, cx - 4, cy + 3, cx + 4, cy + 3)
    elseif label == "down" then
        love.graphics.polygon("fill", cx, cy + 4, cx - 4, cy - 3, cx + 4, cy - 3)
    elseif label == "left" then
        love.graphics.polygon("fill", cx - 4, cy, cx + 3, cy - 4, cx + 3, cy + 4)
    elseif label == "right" then
        love.graphics.polygon("fill", cx + 4, cy, cx - 3, cy - 4, cx - 3, cy + 4)
    else
        local prevFont = love.graphics.getFont()
        local font = (label == "R2" or label == "L2") and fonts.xs or fonts.sm
        love.graphics.setFont(font)
        local kw = font:getWidth(label)
        local kh = font:getHeight()
        love.graphics.print(label, math.floor(cx - kw / 2), math.floor(cy - kh / 2))
        if prevFont then
            love.graphics.setFont(prevFont)
        end
    end
end

function ui.drawCard(c, x, y, cw, ch, isHeld, isFocused, isHidden, cardBack)
    cw = cw or 140
    ch = ch or 200
    local drawY = y
    if isFocused then
        drawY = y - 6
    end

    -- Focus glow and pointer
    if isFocused then
        love.graphics.setColor(1, 0.88, 0.4, 0.95)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", x - 3, drawY - 3, cw + 6, ch + 6, 8)
        love.graphics.setColor(1, 1, 0.88, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 1, drawY - 1, cw + 2, ch + 2, 6)
        love.graphics.setLineWidth(1)

        -- Желтый указатель ▼ над выбранной картой
        love.graphics.setFont(fonts.sm)
        love.graphics.setColor(1, 0.88, 0.4, 1)
        local pStr = "▼"
        local ptw = fonts.sm:getWidth(pStr)
        love.graphics.print(pStr, math.floor(x + (cw - ptw) / 2), drawY - 26)
    end

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", x + 3, drawY + 4, cw, ch, 6)

    -- Outer border #140702
    love.graphics.setColor(20/255, 7/255, 2/255, 1)
    love.graphics.rectangle("fill", x, drawY, cw, ch, 6)

    if isHidden then
        -- Card Back: Deep saloon mahogany with brass diamond lattice
        love.graphics.setColor(40/255, 16/255, 6/255, 1)
        love.graphics.rectangle("fill", x + 3, drawY + 3, cw - 6, ch - 6, 4)

        -- Inner border #8c4215
        love.graphics.setColor(140/255, 66/255, 21/255, 0.75)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 6, drawY + 6, cw - 12, ch - 12, 3)
        love.graphics.setLineWidth(1)

        -- Central Stardew star / stardrop emblem
        sprites.draw(cardBack or "stardrop", x + cw / 2, drawY + ch / 2, 54)
    else
        -- Face up card: Cream parchment #faecc3
        love.graphics.setColor(250/255, 236/255, 195/255, 1)
        love.graphics.rectangle("fill", x + 3, drawY + 3, cw - 6, ch - 6, 4)

        -- Bevel highlights: #fff9df top/left, #be9145 bot/right
        love.graphics.setColor(255/255, 249/255, 223/255, 0.9)
        love.graphics.rectangle("fill", x + 3, drawY + 3, cw - 6, 2)
        love.graphics.rectangle("fill", x + 3, drawY + 3, 2, ch - 6)
        love.graphics.setColor(190/255, 145/255, 69/255, 0.9)
        love.graphics.rectangle("fill", x + 3, drawY + ch - 5, cw - 6, 2)
        love.graphics.rectangle("fill", x + cw - 5, drawY + 3, 2, ch - 6)

        -- Card color by suit
        local isRed = (c.suit == "heart" or c.suit == "diamond")
        if isRed then
            love.graphics.setColor(179/255, 40/255, 26/255, 1) -- #b3281a
        else
            love.graphics.setColor(20/255, 7/255, 2/255, 1)    -- #140702
        end

        local rankFont = fonts.xl
        love.graphics.setFont(rankFont)

        -- Rank at top-left
        love.graphics.print(c.name, x + 8, drawY + 8)

        -- Rank at bottom-right
        local rtw = rankFont:getWidth(c.name)
        local rth = rankFont:getHeight()
        love.graphics.print(c.name, x + cw - 8 - rtw, drawY + ch - 8 - rth)

        -- Center suit icon (48x48)
        sprites.draw(c.suit, x + cw / 2, drawY + ch / 2, 48)
    end

    -- HELD Badge on top of card (for poker)
    if isHeld then
        local hw, hh = 66, 22
        local hx = math.floor(x + (cw - hw) / 2)
        local hy = drawY - 12
        love.graphics.setColor(20/255, 7/255, 2/255)
        love.graphics.rectangle("fill", hx - 1, hy - 1, hw + 2, hh + 2, 4)
        love.graphics.setColor(179/255, 40/255, 26/255) -- #b3281a
        love.graphics.rectangle("fill", hx, hy, hw, hh, 3)
        love.graphics.setFont(fonts.xs)
        local hText = (i18n.current == "ru") and "УДЕРЖ" or "HOLD"
        local htw = fonts.xs:getWidth(hText)
        local hth = fonts.xs:getHeight()
        love.graphics.setColor(255/255, 255/255, 255/255)
        love.graphics.print(hText, math.floor(hx + (hw - htw) / 2), math.floor(hy + (hh - hth) / 2))
    end
end

return ui
