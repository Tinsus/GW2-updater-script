# you don't need to change anything here - except you know what you are doing

param($GW2_path, $TacO_path, $BlishHUD_path, $use_ArcDPS, $use_TacO, $use_BHud)

$GW2_path = $GW2_path.Substring(1, $GW2_path.Length - 2)
$TacO_path = $TacO_path.Substring(1, $TacO_path.Length - 2)
$BlishHUD_path = $BlishHUD_path.Substring(1, $BlishHUD_path.Length - 2)
$MyDocuments_path = [Environment]::GetFolderPath("MyDocuments")
$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$Version_path ="$Script_path\version_control"

$use_ArcDPS = ($use_ArcDPS.Substring(1, $use_ArcDPS.Length - 2)) -ne 0
$use_TacO = ($use_TacO.Substring(1, $use_TacO.Length - 2)) -ne 0
$use_BHud = ($use_BHud.Substring(1, $use_BHud.Length - 2)) -ne 0

# some functions for lazy people

function stopprocesses() {
	Stop-Process -Name "GW2TacO" -ErrorAction SilentlyContinue
	Stop-Process -Name "Blish HUD" -ErrorAction SilentlyContinue
	Stop-Process -Name "Gw2-64" -ErrorAction SilentlyContinue
}

function removefile($path) {
	if (Test-Path "$path") {
		Remove-Item "$path"
	}
}

function newdir($path) {
	if (-not (Test-Path "$path")) {
		New-Item "$path" -ItemType Directory
	}
}

function startGW2() {
	# start TacO
	Start-Process -FilePath "$TacO_path\GW2TacO.exe" -WorkingDirectory "$TacO_path\" -ErrorAction SilentlyContinue

	# start BlishHUD
	Start-Process -FilePath "$BlishHUD_path\Blish HUD.exe" -WorkingDirectory "$BlishHUD_path\" -ErrorAction SilentlyContinue

	# start Guild Wars 2
	Write-Host " "
	Write-Host " "
	Write-Host "have fun in Guild Wars 2"

	Start-Process -FilePath "$GW2_path\Gw2-64.exe" -WorkingDirectory "$GW2_path\" -ArgumentList '-autologin', '-bmp', '-mapLoadInfo' -wait -RedirectStandardError "$GW2_path\errorautocheck.txt"

	# if GW2 has an update removes ArcDPS
	if ($true -and (Test-Path "$GW2_path\errorautocheck.txt") -and ((Get-Item "$GW2_path\errorautocheck.txt").length -ne 0)) {
		Write-Host " "
		Write-Host "crash detected - removing ArcDPS" -ForegroundColor Red
		Write-Host " "

		# UNTESTED (need update/crash to test this)
		$gw2error = Get-Content -Path "$GW2_path\errorautocheck.txt"

		removefile "$GW2_path\errorautocheck.txt"

		if ($gw2error -ne 0) {
			removefile "$GW2_path\bin64\d3d9.dll"

			startGW2
		}
	} else {
		removefile "$GW2_path\errorautocheck.txt"
	}
}

function path_t($tag) {
	return "$TacO_path\POIs\$tag"
}

function path_b($tag) {
	return "$MyDocuments_path\Guild Wars 2\addons\blishhud\markers\$tag"
}

function nls($total) {
	for ($i = 0; $i -lt $total; $i++) {
		Write-Host " "
	}
}

function checkGithub() {
	# check githubs API restrictions and waits until it's possible again

	Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$GW2_path\github.json"
	$json = (Get-Content "$GW2_path\github.json" -Raw) | ConvertFrom-Json

	if ($json.rate.remaining -lt 1) {
		if (-not $older) {
			$date = (Get-Date -Date "1970-01-01 00:00:00Z").toLocalTime().addSeconds($json.rate.reset)

			nls 3
			Write-Host "No more updates possible due to API limitations by github.com :(" -ForegroundColor Red
			nls 1
			Write-Host "The restrictions will be lifted on:"
			Write-Host $date -ForegroundColor Yellow
			nls 1
			Write-Host "Sorry for that."
			nls 2
			Write-Host "This script will wait until updates are possible again. Of cause you can close this window everytime. The updates will be done the next you start this script."
			nls 1
		}

		startGW2
		stopprocesses

		if ($older) {
			exit
		}

		nls 1
		Write-Host "OK - we will wait until the updates are possible again. You can close this window everytime. No data will be damaged or deleted." -ForegroundColor Yellow
		nls 1

		do {
			Start-Sleep -Seconds 60

			Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$GW2_path\github.json"
			$json = (Get-Content "$GW2_path\github.json" -Raw) | ConvertFrom-Json
		} until ($json.rate.remaining -ge 1)
	}

	removefile "$GW2_path\github.json"
}

# now the non-dynamic stuff:

# clean up before anything else starts

Clear-Host

nls 7

stopprocesses

newdir "$Script_path"


# auto update this script itself

# prepare the update to be done by the .bat file with the next start

Invoke-WebRequest "https://github.com/Tinsus/GW2-updater-script/raw/main/GW2start.ps1" -OutFile "$Script_path/GW2start.txt"

Write-Host "GW2start.ps1 is updated every time"


# auto update ArcDPS

$checkurl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"
$targeturl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
$checkfile = "$GW2_path\bin64\d3d9.dll"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.check" -Raw).Trim() -ne (Get-Content "$checkfile.md5" -Raw).Trim())
) {
	Write-Host "ArcDPS is being updated" -ForegroundColor Green

	# direct install
	removefile "$checkfile"
	Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

	# remember this version
	removefile "$checkfile.md5"
	Rename-Item "$checkfile.check" -NewName "$checkfile.md5"
} else {
	Write-Host "ArcDPS is up-to-date"
}

removefile "$checkfile.check"


# check githubs API restrictions and waits until it's possible again

$older = $false

if (Test-Path "$GW2_path\github.json") {
	$older = $true

	removefile "$GW2_path\github.json"
}

# auto update TacO

newdir "$TacO_path"

$checkurl = "https://api.github.com/repos/BoyC/GW2TacO/releases/latest"
$checkfile = "$TacO_path\tacoautoupdate"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Host "TacO is being updated" -ForegroundColor Green

	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

	Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$TacO_path\" -Force
	removefile "$checkfile.temp.zip"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.node_id
} else {
	Write-Host "TacO is up-to-date"
}

removefile "$checkfile.check"


# auto update arcdps-killproof.me-plugin

$checkurl = "https://api.github.com/repos/knoxfighter/arcdps-killproof.me-plugin/releases/latest"
$checkfile = "$GW2_path\bin64\d3d9_arcdps_killproof_me.dll"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.name)
) {
	Write-Host "ArcDps-killproof.me-plugin is being updated" -ForegroundColor Green

	removefile "$checkfile"
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.name
} else {
	Write-Host "ArcDps-killproof.me-plugin is up-to-date"
}

removefile "$checkfile.check"


# auto update arcdps-Boon-Table-plugin

$checkurl = "https://api.github.com/repos/knoxfighter/GW2-ArcDPS-Boon-Table/releases/latest"
$checkfile = "$GW2_path\bin64\d3d9_arcdps_table.dll"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.name)
) {
	Write-Host "GW2-ArcDps-Boon-Table is being updated" -ForegroundColor Green

	removefile "$checkfile"
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.name
} else {
	Write-Host "GW2-ArcDps-Boon-Table is up-to-date"
}

removefile "$checkfile.check"


# auto update BlishHUD

newdir "$BlishHUD_path"
newdir "$MyDocuments_path\Guild Wars 2"
newdir "$MyDocuments_path\Guild Wars 2\addons"
newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud"
newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\markers"
newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

$checkurl = "https://api.github.com/repos/blish-hud/Blish-HUD/releases/latest"
$checkfile = "$BlishHUD_path\blishhudautoupdate"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Host "BlishHUD is being updated" -ForegroundColor Green

	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

	Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$BlishHUD_path\" -Force
	removefile "$checkfile.temp.zip"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.node_id
} else {
	Write-Host "BlishHUD is up-to-date"
}

removefile "$checkfile.check"


# auto update BlishHUD-ArcDPS Bridge

$checkurl = "https://api.github.com/repos/blish-hud/arcdps-bhud/releases/latest"
$checkfile = "$GW2_path\bin64\arcdps_bhud"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Host "BlishHUD-ArcDPS Bridge is being updated" -ForegroundColor Green
	Invoke-WebRequest $json.assets.browser_download_url[1] -OutFile "$checkfile.zip"

	Expand-Archive -Path "$checkfile.zip" -DestinationPath "$GW2_path\bin64\" -Force
	removefile "$checkfile.zip"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.node_id
} else {
	Write-Host "BlishHUD-ArcDPS Bridge is up-to-date"
}

removefile "$checkfile.check"


# auto update BlishHUD-Modules


# Pathing

$checkurl = "https://api.github.com/repos/blish-hud/Pathing/releases/latest"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\pathing"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
$new = $($json.tag_name).Substring(1)

$old = 0

if (Test-Path "$checkfile.md5") {
	$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
}

if ($new -ne $old) {
	Write-Host "BlishHUD-Module Pathing is being updated" -ForegroundColor Green

	# remove old version
	removefile "$checkpath\bh.community.pathing_$old.bhm"
	removefile "$checkpath\Pathing_v$old.bhm"

	#  get new version
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\bh.community.pathing_$new.bhm"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $new
} else {
	Write-Host "BlishHUD-Module Pathing is up-to-date"
}

removefile "$checkfile.check"


# KillProof-Module

$checkurl = "https://api.github.com/repos/blish-hud/KillProof-Module/releases/latest"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\KillProof.bhm"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
$new = $($json.tag_name).Substring(1)

$old = 0

if (Test-Path "$checkfile.md5") {
	$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
}

if ($new -ne $old) {
	Write-Host "BlishHUD-Module KillProof is being updated" -ForegroundColor Green

	# remove old version
	removefile "$checkfile"

	#  get new version
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $new
} else {
	Write-Host "BlishHUD-Module KillProof is up-to-date"
}

removefile "$checkfile.check"


# Quick-Surrender

$checkurl = "https://api.github.com/repos/agaertner/Blish-HUD-Modules-Releases/releases/latest"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\QuickSurrender"

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
$new = $($json.tag_name).Substring(1)

$old = 0

if (Test-Path "$checkfile.md5") {
	$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
}

$targeturl = ""

$json.assets | foreach-object {
	if ($_.name -match "Surrender") {
		$targeturl = $_
	}
}

$new = $($targeturl.name)
$new = $new.Substring($new.Length - 9, 5)
$name = $targeturl.name
$targeturl = $targeturl.browser_download_url

if ($new -ne $old) {
	Write-Host "BlishHUD-Module Quick-Surrende is being updated" -ForegroundColor Green

	# remove old version
	removefile "$checkpath\Nekres.Quick_Surrender_Module_$old.bhm"
	removefile "$checkpath\$name"

	#  get new version
	Invoke-WebRequest $targeturl -OutFile "$checkpath\Nekres.Quick_Surrender_Module_$ver.bhm"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $new
} else {
	Write-Host "BlishHUD-Module Quick-Surrende is up-to-date"
}

removefile "$checkfile.check"


# auto update TEKKIT

$checkurl = "http://tekkitsworkshop.net/index.php/gw2-taco/changelog"
$targeturl = "http://tekkitsworkshop.net/index.php/component/jdownloads/send/2-taco-marker-packs/32-all-in-one"
$checkfile = "tw_ALL_IN_ONE.taco"

$path_t = path_t $checkfile
$path_b = path_b $checkfile

Invoke-WebRequest "$checkurl" -OutFile "$path_t.check"

if (
	-not (Test-Path "$path_t.md5") -or
	-not (Test-Path "$path_b.md5") -or
	(Compare-Object -ReferenceObject $(Get-Content "$path_t.check") -DifferenceObject $(Get-Content "$path_t.md5")) -or
	(Compare-Object -ReferenceObject $(Get-Content "$path_t.check") -DifferenceObject $(Get-Content "$path_b.md5"))
) {
	Write-Host "TEKKIT is being updated" -ForegroundColor Green
	# update for TacO
	removefile "$path_t"
	Invoke-WebRequest "$targeturl" -OutFile "$path_t"

	# update for BlishHUD
	removefile "$path_b"
	Copy-Item "$path_t" -Destination "$path_b"

	# remember this version
	removefile "$path_t.md5"
	removefile "$path_b.md5"
	Rename-Item "$path_t.check" -NewName "$path_t.md5"
	Copy-Item "$path_t.md5" -Destination "$path_b.md5"
} else {
	Write-Host "TEKKIT is up-to-date"
}

removefile "$path_t.check"


# auto update SCHATTENFLUEGEL

$checkurl = "https://api.github.com/repos/Schattenfluegel/SchattenfluegelTrails/contents/Download"
$targeturl = "https://github.com/Schattenfluegel/SchattenfluegelTrails/raw/main/Download/SchattenfluegelTrails.taco"
$checkfile = "SchattenfluegelTrails.taco"

$path_t = path_t $checkfile
$path_b = path_b $checkfile

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$path_t.check"

if (
	-not (Test-Path "$path_t") -or
	-not (Test-Path "$path_b") -or
	$(Get-FileHash "$path_t.check").Hash -ne $(Get-FileHash "$path_t.md5").Hash -or
	$(Get-FileHash "$path_t.check").Hash -ne $(Get-FileHash "$path_b.md5").Hash
) {
	Write-Host "SCHATTENFLUEGEL is being updated" -ForegroundColor Green

	# update for TacO
	removefile "$path_t"
	Invoke-WebRequest "$targeturl" -OutFile "$path_t"

	# update for BlishHUD
	removefile "$path_b"
	Copy-Item "$path_t" -Destination "$path_b"

	# remember this version
	removefile "$path_t.md5"
	removefile "$path_b.md5"
	Rename-Item "$path_t.check" -NewName "$path_t.md5"
	Copy-Item "$path_t.md5" -Destination "$path_b.md5"
} else {
	Write-Host "SCHATTENFLUEGEL is up-to-date"
}

removefile "$path_t.check"


# auto update HEROMARKERS

$checkurl = "https://api.github.com/repos/QuitarHero/Heros-Marker-Pack/releases/latest"
$checkfile = "Hero.Blish.Pack.zip"

$path_b = path_b $checkfile

checkGithub
Invoke-WebRequest "$checkurl" -OutFile "$path_b.check"
$json = (Get-Content "$path_b.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$path_b.md5") -or
	((Get-Content "$path_b.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Host "HEROMARKERS is being updated" -ForegroundColor Green

	# update for BlishHUD (no TacO support)
	removefile "$path_b"

	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$path_b"

	# remember this version
	Set-Content -Path "$path_b.md5" -Value $json.node_id
} else {
	Write-Host "HEROMARKERS is up-to-date"
}

removefile "$path_b.check"


# auto update CZOKALAPIK

$checkurl = "https://api.bitbucket.org/2.0/repositories/czokalapik/czokalapiks-guides-for-gw2taco/commits"
$targeturl = "https://bitbucket.org/czokalapik/czokalapiks-guides-for-gw2taco/get"
$checkfile = "czokalapiks-guides.taco"

$path_t = path_t $checkfile
$path_b = path_b $checkfile

Invoke-WebRequest "$checkurl" -OutFile "$path_t.check"
$json = (Get-Content "$path_t.check" -Raw) | ConvertFrom-Json

$hash = $($json.values[0].hash).Substring(0, 12)

if (
	-not (Test-Path "$path_t.md5") -or
	-not (Test-Path "$path_b.md5") -or
	((Get-Content "$path_t.md5" -Raw).Trim() -ne $json.values[0].hash) -or
	((Get-Content "$path_b.md5" -Raw).Trim() -ne $json.values[0].hash)
) {
	Write-Host "CZOKALAPIK is being updated" -ForegroundColor Green

	# update for TacO
	removefile "$path_t"
	Invoke-WebRequest "$targeturl/$hash.zip" -OutFile "$path_t.zip"

	Expand-Archive -Path "$path_t.zip" -DestinationPath "$TacO_path\POIs\" -Force
	removefile "$path_t.zip"

	Compress-Archive -Path "$TacO_path\POIs\czokalapik-czokalapiks-guides-for-gw2taco-$hash\POIs\*" -DestinationPath "$path_t.zip"
	Remove-Item "$TacO_path\POIs\czokalapik-czokalapiks-guides-for-gw2taco-$hash" -Recurse -force
	Rename-Item -Path "$path_t.zip" -NewName "$path_t"


	# update for BlishHUD
	removefile "$path_b"
	Copy-Item "$path_t" -Destination "$path_b"

	# remember this version
	Set-Content -Path "$path_t.md5" -Value $json.values[0].hash
	Copy-Item "$path_t.md5" -Destination "$path_b.md5"
} else {
	Write-Host "CZOKALAPIK is up-to-date"
}

removefile "$path_t.check"


# auto update REACTIF

$ver = Select-Xml -Content ((Invoke-WebRequest "https://heinze.fr/taco/rss-en.xml").Content) -XPath "//item/pubDate" | Select-Object -First 1 | foreach-object { $_.node.InnerXML }
$targeturl = "https://www.heinze.fr/taco/download.php?f=3"
$checkfile = "reactif_en.taco"

$path_t = path_t $checkfile
$path_b = path_b $checkfile

if (
	-not (Test-Path "$path_t.md5") -or
	-not (Test-Path "$path_b.md5") -or
	((Get-Content "$path_t.md5" -Raw).Trim() -ne $ver) -or
	((Get-Content "$path_b.md5" -Raw).Trim() -ne $ver)
) {
	Write-Host "REACTIF is being updated" -ForegroundColor Green

	# update for TacO
	removefile "$path_t"
	Invoke-WebRequest "$targeturl" -OutFile "$path_t"

	# update for BlishHUD
	removefile "$path_b"
	Copy-Item "$path_t" -Destination "$path_b"

	# remember this version
	Set-Content -Path "$path_t.md5" -Value $ver
	Copy-Item "$path_t.md5" -Destination "$path_b.md5"
} else {
	Write-Host "REACTIF is up-to-date"
}


# cleanup for older version of this script

removefile "$Script_path/GW2start.txt"
removefile "$Script_path/GW2start.txt.md5"
removefile "$Script_path/LICENSE"
removefile "$Script_path/README.md"

$checkfile = "$GW2_path\bin64\d3d9.dll"
removefile "$checkfile.md5"
$checkfile = "$TacO_path\tacoautoupdate"
removefile "$checkfile.md5"
$checkfile = "$GW2_path\bin64\d3d9_arcdps_killproof_me.dll"
removefile "$checkfile.md5"
$checkfile = "$GW2_path\bin64\d3d9_arcdps_table.dll"
removefile "$checkfile.md5"
$checkfile = "$BlishHUD_path\blishhudautoupdate"
removefile "$checkfile.md5"
$checkfile = "$GW2_path\bin64\arcdps_bhud"
removefile "$checkfile.md5"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\pathing"
removefile "$checkfile.md5"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\KillProof.bhm"
removefile "$checkfile.md5"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\QuickSurrender"
removefile "$checkfile.md5"
$checkfile = "tw_ALL_IN_ONE.taco"
$path_t = path_t $checkfile
$path_b = path_b $checkfile
removefile "$path_t.md5"
removefile "$path_b.md5"
$checkfile = "SchattenfluegelTrails.taco"
$path_t = path_t $checkfile
$path_b = path_b $checkfile
removefile "$path_t.md5"
removefile "$path_b.md5"
$checkfile = "Hero.Blish.Pack.zip"
$path_b = path_b $checkfile
removefile "$path_b.md5"
$checkfile = "czokalapiks-guides.taco"
$path_t = path_t $checkfile
$path_b = path_b $checkfile
removefile "$path_t.md5"
removefile "$path_b.md5"
$checkfile = "reactif_en.taco"
$path_t = path_t $checkfile
$path_b = path_b $checkfile
removefile "$path_t.md5"
removefile "$path_b.md5"


# done with updating

if (-not $older) {
	startGW2
	stopprocesses
}

nls 1
Write-Host "see you soon"

Start-Sleep -Seconds 2
