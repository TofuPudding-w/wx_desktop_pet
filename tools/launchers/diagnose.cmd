@echo off
set "PET_LOG_DIR=%LOCALAPPDATA%\WangXianPet\Stage1"
if not exist "%PET_LOG_DIR%" mkdir "%PET_LOG_DIR%"
cd /d "%~dp0"
echo Log: "%PET_LOG_DIR%\pet.log"
start "" /wait "%~dp0CPPet.exe" --log-file "%PET_LOG_DIR%\pet.log" -- --telemetry="%PET_LOG_DIR%\telemetry.json" %*
echo Send pet.log and your test checklist if a problem occurs.
pause
