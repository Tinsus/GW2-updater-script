# you really really don't need to change anything here - except you know exactly what you are doing


#some magic stuff for pathes and options

param($GW2_path_old, $TacO_path_old, $BlishHUD_path_old, $use_ArcDPS_old, $use_TacO_old, $use_BHud_old)

$MyDocuments_path = [Environment]::GetFolderPath("MyDocuments")
$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$Version_path = "$Script_path\version_control"

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
	removefile $FilePath

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
	#generate settings.json
	Write-Host "Generating default files. This takes about 10 seconds." -ForegroundColor DarkGray
	Start-Process -FilePath "$BlishHUD_path\Blish HUD.exe" -WorkingDirectory "$BlishHUD_path\" -ErrorAction SilentlyContinue
	Start-Sleep -Seconds 12
	Stop-Process -Name "Blish HUD" -ErrorAction SilentlyContinue

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

Clear-Host

#build or read the new and shiny GW2start.ini

if (-not (Test-Path "$Script_path\GW2start.ini")) {
	Write-Host "Hi there! It seems to be the very first time for you to use this script. This script can do a lot - maybe you don't want to use all of it. We build the file together now, if you want to change anything just edit or delete the following file: " -NoNewline -ForegroundColor White
	Write-Host "$Script_path\GW2start.ini"

	$conf = @{}

	nls 1
} else {
	$conf = Get-IniContent "$Script_path\GW2start.ini"

	nls 7
}

if ($conf.installation_paths -eq $null) {
	$conf["installation_paths"] = @{}
}

if ($conf.installation_paths.Guildwars2 -eq $null) {
	nls 1
	Write-Host "To do a lot of it's magic this script needs to know where you have installed " -NoNewline
	Write-Host "Guildwars 2" -NoNewline -ForegroundColor Yellow
	Write-Host "?"
	Write-Host "For example: C:\Program Files\Guild Wars 2"

	$input = "C:\Program Files\Guild Wars 2"

	if ($GW2_path_old -ne $null) {
		$input = $GW2_path_old.Substring(1, $GW2_path_old.Length - 2)
	}

	if (-not (Test-Path "$input\Gw2-64.exe")) {
		do {
			$input = Read-Host -Prompt "Enter the installation path to Guildwars 2: "
		} while (-not (Test-Path "$input\Gw2-64.exe"))
	} else {
		Write-Host "Found it: $input"
	}

	$conf["installation_paths"]["Guildwars2"] = $input

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

$GW2_path = $conf.installation_paths.Guildwars2

if ($conf.installation_paths.TacO -eq $null) {
	nls 1
	Write-Host "Most people like " -NoNewline
	Write-Host "TacO " -NoNewline -ForegroundColor Yellow
	Write-Host "a lot. Where do you want it to get installed or where do you have it installed already?"
	Write-Host "For example: C:\Program Files\TacO"

	$input = "C:\Program Files\TacO"

	if ($TacO_path_old -ne $null) {
		$input = $TacO_path_old.Substring(1, $TacO_path_old.Length - 2)
	}

	if (-not (Test-Path "$input")) {
		$input = Read-Host -Prompt "Enter the installation path for TacO: "
	} else {
		Write-Host "Found it: $input"
	}

	$conf["installation_paths"]["TacO"] = $input

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

$TacO_path = $conf.installation_paths.BlishHUD

if ($conf.installation_paths.BlishHUD -eq $null) {
	nls 1
	Write-Host "BlishHUD " -NoNewline -ForegroundColor Yellow
	Write-Host "is a project like TacO, but BlishHUD can do a lot more and is better costomizable. Where do you want it to get installed or already have it installed already?"
	Write-Host "For example: C:\Program Files\BlishHUD"

	$input = "C:\Program Files\BlishHUD"

	if ($BlishHUD_path_old -ne $null) {
		$input = $BlishHUD_path_old.Substring(1, $BlishHUD_path_old.Length - 2)
	}

	if (-not (Test-Path "$input")) {
		$input = Read-Host -Prompt "Enter the installation path for BlishHUD: "
	} else {
		Write-Host "Found it: $input"
	}

	$conf["installation_paths"]["BlishHUD"] = $input

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

$BlishHUD_path = $conf.installation_paths.BlishHUD

if ($conf.configuration -eq $null) {
	$conf["configuration"] = @{}
}

if ($conf.configuration.defaultmode -eq $null) {
	nls 1
	Write-Host "If you want to autoupdate and autostart every feature supported by this script activate the " -NoNewline
	Write-Host "default-mode " -NoNewline -ForegroundColor Yellow
	Write-Host "but if you like to edit what to install/update or auto start activate the " -NoNewline
	Write-Host "pro-mode" -ForegroundColor Yellow

	do {
		$input = Read-Host -Prompt "Type d for default-mode or p for pro-mode: "
	} while (-not(
		($input -eq "d") -or
		($input -eq "p")
	))

	$conf["configuration"]["defaultmode"] = $input -eq "d"

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.configuration.update_ArcDPS -eq $null) {
	$default = $true

	Write-Host "ArcDPS " -NoNewline -ForegroundColor Yellow
	Write-Host "is a great tool to monitor the DPS and other stuff of you and your group. (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"
	Write-Host "Warning: sometimes the game crashes after updates, especially after some game updates. This is may caused by ArcDPS. If this happens delete: " -NoNewline -ForegroundColor Red
	Write-Host "$GW2_path\bin64\d3d9.dll " -NoNewline
	Write-Host "Keep this warning in mind!" -ForegroundColor Red

	if (-not $conf.configuration.defaultmode) {
		do {
			$input = Read-Host -Prompt "Type y to install ArcDPS, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["configuration"]["update_ArcDPS"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.configuration.update_TacO -eq $null) {
	$default = $true

	Write-Host "TacO " -NoNewline -ForegroundColor Yellow
	Write-Host "is a great tool for almost any content in GW2, mostly known for its features to show paths inb the world or help within raids."
	Write-Host "Do you want this script to install TacO and keep it up-to-date? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		do {
			$input = Read-Host -Prompt "Type y to autoupdate TacO, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["configuration"]["update_TacO"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.configuration.update_BlishHUD -eq $null) {
	$default = $true

	Write-Host "BlishHUD " -NoNewline -ForegroundColor Yellow
	Write-Host "is a modern tool for doing the same stuff as TacO does but BlishHUD is more customizable and can be enhanced with so called modules."
	Write-Host "Do you want this script to install BlishHUD and keep it up-to-date? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["configuration"]["update_BlishHUD"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.configuration.start_TacO -eq $null) {
	$default = $false

	Write-Host "TacO " -NoNewline -ForegroundColor Yellow
	Write-Host "needs to be started additionaly to GW2. You need to play GW2 Fullscreen in window-mode."
	Write-Host "Do you want this script to autostart TacO? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_TacO) {
			Write-Host "TacO will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autostart TacO, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["configuration"]["start_TacO"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.configuration.start_BlishHUD -eq $null) {
	$default = $true

	Write-Host "BlishHUD " -NoNewline -ForegroundColor Yellow
	Write-Host "needs to be started additionaly to GW2. You need to play GW2 Fullscreen in window-mode."

	if ($conf.configuration.start_TacO) {
		Write-Host "TacO and BlishHUD can run side by side."
	}

	Write-Host "Do you want this script to autostart BlishHUD? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"


	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autostart BlishHUD, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["configuration"]["start_BlishHUD"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_ArcDPS -eq $null) {
	$conf["settings_ArcDPS"] = @{}
}

if ($conf.settings_ArcDPS.killproof -eq $null) {
	$default = $true

	Write-Host "killproof.me-plugin " -NoNewline -ForegroundColor Yellow
	Write-Host "extences ArcDPS to show the killproof.me data of your group members. Shortcut to open that is Shift+Alt+K"
	Write-Host "Do you want this script to autoupdate the killproof.me-plugin? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_ArcDPS) {
			Write-Host "ArcDPS will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate ArcDPS-killproof.me-plugin, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_ArcDPS"]["killproof"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_ArcDPS.boon_table -eq $null) {
	$default = $true

	Write-Host "Boon-Table-plugin " -NoNewline -ForegroundColor Yellow
	Write-Host "extences ArcDPS to show the boons done by you and your group members. Shortcut to open that is Shift+Alt+B"
	Write-Host "Do you want this script to autoupdate the Boon-Table-plugin? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_ArcDPS) {
			Write-Host "ArcDPS will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate ArcDPS-Boon-Table-plugin, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_ArcDPS"]["boon_table"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_ArcDPS.healing_stats -eq $null) {
	$default = $true

	Write-Host "Healing-Stats-plugin " -NoNewline -ForegroundColor Yellow
	Write-Host "extences ArcDPS to show your heal."
	Write-Host "Do you want this script to autoupdate the Healing-Stats-plugin? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_ArcDPS) {
			Write-Host "ArcDPS will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate Healing-Stats-plugin, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_ArcDPS"]["healing_stats"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_ArcDPS.mechanics_log -eq $null) {
	$default = $true

	Write-Host "Mechanics-Log-plugin " -NoNewline -ForegroundColor Yellow
	Write-Host "extences ArcDPS to how good you or your group members perform with the mechanics in raids. Shortcut to open that is Shift+Alt+L"
	Write-Host "Do you want this script to autoupdate the Mechanics-Log-plugin? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_ArcDPS) {
			Write-Host "ArcDPS will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate ArcDPS-Mechanics-Log-plugin, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_ArcDPS"]["mechanics_log"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD -eq $null) {
	$conf["settings_BlishHUD"] = @{}
}

if ($conf.settings_BlishHUD.ArcDPS_Bridge -eq $null) {
	$default = $true

	Write-Host "ArcDPS Bridge " -NoNewline -ForegroundColor Yellow
	Write-Host "allows BlishHUD to have access to the live ArcDPS data. Some Modules need that."
	Write-Host "Do you want this script to autoupdate the BlishHUD-ArcDPS-Bridge? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_ArcDPS) {
			Write-Host "ArcDPS will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-ArcDPS-Bridge, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["ArcDPS_Bridge"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD.Pathing -eq $null) {
	$default = $true

	Write-Host "Pathing-Module " -NoNewline -ForegroundColor Yellow
	Write-Host "allows BlishHUD to show pathes in the world like TacO does. You need that for all the Map-packs."
	Write-Host "Do you want this script to autoupdate the BlishHUD-Pathing-Module? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-Pathing-Module, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["Pathing"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD.KillProof_Module -eq $null) {
	$default = $true

	Write-Host "KillProof-Module " -NoNewline -ForegroundColor Yellow
	Write-Host "extences BlishHUD to show the killproof.me data of you and your group members."
	Write-Host "Do you want this script to autoupdate the KillProof-Module? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_ArcDPS) {
			Write-Host "ArcDPS will not get installed or updated. You need to enter the account-names or killproof-ids manually." -ForegroundColor Yellow
		}

		if (-not $conf.settings_BlishHUD.ArcDPS_Bridge) {
			Write-Host "BlishHUD-ArcDPS-Bridge will not get installed or updated. You need to enter the account-names or killproof-ids manually." -ForegroundColor Yellow
		}

		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-KillProof-Module, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["KillProof_Module"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD.Quick_Surrender -eq $null) {
	$default = $true

	Write-Host "Quick Surrender-Module " -NoNewline -ForegroundColor Yellow
	Write-Host "extences BlishHUD to show a nice /gg-Button right of your normal skill-bar. Push it and you die. Only visible whre you can /gg"
	Write-Host "Do you want this script to autoupdate the Quick Surrender-Module? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-KillProof-Module, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["Quick_Surrender"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD.Mistwar -eq $null) {
	$default = $true

	Write-Host "Mistwar-Module " -NoNewline -ForegroundColor Yellow
	Write-Host "extences BlishHUD to show a map in WvW. Just press N while you are in WvW to see it."
	Write-Host "Do you want this script to autoupdate the Mistwar-Module? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-Mistwar, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["Mistwar"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD.HPGrid -eq $null) {
	$default = $true

	Write-Host "HPGrid-Module " -NoNewline -ForegroundColor Yellow
	Write-Host "extences BlishHUD to show small bars on the lp bar of bosses in fractals and raids. The bars indicates where LP-driven mechanics happen."
	Write-Host "Do you want this script to autoupdate the HPGrid-Module? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-HPGrid, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["HPGrid"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD.Timers -eq $null) {
	$default = $true

	Write-Host "Timers-Module " -NoNewline -ForegroundColor Yellow
	Write-Host "extences BlishHUD to show information for mechanics in raids. Way better than TacO does - trust me."
	Write-Host "Do you want this script to autoupdate the Timers-Module? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-Timers, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["Timers"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_BlishHUD.Timers -eq $null) {
	$default = $true

	Write-Host "Timers-Module " -NoNewline -ForegroundColor Yellow
	Write-Host "extences BlishHUD to show information for mechanics in raids. Way better than TacO does - trust me."
	Write-Host "Do you want this script to autoupdate the Timers-Module? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate BlishHUD-Timers, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_BlishHUD"]["Timers"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_Mappacks -eq $null) {
	$conf["settings_Mappacks"] = @{}
}

if ($conf.settings_Mappacks.use_TacO -eq $null) {
	$default = $false

	Write-Host "Add map packs to " -NoNewline
	Write-Host "TacO? " -ForegroundColor Yellow -NoNewline
	Write-Host "BlishHUD can also do that."

	Write-Host "Do you want this script to autoupdate map packs for TacO? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_TacO) {
			Write-Host "TacO will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to add map packs to TacO, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_Mappacks"]["use_TacO"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_Mappacks.use_BlishHUD -eq $null) {
	$default = $true

	Write-Host "Add map packs to " -NoNewline
	Write-Host "BlishHUD? " -ForegroundColor Yellow -NoNewline
	Write-Host "Some packs only support BlishHUD."

	Write-Host "Do you want this script to autoupdate map packs for BlishHUD? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_BlishHUD) {
			Write-Host "BlishHUD will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to add map packs to BlishHUD-Pathing-Module, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_Mappacks"]["use_BlishHUD"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_Mappacks.tekkit -eq $null) {
	$default = $true

	Write-Host "TEKKIT-Map pack " -NoNewline -ForegroundColor Yellow
	Write-Host "map pack to show nearly anything in the world. Like map completions, farming trails, jumping puzzles and more. the mostly known map pack of them all and the reason the most people install TacO."
	Write-Host "Do you want this script to autoupdate TEKKIT? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (
			(-not $conf.configuration.update_TacO) -and
			(-not $conf.BlishHUD.Pathing)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		if (
			(-not $conf.settings_Mappacks.use_TacO) -and
			(-not $conf.settings_Mappacks.use_BlishHUD)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not used for map-packs. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate TEKKIT, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_Mappacks"]["tekkit"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_Mappacks.schattenfluegel -eq $null) {
	$default = $true

	Write-Host "Schattenfluegel-Map pack " -NoNewline -ForegroundColor Yellow
	Write-Host "map pack to show be better than TEKKIT. It adds shotcuts and way better pathes. Way better design, but not as complete as TEKKIT."
	Write-Host "Do you want this script to autoupdate Schattenfluegel? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (
			(-not $conf.configuration.update_TacO) -and
			(-not $conf.BlishHUD.Pathing)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		if (
			(-not $conf.settings_Mappacks.use_TacO) -and
			(-not $conf.settings_Mappacks.use_BlishHUD)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not used for map-packs. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate Schattenfluegel, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_Mappacks"]["schattenfluegel"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_Mappacks.czokalapik -eq $null) {
	$default = $true

	Write-Host "Czokalapik-Map pack " -NoNewline -ForegroundColor Yellow
	Write-Host "map pack for easy hero points farm runs. Includes all needed waypoints, easy to follow."
	Write-Host "Do you want this script to autoupdate Czokalapik? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (
			(-not $conf.configuration.update_TacO) -and
			(-not $conf.BlishHUD.Pathing)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		if (
			(-not $conf.settings_Mappacks.use_TacO) -and
			(-not $conf.settings_Mappacks.use_BlishHUD)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not used for map-packs. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate Czokalapik, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_Mappacks"]["czokalapik"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_Mappacks.reactif -eq $null) {
	$default = $true

	Write-Host "Reactif-Map pack " -NoNewline -ForegroundColor Yellow
	Write-Host "map pack like Tekkit but focused on achievements."
	Write-Host "Do you want this script to autoupdate Reactif? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (
			(-not $conf.configuration.update_TacO) -and
			(-not $conf.BlishHUD.Pathing)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		if (
			(-not $conf.settings_Mappacks.use_TacO) -and
			(-not $conf.settings_Mappacks.use_BlishHUD)
		) {
			Write-Host "TacO and BlishHUD-pathing-Module will not used for map-packs. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate Reactif, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_Mappacks"]["reactif"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_Mappacks.heromarkers -eq $null) {
	$default = $true

	Write-Host "Heromarkers-Map pack " -NoNewline -ForegroundColor Yellow
	Write-Host "to add nice tips and markers within the fractals. Only supported for BlishHUD."
	Write-Host "Do you want this script to autoupdate Heromarkers? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.BlishHUD.Pathing) {
			Write-Host "BlishHUD-pathing-Module will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		if (-not $conf.settings_Mappacks.use_BlishHUD) {
			Write-Host "BlishHUD-pathing-Module will not used for map-packs. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type y to autoupdate Heromarkers, n if don't want it: "
		} while (-not(
			($input -eq "y") -or
			($input -eq "n")
		))

		$default = $input -eq "y"
	}

	$conf["settings_Mappacks"]["heromarkers"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

#$conf.configuration.update_ArcDPS
#$conf.configuration.update_TacO
#$conf.configuration.update_BlishHUD
#$conf.configuration.start_TacO
#$conf.configuration.start_BlishHUD
#$conf.settings_ArcDPS.killproof
#$conf.settings_ArcDPS.boon_table
#$conf.settings_ArcDPS.healing_stats
#$conf.settings_ArcDPS.mechanics_log
#$conf.settings_BlishHUD.ArcDPS_Bridge
#$conf.settings_BlishHUD.Pathing
#$conf.settings_BlishHUD.KillProof_Module
#$conf.settings_BlishHUD.Quick_Surrender
#$conf.settings_BlishHUD.Mistwar
#$conf.settings_BlishHUD.HPGrid
#$conf.settings_BlishHUD.Timers
#$conf.settings_Mappacks.use_TacO
#$conf.settings_Mappacks.use_BlishHUD
#$conf.settings_Mappacks.tekkit
#$conf.settings_Mappacks.schattenfluegel
#$conf.settings_Mappacks.czokalapik
#$conf.settings_Mappacks.reactif
#$conf.settings_Mappacks.heromarkers

nls 3
Write-Host "To change any settings for this script checkout the GW2start.ini file located " -NoNewline
Write-Host "$Script_path\GW2start.ini" -ForegroundColor White

exit

#update behavior of:
#$use_ArcDPS
#$use_TacO
#$use_BHud

# clean up before anything else starts


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


# give message about GW2 build id
$checkurl = "https://api.guildwars2.com/v2/build"
$checkfile = "$Version_path\gw2"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
$new = $json.id

if (
	-not (Test-Path "$checkfile.md5") -or
	((Get-Content "$checkfile.md5" -Raw).Trim() -ne $new)
) {
	Write-Host "Guildwars 2 " -NoNewline -ForegroundColor White
	Write-Host "will update itself to build $new" -ForegroundColor Green

	# remember this version
	Set-Content -Path "$checkfile.md5" -Value $new
} else {
	Write-Host "Guildwars 2 " -NoNewline -ForegroundColor White
	Write-Host "is up-to-date"
}

removefile "$checkfile.check"


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

	$targeturl = ""

	$json.assets | foreach-object {
		if ($_.name -match "Surrender") {
			$targeturl = $_
		}
	}

	if ($targeturl -ne "") {
		if (Test-Path "$checkfile.md5") {
			$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
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
	} else {
		Write-Host "BlishHUD-Module Quick-Surrender " -NoNewline -ForegroundColor White
		Write-Host "is not contained in the latest bundle" -ForegroundColor Yellow
	}

	removefile "$checkfile.check"
}


# Mistwar
if ($use_BHud) {
	checkGithub

	$checkurl = "https://api.github.com/repos/agaertner/Blish-HUD-Modules-Releases/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
	$targetfile = "$checkpath\Mistwar"
	$checkfile = "$Version_path\Mistwar"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile.check"

	$json = (Get-Content "$checkfile.check" -Raw) | ConvertFrom-Json
	$new = $($json.tag_name).Substring(1)

	$old = 0

	$targeturl = ""

	$json.assets | foreach-object {
		if ($_.name -match "Mistwar") {
			$targeturl = $_
		}
	}

	if ($targeturl -ne "") {
		if (Test-Path "$checkfile.md5") {
			$old = $(Get-Content "$checkfile.md5" -Raw).Trim()
		}

		$new = $($targeturl.name)
		$new = $new.Substring($new.Length - 9, 5)
		$name = $targeturl.name
		$targeturl = $targeturl.browser_download_url

		if ($new -ne $old) {
			Write-Host "BlishHUD-Module Mistwar " -NoNewline -ForegroundColor White
			Write-Host "is being updated" -ForegroundColor Green

			# remove old version
			removefile "$checkpath\Nekres.Mistwar_$old.bhm"
			removefile "$checkpath\$name"

			#  get new version
			Invoke-WebRequest $targeturl -OutFile "$checkpath\Nekres.Mistwar_$new.bhm"

			# remember this version
			Set-Content -Path "$checkfile.md5" -Value $new

			# enable this version
			enforceBHM "Nekres.Mistwar"
		} else {
			Write-Host "BlishHUD-Module Mistwar " -NoNewline -ForegroundColor White
			Write-Host "is up-to-date"
		}
	} else {
		Write-Host "BlishHUD-Module Mistwar " -NoNewline -ForegroundColor White
		Write-Host "is not contained in the latest bundle" -ForegroundColor Yellow
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
