cd /d "%~dp0"

rem change this to your own installtion-paths
set GW2_path="C:\Program Files\Guild Wars 2"
set TacO_path="D:\Program Files (x86)\GW2\TacO"
set BlishHUD_path="D:\Program Files (x86)\GW2\BlishHUD"

rem set it to 1 to enable the update and installation of the corresponding tools or 0 to ignore it
set use_ArcDPS=1
set use_TacO=1
set use_BHud=1
rem TODO: setting to stop enforcement of blish-hud module activation

if exist "GW2start.txt" (
	del "GW2start.ps1"
	rename "GW2start.txt" "GW2start.ps1"
)

powershell.exe -file "GW2start.ps1" '%GW2_path%' '%TacO_path%' '%BlishHUD_path%' '%use_ArcDPS%' '%use_TacO%' '%use_BHud%'