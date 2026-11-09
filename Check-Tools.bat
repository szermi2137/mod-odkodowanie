@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Check-Tools.ps1"
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
