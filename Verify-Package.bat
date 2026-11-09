@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Verify-Package.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Kontrola wykryla problem. Nie uzywaj brakujacych lub zmienionych narzedzi.
pause
exit /b %RC%
