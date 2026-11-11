local viewport = {}

viewport.BASE_W = 1024
viewport.BASE_H = 768

viewport.screenW = 1024
viewport.screenH = 768
viewport.scale = 1
viewport.offsetX = 0
viewport.offsetY = 0

local mainCanvas = nil

function viewport.init()
    if not love or not love.graphics then return end
    if not mainCanvas then
        mainCanvas = love.graphics.newCanvas(viewport.BASE_W, viewport.BASE_H)
        mainCanvas:setFilter("linear", "linear")
    end
    viewport.updateDimensions(love.graphics.getDimensions())
end

function viewport.updateDimensions(w, h)
    viewport.screenW = w
    viewport.screenH = h

    -- Scale factor preserving native 4:3 aspect ratio
    local scaleX = w / viewport.BASE_W
    local scaleY = h / viewport.BASE_H
    viewport.scale = math.min(scaleX, scaleY)

    -- Centering with letterboxing / pillarboxing
    viewport.offsetX = math.floor((w - viewport.BASE_W * viewport.scale) / 2)
    viewport.offsetY = math.floor((h - viewport.BASE_H * viewport.scale) / 2)
end

function viewport.startRender()
    if not mainCanvas then viewport.init() end
    love.graphics.setCanvas({ mainCanvas, stencil = true })
    love.graphics.clear(0.04, 0.02, 0.01, 1)
end

function viewport.endRender()
    love.graphics.setCanvas()

    -- Fill background around letterbox / pillarbox area with deep mahogany saloon wood #140702
    love.graphics.setColor(20/255, 7/255, 2/255, 1)
    love.graphics.rectangle("fill", 0, 0, viewport.screenW, viewport.screenH)

    -- Draw the scaled 1024x768 virtual canvas
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mainCanvas, viewport.offsetX, viewport.offsetY, 0, viewport.scale, viewport.scale)

    -- If pillarboxing (e.g. 16:9 widescreen), draw saloon wooden pillars with decorative bevels on left & right
    if viewport.offsetX > 0 then
        -- Left bar
        love.graphics.setColor(0.08, 0.03, 0.01, 0.85)
        love.graphics.rectangle("fill", 0, 0, viewport.offsetX, viewport.screenH)
        love.graphics.setColor(126/255, 57/255, 17/255, 0.9)
        love.graphics.line(viewport.offsetX, 0, viewport.offsetX, viewport.screenH)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.line(viewport.offsetX - 1, 0, viewport.offsetX - 1, viewport.screenH)

        -- Right bar
        local rightX = viewport.screenW - viewport.offsetX
        love.graphics.setColor(0.08, 0.03, 0.01, 0.85)
        love.graphics.rectangle("fill", rightX, 0, viewport.offsetX, viewport.screenH)
        love.graphics.setColor(126/255, 57/255, 17/255, 0.9)
        love.graphics.line(rightX, 0, rightX, viewport.screenH)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.line(rightX + 1, 0, rightX + 1, viewport.screenH)
    elseif viewport.offsetY > 0 then
        -- Top bar
        love.graphics.setColor(0.08, 0.03, 0.01, 0.85)
        love.graphics.rectangle("fill", 0, 0, viewport.screenW, viewport.offsetY)
        love.graphics.setColor(126/255, 57/255, 17/255, 0.9)
        love.graphics.line(0, viewport.offsetY, viewport.screenW, viewport.offsetY)

        -- Bottom bar
        local bottomY = viewport.screenH - viewport.offsetY
        love.graphics.setColor(0.08, 0.03, 0.01, 0.85)
        love.graphics.rectangle("fill", 0, bottomY, viewport.screenW, viewport.offsetY)
        love.graphics.setColor(126/255, 57/255, 17/255, 0.9)
        love.graphics.line(0, bottomY, viewport.screenW, bottomY)
    end
end

-- Convert screen coordinates (mouse, touch) into virtual 1024x768 coordinates
function viewport.toVirtual(screenX, screenY)
    local vx = (screenX - viewport.offsetX) / viewport.scale
    local vy = (screenY - viewport.offsetY) / viewport.scale
    return vx, vy
end

-- Check if point is inside virtual 1024x768 area
function viewport.isInside(screenX, screenY)
    local vx, vy = viewport.toVirtual(screenX, screenY)
    return vx >= 0 and vx <= viewport.BASE_W and vy >= 0 and vy <= viewport.BASE_H
end

return viewport
