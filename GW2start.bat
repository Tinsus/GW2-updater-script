cd /d "%~dp0"

set GW2_path="C:\Program Files\Guild Wars 2"
set TacO_path="D:\Program Files (x86)\GW2\TacO"
set BlishHUD_path="D:\Program Files (x86)\GW2\BlishHUD"

powershell.exe -file "GW2start.ps1" '%GW2_path%' '%TacO_path%' '%BlishHUD_path%'