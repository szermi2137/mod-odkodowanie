@echo off
setlocal
chcp 65001 >nul
set /p "MCVER=Podaj dokladna wersje Minecrafta, np. 1.21.4: "
if "%MCVER%"=="" exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Download-Yarn-Mappings.ps1" -GameVersion "%MCVER%"
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
