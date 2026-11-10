function love.conf(t)
    t.identity = "stardew_saloon_casino"
    t.version = "11.5"
    t.console = false

    t.window.title = "Stardew Saloon Casino"
    t.window.width = 1024
    t.window.height = 768
    t.window.borderless = false
    t.window.resizable = false
    t.window.fullscreen = false
    t.window.vsync = 1
    t.window.highdpi = false
    t.window.stencil = true

    t.modules.audio = true
    t.modules.sound = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.keyboard = true
    t.modules.joystick = true
    t.modules.mouse = true
    t.modules.math = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.window = true
    t.modules.event = true
    t.modules.physics = false
    t.modules.video = false
    t.modules.touch = false
end
