@echo off

cd /d "%~dp0"

for /F %%A in ('powershell.exe -Command "if ($(Get-ExecutionPolicy) -eq \"Restricted\") { echo 1 } else {echo 0}" ') do set policy=%%A
if %policy% EQU 1 (
	echo "Your computer is set to NOT allow PowerShell scripts. Please press any key to continue, you will be asked to allow administrative rights once, than a window will open and close instandly, this will allow PowerShell to run GW2start for the future. If you don't want this: close this window and delete GW2start.bat - it will not work without this change."
	pause
	powershell.exe -Command "Start-Process powershell.exe -Verb runAs -ArgumentList \"-Command Set-ExecutionPolicy RemoteSigned -Force;\""
)

powershell.exe -Command "Invoke-WebRequest https://github.com/Tinsus/GW2-updater-script/raw/main/GW2start.ps1 -OutFile GW2start.ps1"

powershell.exe -file "GW2start.ps1" "config"

del "GW2start.ps1"
