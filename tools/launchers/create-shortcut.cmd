@echo off
setlocal
set "WX_PET_PACKAGE=%~dp0"
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $folder=$env:WX_PET_PACKAGE; $exe=Join-Path $folder 'CPPet.exe'; if (!(Test-Path -LiteralPath $exe)) { throw 'Extract the whole ZIP first.' }; $path=Join-Path ([Environment]::GetFolderPath('Desktop')) 'WangXian Desktop Pet.lnk'; $shell=New-Object -ComObject WScript.Shell; $link=$shell.CreateShortcut($path); if ((Test-Path -LiteralPath $path) -and $link.Description -ne 'WangXian Desktop Pet') { throw 'An unrelated shortcut already exists at this path.' }; $link.TargetPath=$exe; $link.WorkingDirectory=$folder; $link.IconLocation=$exe+',0'; $link.Description='WangXian Desktop Pet'; $link.Save(); Write-Host ('Created: '+$path)"
if errorlevel 1 echo Shortcut creation failed. You can still launch CPPet.exe directly.
pause
