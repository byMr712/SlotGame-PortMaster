#!/bin/bash
# PortMaster / NextUI Launcher for Slot Game on TrimUI Brick

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt 2>/dev/null
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

GAMEDIR="/$directory/ports/casino"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

cd $GAMEDIR

# Поиск среды выполнения LÖVE 11.x (PortMaster / Linux)
if [ -f "/usr/bin/love" ]; then
  LOVE_BIN="/usr/bin/love"
elif [ -f "$controlfolder/love/love" ]; then
  LOVE_BIN="$controlfolder/love/love"
elif [ -f "$controlfolder/libs/love/love" ]; then
  LOVE_BIN="$controlfolder/libs/love/love"
elif [ -f "/roms/ports/PortMaster/love/love" ]; then
  LOVE_BIN="/roms/ports/PortMaster/love/love"
else
  LOVE_BIN="love"
fi

# Определение расположения игры (папка или подпапка)
if [ -f "$GAMEDIR/main.lua" ]; then
  GAME_TARGET="$GAMEDIR"
elif [ -f "$GAMEDIR/casino/main.lua" ]; then
  GAME_TARGET="$GAMEDIR/casino"
elif [ -f "$GAMEDIR/game.love" ]; then
  GAME_TARGET="$GAMEDIR/game.love"
else
  GAME_TARGET="."
fi

$ESUDO chmod +x "$GAMEDIR/Casino.sh" 2>/dev/null
$LOVE_BIN "$GAME_TARGET"
