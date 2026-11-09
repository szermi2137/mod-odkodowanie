@echo off
setlocal
chcp 65001 >nul
echo To moze pobrac wiele wersji/buildow Yarn i zuzyc duzo miejsca.
choice /C TN /N /M "Kontynuowac? [T/N] "
if errorlevel 2 exit /b 0
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Download-Yarn-Mappings.ps1" -AllBuilds
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Pobieranie zakończone z kodem %RC%.
pause
exit /b %RC%
