local audio = {
    sounds = {}
}

local function generateTone(freq, duration, type, sampleRate)
    sampleRate = sampleRate or 44100
    local samples = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)

    for i = 0, samples - 1 do
        local t = i / sampleRate
        local envelope = math.exp(-t * (4 / duration))
        local sample = 0

        if type == "square" then
            sample = math.sin(2 * math.pi * freq * t) > 0 and 0.5 or -0.5
        elseif type == "sawtooth" then
            sample = (2 * ((t * freq) % 1) - 1) * 0.5
        else -- triangle / sine
            sample = math.sin(2 * math.pi * freq * t)
        end

        soundData:setSample(i, sample * envelope * 0.4)
    end

    return love.audio.newSource(soundData, "static")
end

function audio.init()
    pcall(function()
        audio.sounds.click = generateTone(210, 0.045, "triangle")
        audio.sounds.coin = generateTone(980, 0.08, "sine")
        audio.sounds.tick = generateTone(240, 0.025, "square")
        audio.sounds.fail = generateTone(140, 0.22, "sawtooth")
        audio.sounds.win = generateTone(880, 0.35, "sine")
        audio.sounds.tension = generateTone(650, 0.15, "sine")
        audio.sounds.fret = generateTone(360, 0.03, "triangle")
    end)
end

-- Воспроизведение звука с микро-вариацией высоты тона (чтоб не надоедали!)
function audio.play(name, customPitch)
    pcall(function()
        if audio.sounds[name] then
            local s = audio.sounds[name]:clone()
            local pitchJitter = customPitch or (0.94 + math.random() * 0.12)
            s:setPitch(pitchJitter)
            s:play()
        end
    end)
end

return audio
