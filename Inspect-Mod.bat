@echo off
setlocal
chcp 65001 >nul
if not "%~1"=="" goto ARGUMENT
set /p "JARPATH=Podaj sciezke do JAR-a: "
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Check-Archive.ps1" -JarPath "%JARPATH%"
goto DONE
:ARGUMENT
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Check-Archive.ps1" -JarPath "%~1"
:DONE
echo.
pause
