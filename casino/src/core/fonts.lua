local fonts = {}

local fontCache = {}

function fonts.get(size)
    size = math.floor(size or 12)
    if not fontCache[size] then
        local success, f = pcall(love.graphics.newFont, "pressstart2p.ttf", size)
        if success and f then
            fontCache[size] = f
        else
            fontCache[size] = love.graphics.newFont(size)
        end
    end
    return fontCache[size]
end

function fonts.init()
    fonts.xs = fonts.get(8)
    fonts.sm = fonts.get(10)
    fonts.md = fonts.get(12)
    fonts.lg = fonts.get(15)
    fonts.xl = fonts.get(18)
    fonts.xxl = fonts.get(22)
    love.graphics.setFont(fonts.md)
end

return fonts
