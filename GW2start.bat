cd /d "%~dp0"

if exist "GW2start.txt" (
	del "GW2start.ps1"
	rename "GW2start.txt" "GW2start.ps1"
)

powershell.exe -file "GW2start.ps1"