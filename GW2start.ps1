# you don't need to change anything here - except you know what you are doing

param($GW2_path, $TacO_path, $BlishHUD_path)

$GW2_path = $GW2_path.Substring(1, $GW2_path.Length - 2)
$TacO_path = $TacO_path.Substring(1, $TacO_path.Length - 2)
$BlishHUD_path = $BlishHUD_path.Substring(1, $BlishHUD_path.Length - 2)
$MyDocuments_path = [Environment]::GetFolderPath("MyDocuments")

$neededGithubApiCalls = 9



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
	Write-Output " "
	Write-Output " "
	Write-Output "have fun in Guild Wars 2"

	Start-Process -FilePath "$GW2_path\Gw2-64.exe" -WorkingDirectory "$GW2_path\" -ArgumentList '-autologin', '-bmp', '-mapLoadInfo' -wait -RedirectStandardError "$GW2_path\errorautocheck.txt"

	# if GW2 has an update removes ArcDPS
	if ($true -and (Test-Path "$GW2_path\errorautocheck.txt") -and ((Get-Item "$GW2_path\errorautocheck.txt").length -ne 0)) {
		Write-Output " "
		Write-Output "crash detected - removing ArcDPS"
		Write-Output " "

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

# now the non-dynamic stuff:

# clean up before anything else starts

clear

for ($i = 0; $i -lt 7; $i++) {
	Write-Output " "
}

stopprocesses



# auto update ArcDPS

$checkurl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"
$targeturl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
$checkfile = "$GW2_path\bin64\d3d9.dll"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.check" -Raw).Trim() -ne (Get-Content "$checkfile.md5" -Raw).Trim())
) {
	Write-Output "ArcDPS is being updated"

	# direct install
	removefile "$checkfile"
	Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

	# remember this version
	removefile "$checkfile.md5"
	Rename-Item "$checkfile.check" -NewName "$checkfile.md5"
}

removefile "$checkfile.check"
Write-Output "ArcDPS is up-to-date"



# check githubs API restrictions and waits until it's possible again

$older = $false

if (Test-Path "$GW2_path\github.json") {
	$older = $true

	removefile "$GW2_path\github.json"
}

Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$GW2_path\github.json"
$json = (Get-Content "$GW2_path\github.json" -Raw) | ConvertFrom-Json

if ($json.rate.remaining -lt $neededGithubApiCalls) {
	if (-not $older) {
		$date = (Get-Date -Date "1970-01-01 00:00:00Z").toLocalTime().addSeconds($json.rate.reset)

		Write-Output " "
		Write-Output " "
		Write-Output " "
		Write-Output "No more updates possible due to API limitations by github.com :("
		Write-Output " "
		Write-Output "The restrictions will be lifted on:"
		Write-Output $date
		Write-Output " "
		Write-Output "Sorry for that."
		Write-Output " "
		Write-Output " "
		Write-Output "This script will wait until updates are possible. Of cause you can close this window everytime. The updates will be done the next time."
		Write-Output " "
	}

	startGW2
	stopprocesses

	if ($older) {
		exit
	}

	Write-Output " "
	Write-Output "OK - we will wait until the updates are possible again. You can close this window everytime. No data will be damaged or deleted."
	Write-Output " "

	do {
		Start-Sleep -Seconds 60

		Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$GW2_path\github.json"
		$json = (Get-Content "$GW2_path\github.json" -Raw) | ConvertFrom-Json
	} until ($json.rate.remaining -ge $neededGithubApiCalls)
}

removefile "$GW2_path\github.json"


# auto update TacO

newdir "$TacO_path"

$checkurl = "https://api.github.com/repos/BoyC/GW2TacO/releases/latest"
$checkfile = "$TacO_path\tacoautoupdate"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Output "TacO is being updated"

	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

	Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$TacO_path\" -Force
	removefile "$checkfile.temp.zip"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.node_id
}

removefile "$checkfile.check"
Write-Output "TacO is up-to-date"


# auto update arcdps-killproof.me-plugin

$checkurl = "https://api.github.com/repos/knoxfighter/arcdps-killproof.me-plugin/releases/latest"
$checkfile = "$GW2_path\bin64\d3d9_arcdps_killproof_me.dll"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.name)
) {
	Write-Output "ArcDps-killproof.me-plugin is being updated"

	removefile "$checkfile"
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.name
}

removefile "$checkfile.check"
Write-Output "ArcDps-killproof.me-plugin is up-to-date"



# auto update BlishHUD

newdir "$BlishHUD_path"
newdir "$MyDocuments_path\Guild Wars 2"
newdir "$MyDocuments_path\Guild Wars 2\addons"
newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud"
newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\markers"
newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

$checkurl = "https://api.github.com/repos/blish-hud/Blish-HUD/releases/latest"
$checkfile = "$BlishHUD_path\blishhudautoupdate"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Output "BlishHUD is being updated"
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

	Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$BlishHUD_path\" -Force
	removefile "$checkfile.temp.zip"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.node_id
}

removefile "$checkfile.check"
Write-Output "BlishHUD is up-to-date"



# auto update BlishHUD-ArcDPS Bridge

$checkurl = "https://api.github.com/repos/blish-hud/arcdps-bhud/releases/latest"
$checkfile = "$GW2_path\bin64\arcdps_bhud"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Output "BlishHUD-ArcDPS Bridge is being updated"
	Invoke-WebRequest $json.assets.browser_download_url[1] -OutFile "$checkfile.zip"

	Expand-Archive -Path "$checkfile.zip" -DestinationPath "$GW2_path\bin64\" -Force
	removefile "$checkfile.zip"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $json.node_id
}

removefile "$checkfile.check"
Write-Output "BlishHUD-ArcDPS Bridge is up-to-date"



# auto update BlishHUD-Modules



# Pathing

$checkurl = "https://api.github.com/repos/blish-hud/Pathing/releases/latest"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\pathing"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
$new = $($json.tag_name).Substring(1)

$old = 0

if (Test-Path "$checkfile.md5") {
	$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
}

if ($new -ne $old) {
	Write-Output "BlishHUD-Module Pathing is being updated"

	# remove old version
	removefile "$checkpath\bh.community.pathing_$old.bhm"
	removefile "$checkpath\Pathing_v$old.bhm"

	#  get new version
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\bh.community.pathing_$new.bhm"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $new
}

removefile "$checkfile.check"
Write-Output "BlishHUD-Module Pathing is up-to-date"



# KillProof-Module

$checkurl = "https://api.github.com/repos/blish-hud/KillProof-Module/releases/latest"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\KillProof.bhm"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
$new = $($json.tag_name).Substring(1)

$old = 0

if (Test-Path "$checkfile.md5") {
	$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
}

if ($new -ne $old) {
	Write-Output "BlishHUD-Module KillProof is being updated"

	# remove old version
	removefile "$checkfile"

	#  get new version
	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $new
}

removefile "$checkfile.check"
Write-Output "BlishHUD-Module KillProof is up-to-date"



# Quick-Surrender

$checkurl = "https://api.github.com/repos/agaertner/Blish-HUD-Modules-Releases/releases/latest"
$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
$checkfile = "$checkpath\QuickSurrender"

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
	Write-Output "BlishHUD-Module Quick-Surrende is being updated"

	# remove old version
	removefile "$checkpath\Nekres.Quick_Surrender_Module_$old.bhm"
	removefile "$checkpath\$name"

	#  get new version
	Invoke-WebRequest $targeturl -OutFile "$checkpath\Nekres.Quick_Surrender_Module_$ver.bhm"

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $new
}

removefile "$checkfile.check"
Write-Output "BlishHUD-Module Quick-Surrende is up-to-date"



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
	Write-Output "TEKKIT is being updated"
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
}

removefile "$path_t.check"

Write-Output "TEKKIT is up-to-date"



# auto update SCHATTENFLUEGEL

$checkurl = "https://api.github.com/repos/Schattenfluegel/SchattenfluegelTrails/contents/Download"
$targeturl = "https://github.com/Schattenfluegel/SchattenfluegelTrails/raw/main/Download/SchattenfluegelTrails.taco"
$checkfile = "SchattenfluegelTrails.taco"

$path_t = path_t $checkfile
$path_b = path_b $checkfile

Invoke-WebRequest "$checkurl" -OutFile "$path_t.check"

if (
	-not (Test-Path "$path_t") -or
	-not (Test-Path "$path_b") -or
	$(Get-FileHash "$path_t.check").Hash -ne $(Get-FileHash "$path_t.md5").Hash -or
	$(Get-FileHash "$path_t.check").Hash -ne $(Get-FileHash "$path_b.md5").Hash
) {
	Write-Output "SCHATTENFLUEGEL is being updated"

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
}

removefile "$TacO_path\POIs\SchattenfluegelTrails.check"
Write-Output "SCHATTENFLUEGEL is up-to-date"



# auto update HEROMARKERS

$checkurl = "https://api.github.com/repos/QuitarHero/Heros-Marker-Pack/releases/latest"
$checkfile = "Hero.Blish.Pack.zip"

$path_b = path_b $checkfile

Invoke-WebRequest "$checkurl" -OutFile "$path_b.check"
$json = (Get-Content "$path_b.check" -Raw) | ConvertFrom-Json

if (
	-not (Test-Path "$path_b.md5") -or
	((Get-Content "$path_b.md5" -Raw).Trim() -ne $json.node_id)
) {
	Write-Output "HEROMARKERS is being updated"

	# update for BlishHUD (no TacO support)
	removefile "$path_b"

	Invoke-WebRequest $json.assets.browser_download_url -OutFile "$path_b"

	# remember this version
	Set-Content -Path "$path_b.md5" -Value $json.node_id
}

removefile "$path_b.check"
Write-Output "HEROMARKERS is up-to-date"



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
	Write-Output "CZOKALAPIK is being updated"

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
}

removefile "$path_t.check"
Write-Output "CZOKALAPIK is up-to-date"



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
	Write-Output "REACTIF is being updated"

	# update for TacO
	removefile "$path_t"
	Invoke-WebRequest "$targeturl" -OutFile "$path_t"

	# update for BlishHUD
	removefile "$path_b"
	Copy-Item "$path_t" -Destination "$path_b"

	# remember this version
	Set-Content -Path "$path_t.md5" -Value $ver
	Copy-Item "$path_t.md5" -Destination "$path_b.md5"
}

Write-Output "REACTIF is up-to-date"



# done with updating

if (-not $older) {
	startGW2
	stopprocesses
}

Write-Output " "
Write-Output "see you soon"

Start-Sleep -Seconds 2
