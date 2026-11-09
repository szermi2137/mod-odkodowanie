@echo off
setlocal
chcp 65001 >nul
set "SCRIPT=%~dp0scripts\Recover-Mod.ps1"
if not "%~1"=="" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -JarPath "%~1"
) else (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo Proces zakończony kodem %RC%. Sprawdź komunikat powyżej.
pause
exit /b %RC%
