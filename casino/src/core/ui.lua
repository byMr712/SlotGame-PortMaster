local ui = {}
local fonts = require("src.core.fonts")

local feltImage = nil

function ui.init()
    if feltImage then return end
    if not love or not love.image or not love.graphics then return end

    -- CPU-backed ImageData texture for felt (992x672) - immune to OpenGL context recreation
    local fw, fh = 992, 672
    local feltData = love.image.newImageData(fw, fh)
    feltData:mapPixel(function(x, y, r, g, b, a)
        if (x % 8 == 0 and y % 8 == 0) or (x % 8 == 4 and y % 8 == 4) then
            return 16/255, 61/255, 31/255, 1 -- #103d1f micro-dot
        else
            return 11/255, 41/255, 21/255, 1 -- #0b2915 deep felt
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

    -- Draw textured felt
    if feltImage then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(feltImage, x, y)
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

function ui.drawSaloonButton(x, y, w, h, text, font, isPressed)
    font = font or fonts.lg
    local yOffset = isPressed and 2 or 0

    -- Drop shadow
    if not isPressed then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", x, y + 4, w, h, 4)
    end

    -- Outer border #140702
    love.graphics.setColor(20/255, 7/255, 2/255, 1)
    love.graphics.rectangle("fill", x - 3, y + yOffset - 3, w + 6, h + 6, 5)

    -- Gradient #c7661b -> #a24b0f -> #753106
    for dy = 0, h - 1, 2 do
        local t = dy / h
        local cr = (199 * (1 - t) + 117 * t) / 255
        local cg = (102 * (1 - t) + 49 * t) / 255
        local cb = (27 * (1 - t) + 6 * t) / 255
        love.graphics.setColor(cr, cg, cb)
        love.graphics.rectangle("fill", x, y + yOffset + dy, w, 2, 4)
    end

    -- Inner bevels: top #fca868, bottom #521e02
    love.graphics.setColor(252/255, 168/255, 104/255, 0.85)
    love.graphics.rectangle("fill", x + 1, y + yOffset + 1, w - 2, 2)
    love.graphics.rectangle("fill", x + 1, y + yOffset + 1, 2, h - 2)
    love.graphics.setColor(82/255, 30/255, 2/255, 0.85)
    love.graphics.rectangle("fill", x + 1, y + yOffset + h - 3, w - 2, 2)
    love.graphics.rectangle("fill", x + w - 3, y + yOffset + 1, 2, h - 2)

    -- White hairline
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle("fill", x + 2, y + yOffset + 1, w - 4, 1)

    -- Text
    if text and text ~= "" then
        love.graphics.setFont(font)
        local tw = font:getWidth(text)
        local th = font:getHeight()
        local tx = math.floor(x + (w - tw) / 2)
        local ty = math.floor(y + yOffset + (h - th) / 2)
        -- Text shadow #3a1502
        love.graphics.setColor(58/255, 21/255, 2/255, 1)
        love.graphics.print(text, tx + 2, ty + 2)
        -- Text color #fff8eb
        love.graphics.setColor(255/255, 248/255, 235/255, 1)
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

function ui.drawButtonBadge(cx, cy, r, label, alpha)
    alpha = alpha or 1.0
    r = r or 12
    -- Circle fill: gradient gold #fde047 -> #a16207
    love.graphics.setColor(245/255, 184/255, 46/255, alpha)
    love.graphics.circle("fill", cx, cy, r)
    -- Highlight top half
    love.graphics.setColor(253/255, 224/255, 71/255, 0.85 * alpha)
    love.graphics.arc("fill", cx, cy, r, -math.pi, 0)
    -- Dark border #422006
    love.graphics.setColor(66/255, 32/255, 6/255, alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r)
    love.graphics.setLineWidth(1)

    -- Label in center
    local font = fonts.xs
    love.graphics.setFont(font)
    local kw = font:getWidth(label)
    local kh = font:getHeight()
    love.graphics.setColor(37/255, 19/255, 3/255, alpha)
    love.graphics.print(label, math.floor(cx - kw / 2), math.floor(cy - kh / 2))
end

return ui
