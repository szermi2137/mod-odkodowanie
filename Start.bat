@echo off
setlocal
chcp 65001 >nul
:MENU
cls
echo =============================================================
echo       MOD JAR RECOVERY TOOLKIT SMART 2.0
echo ========================================================
echo  1. Odzyskaj/dekompiluj JAR (automatycznie)
echo  2. Zbadaj JAR bez dekompilacji
echo  3. Pobierz najnowszy Yarn dla kazdej wersji 1.20.1+
echo  4. Pobierz wszystkie stabilne buildy Yarn (duzo miejsca)
echo  5. Pobierz Yarn dla jednej wersji MC
echo  6. Sprawdz narzedzia
echo  7. Otworz folder output
echo  0. Wyjscie
echo.
choice /C 12345670 /N /M "Wybierz: "
if errorlevel 8 goto END
if errorlevel 7 goto OUTPUT
if errorlevel 6 goto CHECK
if errorlevel 5 goto ONEYARN
if errorlevel 4 goto ALLYARN
if errorlevel 3 goto YARN
if errorlevel 2 goto INSPECT
if errorlevel 1 goto RECOVER
:RECOVER
call "%~dp0Recover-Mod.bat"
goto MENU
:INSPECT
call "%~dp0Inspect-Mod.bat"
goto MENU
:YARN
call "%~dp0Download-Yarn-Mappings.bat"
goto MENU
:ALLYARN
call "%~dp0Download-All-Yarn-Builds.bat"
goto MENU
:ONEYARN
call "%~dp0Fetch-Yarn-For-Version.bat"
goto MENU
:CHECK
call "%~dp0Check-Tools.bat"
goto MENU
:OUTPUT
if not exist "%~dp0output" mkdir "%~dp0output"
start "" "%~dp0output"
goto MENU
:END
endlocal
