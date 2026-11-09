@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Download-Yarn-Mappings.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Pobieranie zakończone z kodem %RC%.
pause
exit /b %RC%
