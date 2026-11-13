@echo off
setlocal
cd /d "%~dp0"

if exist "%~dp0dist\SlotGame_Windows_x64\SlotGame.exe" (
    start "" "%~dp0dist\SlotGame_Windows_x64\SlotGame.exe"
    exit /b 0
)

if exist "C:\Program Files\LOVE\love.exe" (
    start "" "C:\Program Files\LOVE\love.exe" "%~dp0casino"
    exit /b 0
)

if exist "C:\Program Files (x86)\LOVE\love.exe" (
    start "" "C:\Program Files (x86)\LOVE\love.exe" "%~dp0casino"
    exit /b 0
)

where love >nul 2>nul
if %errorlevel% equ 0 (
    start "" love "%~dp0casino"
    exit /b 0
)

echo ERROR: LOVE2D not found. Please install Love2D (https://love2d.org) or ensure dist\SlotGame_Windows_x64\SlotGame.exe exists.
pause
