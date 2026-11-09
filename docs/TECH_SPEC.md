# Technical Specification & Architecture

## 1. Стек и среда выполнения

- **Язык & Движок:** Lua 5.1 / LuaJIT + **LÖVE 11.5 (Love2D)**.
- **ОС & Платформа:** Linux ARM64 (Allwinner A133P) под управлением **NextUI** или **CrossMix-OS**.
- **Дисплей:** Родной фреймбуфер **1024 × 768 @ 60 Hz**.
- **Ввод:** `love.joystick` (SDL2 GameController API с автоопределением кнопок TrimUI Brick).
- **Звук:** OpenAL (сэмплы щелчков дерева, звона монет, фанфар).
- **Локализация:** Встроенный модуль `i18n` с поддержкой **Русского (RU)** и **Английского (EN)** языков.

---

## 2. Структура проекта

```
SlotGame-PortMaster/
├── docs/                      # Документация (GDD, TECH_SPEC, CONTROLS, DESIGN_SYSTEM)
├── casino/                    # Папка с исходным кодом игры
│   ├── main.lua               # Точка входа LÖVE, инициализация и главный цикл
│   ├── conf.lua               # Конфигурация окна (1024x768, vsync=true, title)
│   ├── locales/               # Словари локализации
│   │   ├── ru.lua             # Русский язык
│   │   └── en.lua             # Английский язык
│   ├── src/
│   │   ├── core/              # Системные модули
│   │   │   ├── state.lua      # Конечный автомат экранов (State Manager)
│   │   │   ├── input.lua      # Обработка D-Pad, кнопок и виртуальных событий
│   │   │   ├── economy.lua    # Баланс, конвертер ₽/$, история выигрышей
│   │   │   ├── i18n.lua       # Модуль локализации (ru/en)
│   │   │   ├── save.lua       # Чтение/запись save.json
│   │   │   └── audio.lua      # Звуковые эффекты и фоновая музыка
│   │   ├── ui/                # UI-компоненты
│   │   │   ├── topbar.lua     # Верхняя латунная панель статуса и баланса
│   │   │   ├── button.lua     # Резные деревянные кнопки
│   │   │   └── dialog.lua     # Модальные окна (Банкомат, Выбор языка)
│   │   ├── games/             # Модули игр
│   │   │   ├── lobby/         # Главное меню / выбор игры
│   │   │   ├── slots/         # Логика и рендеринг 3-барабанного слота
│   │   │   ├── blackjack/     # Блэкджек (Калико-Джек)
│   │   │   ├── roulette/      # Рулетка долины
│   │   │   └── poker/         # Салунный дро-покер
│   │   └── assets/            # Графика, шрифты и аудио
│   │       ├── fonts/         # TTF шрифт с полной поддержкой кириллицы
│   │       ├── sfx/           # Сэмплы (wood_click.wav, coin.wav, fanfare.wav)
│   │       └── textures/      # Атлас спрайтов (тайлы 64x64)
├── Casino.sh                  # Запускной bash-скрипт для PortMaster / NextUI
├── control.txt                # Метаданные для PortMaster
└── README.md                  # Руководство по сборке и установке
```

---

## 3. Модуль локализации (`src/core/i18n.lua`)

```lua
local i18n = {}
i18n.current = "ru" -- "ru" или "en"
i18n.locales = {
    ru = require("locales.ru"),
    en = require("locales.en")
}

function i18n.setLanguage(lang)
    if i18n.locales[lang] then
        i18n.current = lang
    end
end

function i18n.t(key)
    local dict = i18n.locales[i18n.current]
    return (dict and dict[key]) or key
end

return i18n
```

---

## 4. Модель сохранения данных (`save.json`)

```json
{
  "version": 1,
  "language": "ru",
  "currency": "RUB",
  "balance_rub": 50000,
  "balance_usd": 500,
  "stats": {
    "total_spins": 0,
    "total_hands": 0,
    "total_won_rub": 0,
    "biggest_win_rub": 0,
    "bankrupt_count": 0
  },
  "settings": {
    "sfx_volume": 1.0,
    "music_volume": 0.7
  }
}
```

---

## 5. Скрипт запуска для PortMaster и NextUI (`Casino.sh`)

```bash
#!/bin/bash
source /etc/profile 2>/dev/null || true
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

export PORTMASTER_HOME="/roms/ports"
export LD_LIBRARY_PATH="$SCRIPT_DIR/libs:$LD_LIBRARY_PATH"

if [ -f "/roms/ports/PortMaster/love" ]; then
    /roms/ports/PortMaster/love "$SCRIPT_DIR/casino"
elif which love >/dev/null 2>&1; then
    love "$SCRIPT_DIR/casino"
else
    ./love "$SCRIPT_DIR/casino"
fi
```
