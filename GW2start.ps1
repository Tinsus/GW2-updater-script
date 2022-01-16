# you really really don't need to change anything here - except you know exactly what you are doing


#some magic stuff for pathes and options

param($GW2_path, $TacO_path, $BlishHUD_path, $use_ArcDPS, $use_TacO, $use_BHud)

$GW2_path = $GW2_path.Substring(1, $GW2_path.Length - 2)
$TacO_path = $TacO_path.Substring(1, $TacO_path.Length - 2)
$BlishHUD_path = $BlishHUD_path.Substring(1, $BlishHUD_path.Length - 2)
$MyDocuments_path = [Environment]::GetFolderPath("MyDocuments")
$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$Version_path = "$Script_path\version_control"

$use_ArcDPS = ($use_ArcDPS.Substring(1, $use_ArcDPS.Length - 2)) -ne 0
$use_TacO = ($use_TacO.Substring(1, $use_TacO.Length - 2)) -ne 0
$use_BHud = ($use_BHud.Substring(1, $use_BHud.Length - 2)) -ne 0


# some functions for lazy people

function stopprocesses() {
	if ($use_TacO) {
		Stop-Process -Name "GW2TacO" -ErrorAction SilentlyContinue
	}

	if ($use_BHud) {
		Stop-Process -Name "Blish HUD" -ErrorAction SilentlyContinue
	}

	if ($use_ArcDPS) {
		Stop-Process -Name "RazerCortex" -ErrorAction SilentlyContinue
	}

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
	if ($use_TacO) {
		Start-Process -FilePath "$TacO_path\GW2TacO.exe" -WorkingDirectory "$TacO_path\" -ErrorAction SilentlyContinue
	}

	# start BlishHUD
	if ($use_BHud) {
		Start-Process -FilePath "$BlishHUD_path\Blish HUD.exe" -WorkingDirectory "$BlishHUD_path\" -ErrorAction SilentlyContinue
	}

	# start Guild Wars 2
	nls 2
	Write-Host "have fun in Guild Wars 2"

	Start-Process -FilePath "$GW2_path\Gw2-64.exe" -WorkingDirectory "$GW2_path\" -ArgumentList '-autologin', '-bmp', '-mapLoadInfo' -wait -RedirectStandardError "$GW2_path\errorautocheck.txt"

	# if GW2 has an update removes ArcDPS
	if ($use_ArcDPS -and (Test-Path "$GW2_path\errorautocheck.txt") -and ((Get-Item "$GW2_path\errorautocheck.txt").length -ne 0)) {
		nls 1
		Write-Host "crash detected - removing ArcDPS" -ForegroundColor Red
		nls 1

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

	removefile "$Version_path\github.json"
	Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Version_path\github.json"

	$json = (Get-Content "$Version_path\github.json" -Raw) | ConvertFrom-Json

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

			removefile "$Version_path\github.json"
			Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Version_path\github.json"

			$json = (Get-Content "$Version_path\github.json" -Raw) | ConvertFrom-Json
		} until ($json.rate.remaining -ge 1)
	}
}

function Get-IniContent($filePath) {
    $ini = @{}

    Switch -regex -file $FilePath {
		# Section
        "^\[(.+)\]" {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
		# Comment
        "^(;.*)$" {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = "Comment" + $CommentCount
            $ini[$section][$name] = $value
        }
		# Key
        "(.+?)\s*=(.*)" {
            $name, $value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }

    return $ini
}

function Out-IniFile($InputObject, $FilePath) {
    $outFile = New-Item -ItemType file -Path $Filepath
    foreach ($i in $InputObject.keys) {
        if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")) {
            #No Sections
            Add-Content -Path $outFile -Value "$i=$($InputObject[$i])"
        } else {
            #Sections
            Add-Content -Path $outFile -Value "[$i]"

            Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                if ($j -match "^Comment[\d]+") {
                    Add-Content -Path $outFile -Value "$($InputObject[$i][$j])"
                } else {
                    Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])"
                }
            }

            Add-Content -Path $outFile -Value ""
        }
    }
}

function enforceBHM($modulename) {
	$data = Get-Content "$MyDocuments_path\Guild Wars 2\addons\blishhud\settings.json" -Raw | ConvertFrom-Json

	$i = 0

	$data.Entries | foreach {
		if ($_.Key -eq "ModuleConfiguration") {
			if (-not $data.Entries[$i].Value.Entries.Value[0]."$modulename") {
				Add-Member -InputObject $data.Entries[$i].Value.Entries.Value[0] -NotePropertyName "$modulename"  -NotePropertyValue @{
					"Enabled" = $true
					"UserEnabledPermissions" = $null
					"IgnoreDependencies" = $false
					"Settings" = $null
				}
			} else {
				$data.Entries[$i].Value.Entries.Value[0]."$modulename".Enabled = $true
			}

			<#
			if (-not $data.Entries[$i].Value.Entries.Value[0]."bh.general.events") {
				Add-Member -InputObject $data.Entries[$i].Value.Entries.Value[0] -NotePropertyName "bh.general.events"  -NotePropertyValue @{
					"Enabled" = $true
					"UserEnabledPermissions" = $null
					"IgnoreDependencies" = $false
					"Settings" = $null
				}
			} else {
				$data.Entries[$i].Value.Entries.Value[0]."bh.general.events".Enabled = $true
			}
			#>
		}

		$i++
	}

	$data | ConvertTo-Json -Depth 100 | Out-File "$MyDocuments_path\Guild Wars 2\addons\blishhud\settings.json"

	((Get-Content -path "$MyDocuments_path\Guild Wars 2\addons\blishhud\settings.json" -Raw).Replace("\u0027","'").Replace('   ', ' ').Replace('  ', ' ').Replace(":  ", ": ")) | Set-Content -Path "$MyDocuments_path\Guild Wars 2\addons\blishhud\settings.json"
}

# now the real magic:

# clean up before anything else starts

Clear-Host

nls 7

stopprocesses

newdir "$Version_path"


# some information for our user (yes, I'm talking about YOU, you creepy coder)

$older = $false

if (Test-Path "$Script_path\github.json") {
	$older = $true
} else {
	Write-Host "You set the following options. " -ForegroundColor White -NoNewline
	Write-Host "If you need change it there $Script_path\GW2start.bat" -ForegroundColor DarkGray
	nls 1

	Write-Host "Guildwars 2 " -NoNewline -ForegroundColor White
	Write-Host "is installed in " -NoNewline
	Write-Host $GW2_path -ForegroundColor DarkGray
	nls 1

	Write-Host "ArcDPS " -ForegroundColor White -NoNewline
	Write-Host "is " -NoNewline
	if ($use_ArcDPS) {
		Write-Host "enabled " -ForegroundColor Green -NoNewline
		Write-Host "it will get installed and updated."
		Write-Host "If you have any trouble with the game crashing: disable ArcDPS-updating in the .bat-file and delete the ArcDPS-specific files in your \GW2\bin64-folder." -ForegroundColor DarkGray
	} else {
		Write-Host "disabled " -ForegroundColor Red -NoNewline
		Write-Host " it will not get installed, updated or deleted. Just ignored. I'm good with ignoring." -ForegroundColor DarkGray
	}
	nls 1

	Write-Host "BlishHUD " -NoNewline -ForegroundColor White
	Write-Host "is " -NoNewline
	if ($use_BHud) {
		Write-Host "enabled " -ForegroundColor Green -NoNewline
		Write-Host "it will get installed and updated in " -NoNewline
		Write-Host $BlishHUD_path -ForegroundColor DarkGray
	} else {
		Write-Host "disabled " -ForegroundColor Red -NoNewline
		Write-Host "it will not get installed, updated or deleted. Just ignored. I'm quite good with ignoring."
	}
	nls 1

	Write-Host "TacO " -NoNewline -ForegroundColor White
	Write-Host "is " -NoNewline
	if ($use_TacO) {
		Write-Host "enabled " -ForegroundColor Green -NoNewline
		Write-Host "it will get installed and updated in " -NoNewline
		Write-Host $TacO_path -ForegroundColor DarkGray
	} else {
		Write-Host "disabled " -ForegroundColor Red -NoNewline
		Write-Host "it will not get installed, updated or deleted. Just ignored. I'm very good with ignoring."
	}
	nls 3
}


# auto update this script itself (prepare the update to be done by the .bat file with the next start)

removefile "$Script_path\GW2start.txt"

Invoke-WebRequest "https://github.com/Tinsus/GW2-updater-script/raw/main/GW2start.ps1" -OutFile "$Script_path/GW2start.txt"

Write-Host "GW2start.ps1 " -NoNewline -ForegroundColor White
Write-Host "is " -NoNewline
Write-Host "updated " -NoNewline -ForegroundColor Green
Write-Host "every time"


# auto update ArcDPS
if ($use_ArcDPS) {
	$checkurl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"
	$targeturl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
	$targetfile = "$GW2_path\bin64\d3d9.dll"
	$checkfile = "$Version_path\d3d9.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.check" -Raw).Trim() -ne (Get-Content "$checkfile.md5" -Raw).Trim())
	) {
		Write-Host "ArcDPS " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# direct install
		removefile "$targetfile"
		Invoke-WebRequest "$targeturl" -OutFile "$targetfile"

		# remember this version
		removefile "$checkfile.md5"
		Rename-Item "$checkfile.check" -NewName "$checkfile.md5"
	} else {
		Write-Host "ArcDPS " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update TacO
if ($use_TacO) {
	newdir "$TacO_path"

	$checkurl = "https://api.github.com/repos/BoyC/GW2TacO/releases/latest"
	$targetfile = "$TacO_path\"
	$checkfile = "$Version_path\taco"

	checkGithub
	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
	) {
		Write-Host "TacO " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

		Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$targetfile" -Force
		removefile "$checkfile.temp.zip"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $json.node_id
	} else {
		Write-Host "TacO " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update arcdps-killproof.me-plugin
if ($use_ArcDPS) {
	checkGithub

	$checkurl = "https://api.github.com/repos/knoxfighter/arcdps-killproof.me-plugin/releases/latest"
	$targetfile = "$GW2_path\bin64\d3d9_arcdps_killproof_me.dll"
	$checkfile = "$Version_path\d3d9_arcdps_killproof_me.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.name)
	) {
		Write-Host "ArcDps-killproof.me-plugin " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $json.name
	} else {
		Write-Host "ArcDps-killproof.me-plugin " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update arcdps-Boon-Table-plugin
if ($use_ArcDPS) {
	checkGithub

	$checkurl = "https://api.github.com/repos/knoxfighter/GW2-ArcDPS-Boon-Table/releases/latest"
	$targetfile = "$GW2_path\bin64\d3d9_arcdps_table.dll"
	$checkfile = "$Version_path\d3d9_arcdps_table.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.name)
	) {
		Write-Host "GW2-ArcDps-Boon-Table " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $json.name
	} else {
		Write-Host "GW2-ArcDps-Boon-Table " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update arcdps-healing-stats
if ($use_ArcDPS) {
	checkGithub

	$checkurl = "https://api.github.com/repos/Krappa322/arcdps_healing_stats/releases/latest"
	$targetfile = "$GW2_path\bin64\arcdps_healing_stats.dll"
	$checkfile = "$Version_path\arcdps_healing_stats.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.name)
	) {
		Write-Host "arcdps-healing-stats " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $json.name
	} else {
		Write-Host "arcdps-healing-stats " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update GW2-ArcDPS-Mechanics-Log
if ($use_ArcDPS) {
	checkGithub

	$checkurl = "https://api.github.com/repos/knoxfighter/GW2-ArcDPS-Mechanics-Log/releases/latest"
	$targetfile = "$GW2_path\bin64\ d3d9_arcdps_mechanics.dll"
	$checkfile = "$Version_path\ d3d9_arcdps_mechanics.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.name)
	) {
		Write-Host "GW2-ArcDPS-Mechanics-Log " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets[0].browser_download_url -OutFile "$targetfile"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $json.name
	} else {
		Write-Host "GW2-ArcDPS-Mechanics-Log " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update BlishHUD
if ($use_BHud) {
	newdir "$BlishHUD_path"
	newdir "$MyDocuments_path\Guild Wars 2"
	newdir "$MyDocuments_path\Guild Wars 2\addons"
	newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud"
	newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\markers"
	newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/Blish-HUD/releases/latest"
	$targetfile = "$BlishHUD_path\"
	$checkfile = "$Version_path\blishhud"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
	) {
		Write-Host "BlishHUD " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

		Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$targetfile\" -Force
		removefile "$checkfile.temp.zip"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $json.node_id

		#generate settings.json
		Write-Host "Generating default files. This takes about 10 seconds." -ForegroundColor DarkGray
		Start-Process -FilePath "$BlishHUD_path\Blish HUD.exe" -WorkingDirectory "$BlishHUD_path\" -ErrorAction SilentlyContinue
		Start-Sleep -Seconds 12
		Stop-Process -Name "Blish HUD" -ErrorAction SilentlyContinue
	} else {
		Write-Host "BlishHUD " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update BlishHUD-ArcDPS Bridge
if ($use_BHud -and $use_ArcDPS) {
	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/arcdps-bhud/releases/latest"
	$targetfile = "$GW2_path\bin64\arcdps_bhud.dll"
	$checkfile = "$Version_path\arcdps_bhud.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
	) {
		Write-Host "BlishHUD-ArcDPS Bridge " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url[1] -OutFile "$checkfile.zip"

		removefile "$targetfile"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$GW2_path\bin64\" -Force
		removefile "$checkfile.zip"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $json.node_id
	} else {
		Write-Host "BlishHUD-ArcDPS Bridge " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update BlishHUD-Modules

# Pathing
if ($use_BHud) {
	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/Pathing/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
	$checkfile = "$Version_path\pathing"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
	$new = $($json.tag_name).Substring(1)

	$old = 0

	if (Test-Path "$checkfile.md5") {
		$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
	}

	if ($new -ne $old) {
		Write-Host "BlishHUD-Module Pathing " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$checkpath\bh.community.pathing_$old.bhm"
		removefile "$checkpath\Pathing_v$old.bhm"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\bh.community.pathing_$new.bhm"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $new

		# enable this version
		enforceBHM "bh.community.pathing"
	} else {
		Write-Host "BlishHUD-Module Pathing " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# KillProof-Module
if ($use_BHud) {
	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/KillProof-Module/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
	$targetfile = "$checkpath\KillProof.bhm"
	$checkfile = "$Version_path\KillProof.bhm"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
	$new = $($json.tag_name).Substring(1)

	$old = 0

	if (Test-Path "$checkfile.md5") {
		$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
	}

	if ($new -ne $old) {
		Write-Host "BlishHUD-Module KillProof " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$targetfile"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $new

		# enable this version
		enforceBHM "KillProofModule"
	} else {
		Write-Host "BlishHUD-Module KillProof " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# Quick-Surrender
if ($use_BHud) {
	checkGithub

	$checkurl = "https://api.github.com/repos/agaertner/Blish-HUD-Modules-Releases/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
	$targetfile = "$checkpath\QuickSurrender"
	$checkfile = "$Version_path\QuickSurrender"

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
		Write-Host "BlishHUD-Module Quick-Surrender " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$checkpath\Nekres.Quick_Surrender_Module_$old.bhm"
		removefile "$checkpath\$name"

		#  get new version
		Invoke-WebRequest $targeturl -OutFile "$checkpath\Nekres.Quick_Surrender_Module_$new.bhm"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $new

		# enable this version
		enforceBHM "Nekres.Quick_Surrender_Module"
	} else {
		Write-Host "BlishHUD-Module Quick-Surrender " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# BlishHud-HPGrid
if ($use_BHud) {
	checkGithub

	$checkurl = "https://api.github.com/repos/manlaan/BlishHud-HPGrid/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
	$targetfile = "$checkpath\BlishHud-HPGrid"
	$checkfile = "$Version_path\BlishHud-HPGrid"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
	$new = $($json.tag_name).Substring(1)

	$old = 0

	if (Test-Path "$checkfile.md5") {
		$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
	}

	$new = $json.name
	$name = $json.assets.name

	if ($new -ne $old) {
		Write-Host "BlishHUD-Module HPGrid " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$checkpath\Manlaan.HPGrid_$old.bhm"
		removefile "$checkpath\$name"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\Manlaan.HPGrid_$new.bhm"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $new

		# enable this version
		enforceBHM "Manlaan.HPGrid"
	} else {
		Write-Host "BlishHUD-Module HPGrid " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# BlishHud-Timers
if ($use_BHud) {
	checkGithub

	$checkurl = "https://api.github.com/repos/Dev-Zhao/Timers_BlishHUD/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
	$targetfile = "$checkpath\BlishHud-Timers"
	$checkfile = "$Version_path\BlishHud-Timers"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
	$new = $($json.tag_name).Substring(1)

	$old = 0

	if (Test-Path "$checkfile.md5") {
		$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
	}

	$new = $json.name
	$new = $new.Substring($new.Length - 5, 5)
	$name = $json.assets.name

	if ($new -ne $old) {
		Write-Host "BlishHUD-Module Timers " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$checkpath\Charr.Timers_BlishHUD_$old.bhm"
		removefile "$checkpath\$name"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\Charr.Timers_BlishHUD_$new.bhm"

		# remember this version
		Set-Content -Path "$checkfile.md5" -Value $new

		# enable this version
		enforceBHM "Charr.Timers_BlishHUD"
	} else {
		Write-Host "BlishHUD-Module Timers " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update TEKKIT
if ($use_BHud -or $use_TacO) {
	$checkurl = "http://tekkitsworkshop.net/index.php/gw2-taco/changelog"
	$targeturl = "http://tekkitsworkshop.net/index.php/component/jdownloads/send/2-taco-marker-packs/32-all-in-one"
	$targetfile = "tw_ALL_IN_ONE.taco"
	$checkfile = "$Version_path\tw_ALL_IN_ONE.taco"

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	if (
		(
			$use_TacO -and
			(
				(-not (Test-Path "$checkfile.t.md5")) -or
				(Compare-Object -ReferenceObject $(Get-Content "$checkfile.check") -DifferenceObject $(Get-Content "$checkfile.t.md5"))
			)
		) -or (
			$use_BHud -and
			(
				(-not (Test-Path "$checkfile.b.md5")) -or
				(Compare-Object -ReferenceObject $(Get-Content "$checkfile.check") -DifferenceObject $(Get-Content "$checkfile.b.md5"))
			)
		)
	) {
		Write-Host "TEKKIT " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

		if ($use_BHud) {
			removefile "$path_b"
			Copy-Item "$checkfile" -Destination "$path_b"
			removefile "$checkfile.b.md5"
			Copy-Item "$checkfile.check" -Destination "$checkfile.b.md5"
		}

		if ($use_TacO) {
			removefile "$path_t"
			Copy-Item "$checkfile" -Destination "$path_t"
			removefile "$checkfile.t.md5"
			Copy-Item "$checkfile.check" -Destination "$checkfile.t.md5"
		}

		removefile "$checkfile"
	} else {
		Write-Host "TEKKIT " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update SCHATTENFLUEGEL
if ($use_BHud -or $use_TacO) {
	checkGithub

	$checkurl = "https://api.github.com/repos/Schattenfluegel/SchattenfluegelTrails/contents/Download"
	$targeturl = "https://github.com/Schattenfluegel/SchattenfluegelTrails/raw/main/Download/SchattenfluegelTrails.taco"
	$targetfile = "SchattenfluegelTrails.taco"
	$checkfile = "$Version_path\SchattenfluegelTrails.taco"

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	if (
		(
			$use_TacO -and
			(
				(-not (Test-Path "$checkfile.t.md5")) -or
				$(Get-FileHash "$checkfile.check").Hash -ne $(Get-FileHash "$checkfile.t.md5").Hash
			)
		) -or (
			$use_BHud -and
			(
				(-not (Test-Path "$checkfile.b.md5")) -or
				$(Get-FileHash "$checkfile.check").Hash -ne $(Get-FileHash "$checkfile.b.md5").Hash
			)
		)
	) {
		Write-Host "SCHATTENFLUEGEL " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

		if ($use_TacO) {
			removefile "$path_t"
			Copy-Item "$checkfile" -Destination "$path_t"
			removefile "$checkfile.t.md5"
			Copy-Item "$checkfile.check" -Destination "$checkfile.t.md5"
		}

		if ($use_BHud) {
			removefile "$path_b"
			Copy-Item "$checkfile" -Destination "$path_b"
			removefile "$checkfile.b.md5"
			Copy-Item "$checkfile.check" -Destination "$checkfile.b.md5"
		}

		removefile "$checkfile"
	} else {
		Write-Host "SCHATTENFLUEGEL " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update HEROMARKERS
# update for BlishHUD (no TacO support)
if ($use_BHud) {
	checkGithub

	$checkurl = "https://api.github.com/repos/QuitarHero/Heros-Marker-Pack/releases/latest"
	$targetfile = "Hero.Blish.Pack.zip"
	$checkfile = "$Version_path\Hero.Blish.Pack.zip"

	$path_b = path_b $targetfile

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"
	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	if (
		-not (Test-Path "$checkfile.md5") -or
		((Get-Content "$checkfile.md5" -Raw).Trim() -ne $json.node_id)
	) {
		Write-Host "HEROMARKERS " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$path_b"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$path_b"

		Set-Content -Path "$checkfile.md5" -Value $json.node_id
	} else {
		Write-Host "HEROMARKERS " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update CZOKALAPIK
if ($use_BHud -or $use_TacO) {
	$checkurl = "https://api.bitbucket.org/2.0/repositories/czokalapik/czokalapiks-guides-for-gw2taco/commits"
	$targeturl = "https://bitbucket.org/czokalapik/czokalapiks-guides-for-gw2taco/get"
	$targetfile = "czokalapiks-guides.taco"
	$checkfile = "$Version_path\czokalapiks-guides.taco"

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"
	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json

	$hash = $($json.values[0].hash).Substring(0, 12)

	if (
		(
			$use_TacO -and
			(
				(-not (Test-Path "$checkfile.t.md5")) -or
				((Get-Content "$checkfile.t.md5" -Raw).Trim() -ne $json.values[0].hash)
			)
		) -or (
			$use_BHud -and
			(
				(-not (Test-Path "$checkfile.b.md5")) -or
				((Get-Content "$checkfile.b.md5" -Raw).Trim() -ne $json.values[0].hash)
			)
		)
	) {
		Write-Host "CZOKALAPIK " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest "$targeturl/$hash.zip" -OutFile "$checkfile.zip"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$Version_path\" -Force
		removefile "$checkfile.zip"
		Compress-Archive -Path "$Version_path\czokalapik-czokalapiks-guides-for-gw2taco-$hash\POIs\*" -DestinationPath "$checkfile.zip"
		Remove-Item "$Version_path\czokalapik-czokalapiks-guides-for-gw2taco-$hash" -Recurse -force

		if ($use_TacO) {
			removefile "$path_t"
			Copy-Item "$checkfile.zip" -Destination "$path_t"
			Set-Content -Path "$checkfile.t.md5" -Value $json.values[0].hash
		}

		if ($use_BHud) {
			removefile "$path_b"
			Copy-Item "$checkfile.zip" -Destination "$path_b"
			Set-Content -Path "$checkfile.b.md5" -Value $json.values[0].hash
		}

		removefile "$checkfile.zip"
	} else {
		Write-Host "CZOKALAPIK " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile.check"
}


# auto update REACTIF
if ($use_BHud -or $use_TacO) {
	$ver = Select-Xml -Content ((Invoke-WebRequest "https://heinze.fr/taco/rss-en.xml").Content) -XPath "//item/pubDate" | Select-Object -First 1 | foreach-object { $_.node.InnerXML }
	$targeturl = "https://www.heinze.fr/taco/download.php?f=3"
	$targetfile = "reactif_en.taco"
	$checkfile = "$Version_path\reactif_en.taco"

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	if (
		(
			$use_TacO -and
			(
				(-not (Test-Path "$checkfile.t.md5")) -or
				((Get-Content "$checkfile.t.md5" -Raw).Trim() -ne $ver)
			)
		) -or (
			$use_BHud -and
			(
				(-not (Test-Path "$checkfile.b.md5")) -or
				((Get-Content "$checkfile.b.md5" -Raw).Trim() -ne $ver)
			)
		)
	) {
		Write-Host "REACTIF " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

		if ($use_TacO) {
			removefile "$path_t"
			Copy-Item "$checkfile" -Destination "$path_t"
			Set-Content -Path "$checkfile.t.md5" -Value $ver
		}

		if ($use_BHud) {
			removefile "$path_b"
			Copy-Item "$checkfile" -Destination "$path_b"
			Set-Content -Path "$checkfile.b.md5" -Value $ver
		}

		removefile "$checkfile"
	} else {
		Write-Host "REACTIF " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}
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
removefile "$checkpath\Charr.Timers_BlishHUD_.bhm"
removefile "$checkpath\Manlaan.HPGrid_.bhm"
removefile "$checkpath\Nekres.Quick_Surrender_Module_.bhm"
removefile "$checkpath\bh.community.pathing_.bhm"
removefile "$GW2_path\github.json"


# done with updating

if (-not $older) {
	startGW2
	stopprocesses
}

removefile "$Script_path\github.json"


nls 1
Write-Host "see you soon"

Start-Sleep -Seconds 2
