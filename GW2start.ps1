#param($GW2_path_old, $TacO_path_old, $BlishHUD_path_old, $use_ArcDPS_old, $use_TacO_old, $use_BHud_old)

$MyDocuments_path = [Environment]::GetFolderPath("MyDocuments")
$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$checkfile = "$Script_path\checkfile"

$forceGUI = $false

function stopprocesses() {
	if ($conf.configuration.start_TacO) {
		Stop-Process -Name "GW2TacO" -ErrorAction SilentlyContinue
	}

	if ($conf.configuration.start_BlishHUD) {
		Stop-Process -Name "Blish HUD" -ErrorAction SilentlyContinue
	}

	if ($conf.configuration.update_ArcDPS) {
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
	if ($conf.configuration.start_TacO) {
		Start-Process -FilePath "$TacO_path\GW2TacO.exe" -WorkingDirectory "$TacO_path\" -ErrorAction SilentlyContinue
	}

	# start BlishHUD
	if ($conf.configuration.start_BlishHUD) {
		Start-Process -FilePath "$BlishHUD_path\Blish HUD.exe" -WorkingDirectory "$BlishHUD_path\" -ErrorAction SilentlyContinue
	}

	# start Guild Wars 2
	nls 2
	Write-Host "have fun in Guild Wars 2"

	Start-Process -FilePath "$GW2_path\Gw2-64.exe" -WorkingDirectory "$GW2_path\" -ArgumentList '-autologin', '-bmp', '-mapLoadInfo' -wait -RedirectStandardError "$GW2_path\errorautocheck.txt"

	# if GW2 has an update removes ArcDPS
	if ($configuration.update_ArcDPS -and (Test-Path "$GW2_path\errorautocheck.txt") -and ((Get-Item "$GW2_path\errorautocheck.txt").length -ne 0)) {
		nls 1
		Write-Host "crash detected - removing ArcDPS" -ForegroundColor Red
		nls 1

		# UNTESTED (need update/crash to test this)
		$gw2error = Get-Content -Path "$GW2_path\errorautocheck.txt"

		removefile "$GW2_path\errorautocheck.txt"

		if ($gw2error -ne 0) {
			removefile "$GW2_path\bin64\d3d9.dll"
			removefile "$GW2_path\bin64\d3d11.dll"
			removefile "$GW2_path\d3d9.dll"
			removefile "$GW2_path\d3d11.dll"

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

	removefile "$Script_path\github.json"
	Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"

	$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json

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

			removefile "$Script_path\github.json"
			Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"

			$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json
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
		}

		$i++
	}

	$data | ConvertTo-Json -Depth 100 | Out-File "$MyDocuments_path\Guild Wars 2\addons\blishhud\settings.json"

	((Get-Content -path "$MyDocuments_path\Guild Wars 2\addons\blishhud\settings.json" -Raw).Replace("\u0027","'").Replace('   ', ' ').Replace('  ', ' ').Replace(":  ", ": ")) | Set-Content -Path "$MyDocuments_path\Guild Wars 2\addons\blishhud\settings.json"
}

function DeGZip-File($infile, $outfile = ($infile -replace '\.gz$','')) {
	$input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
	$output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
	$gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
	$buffer = New-Object byte[](1024)

	while ($true) {
		$read = $gzipstream.Read($buffer, 0, 1024)

		if ($read -le 0) {
			break
		}

		$output.Write($buffer, 0, $read)
	}

	$gzipStream.Close()
	$output.Close()
	$input.Close()
}

$modules = @{}
$modules.Main = @{}
$modules.ArcDPS = @{}
$modules.Path = @{}
$modules.BlishHud = @{}

$modules.ArcDPS.killproof = @{
	name = "killproof.me"
	desc = "extences ArcDPS to show the killproof.me data of your group members. Shortcut to open that is Shift+Alt+K"
	default = $true
	checkurl = "https://api.github.com/repos/knoxfighter/arcdps-killproof.me-plugin/releases/latest"
	targetfile = "bin64\d3d9_arcdps_killproof_me.dll"
	platform = "github-normal"
}

$modules.ArcDPS.boon = @{
	name = "Boon-Table"
	desc = "extences ArcDPS to show the boons done by you and your group members. Shortcut to open that is Shift+Alt+B"
	default = $true
	checkurl = "https://api.github.com/repos/knoxfighter/GW2-ArcDPS-Boon-Table/releases/latest"
	targetfile = "bin64\d3d9_arcdps_table.dll"
	platform = "github-normal"
}

$modules.ArcDPS.healing = @{
	name = "Healing-Stats"
	desc = "extences ArcDPS to show your heal."
	default = $true
	checkurl = "https://api.github.com/repos/Krappa322/arcdps_healing_stats/releases/latest"
	targetfile = "bin64\arcdps-healing-stats.dll"
	platform = "github-normal"
}

$modules.ArcDPS.mechanics = @{
	name = "Mechanics-Logs"
	desc = "extences ArcDPS to how good you or your group members perform with the mechanics in raids. Shortcut to open that is Shift+Alt+L"
	default = $true
	checkurl = "https://api.github.com/repos/knoxfighter/GW2-ArcDPS-Mechanics-Log/releases/latest"
	targetfile = "bin64\d3d9_arcdps_mechanics.dll"
	platform = "github-normal"
}

$modules.Path.schattenfluegel = @{
	name = "Schattenfluegel"
	desc = "map pack to show be better than TEKKIT. It adds shotcuts and way better pathes. Way better design, but not as complete as TEKKIT."
	default = $true
	checkurl = "https://api.github.com/repos/Schattenfluegel/SchattenfluegelTrails/contents/Download"
	targeturl = "https://github.com/Schattenfluegel/SchattenfluegelTrails/raw/main/Download/SchattenfluegelTrails.taco"
	targetfile = "SchattenfluegelTrails.taco"
	platform = "github-raw"
	blishonly = $false
}

$modules.Path.czokalapiks = @{
	name = "Czokalapiks"
	desc = "map pack for easy hero points farm runs. Includes all needed waypoints, easy to follow."
	default = $true
	checkurl = "https://api.bitbucket.org/2.0/repositories/czokalapik/czokalapiks-guides-for-gw2taco/commits"
	targeturl = "https://bitbucket.org/czokalapik/czokalapiks-guides-for-gw2taco/get"
	targetfile = "czokalapiks-guides.taco"
	platform = "bitbucket"
	blishonly = $false
}

Invoke-WebRequest "https://mp-repo.blishhud.com/repo.json" -OutFile "$checkfile"
$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
Remove-Item "$checkfile"

$i = 0

$json | foreach {
	$modules.Path["xbr$i"] = @{}
	$modules.Path["xbr$i"].name = $_.Name
	$modules.Path["xbr$i"].desc = $_.Description
	$modules.Path["xbr$i"].platform = "blishrepo"
	$modules.Path["xbr$i"].targeturl = $_.Download
	$modules.Path["xbr$i"].targetfile = $_.FileMane
	$modules.Path["xbr$i"].version = $_.LastUpdate

	if (
		($_.Name -eq "ReActif EN") -or
		($_.Name -eq "Hero's Marker Pack") -or
		($_.Name -eq "Tekkit's All-In-One") -or
		$false
	) {
		$modules.Path["xbr$i"].default = $true
	} else {
		$modules.Path["xbr$i"].default = $false
	}

	$i++
}

Invoke-WebRequest "https://pkgs.blishhud.com/packages.gz" -OutFile "$checkfile.gz"
DeGZip-File "$checkfile.gz"
Remove-Item "$checkfile.gz"
$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
Remove-Item "$checkfile"

$json | foreach {
	$filtered = $true

	$_.dependencies.psobject.properties | Foreach {
		if (
			($_.Name -eq "bh.blishhud") -and
			($_.Value -like "<*")
		) {
			$filtered = $false
		}
	}

	$name = $_.name -replace '[^a-zA-Z]', ''

	if ($filtered) {
		$modules.BlishHud[$name] = @{}
		$modules.BlishHud[$name].name = $_.name
		$modules.BlishHud[$name].desc = $_.description
		$modules.BlishHud[$name].targeturl = $_.location
		$modules.BlishHud[$name].version = $_.version
		$modules.BlishHud[$name].namespace = $_.namespace

		if (
			($_.Name -eq "Timers") -or
			$false
		) {
			$modules.BlishHud[$name].default = $true
		} else {
			$modules.BlishHud[$name].default = $false
		}
	}
}

function showGUI {
# prepare stuff
	Add-Type -assembly System.Windows.Forms

	$main_form = New-Object System.Windows.Forms.Form

	$tooltip = New-Object System.Windows.Forms.ToolTip
	$tooltip.AutoPopDelay = 30000;
	$tooltip.InitialDelay = 100;
	$tooltip.ReshowDelay = 500;

	$main_form.Text ='Config GW2start script'
	$main_form.AutoSize = $true
	$main_form.AutoSizeMode = 1

	$descriptionMain = New-Object System.Windows.Forms.Label
	$descriptionMain.Text = "Here you can config the GW2start script to your own need. This config shows up when new options are available.
	You can open this setting using the GW2start-config.bat placed next to your usual GW2start.bat"
	$descriptionMain.Location  = New-Object System.Drawing.Point(10, 10)
	$descriptionMain.AutoSize = $true
	$main_form.Controls.Add($descriptionMain)

# ARCDPS
	$groupArc = New-Object System.Windows.Forms.GroupBox
	$groupArc.Location = New-Object System.Drawing.Size(10, 40)
	$groupArc.AutoSize = $true
	$groupArc.AutoSizeMode = 1
	$groupArc.text = "ArcDPS"

	$descriptionArc = New-Object System.Windows.Forms.Label
	$descriptionArc.Text = "DPS meter with great expandability"
	$descriptionArc.Location = New-Object System.Drawing.Point(10, 15)
	$descriptionArc.AutoSize = $true
	$groupArc.Controls.Add($descriptionArc)

	$enabledArc = New-Object System.Windows.Forms.CheckBox
	$enabledArc.Text = "install + update"
	$enabledArc.Location = New-Object System.Drawing.Point(10, 30)
	$enabledArc.Add_CheckStateChanged({
		changeGUI -category "enable" -key "arc" -value $this.checked
	})
	$groupArc.Controls.Add($enabledArc)

	$pathArc = New-Object System.Windows.Forms.Button
	$pathArc.Location = New-Object System.Drawing.Size(10, 55)
	$pathArc.Size = New-Object System.Drawing.Size(50, 20)
	$pathArc.Text = "Edit"
	$pathArc.Add_Click({
		changeGUI -category "path" -key "arc"
	})
	$groupArc.Controls.Add($pathArc)

	$pathArcLabel = New-Object System.Windows.Forms.Label
	$pathArcLabel.Text = "Select installation path first"
	$pathArcLabel.Location = New-Object System.Drawing.Point(62, 58)
	$pathArcLabel.AutoSize = $true
	$groupArc.Controls.Add($pathArcLabel)

	$arcDx9 = New-Object System.Windows.Forms.RadioButton
	$arcDx9.Text = "DirectX 9"
	$arcDx9.Location = New-Object System.Drawing.Point(10, 80)
	$arcDx9.AutoSize = $true
	$arcDx9.Add_Click({
		changeGUI -category "dx" -key "9" -value $this.checked
	})
	$tooltip.SetToolTip($arcDx9, "Did you set Guildwars2 to use DirectX9 (default) or DirectX11?")
	$groupArc.Controls.Add($arcDx9)

	$arcDx11 = New-Object System.Windows.Forms.RadioButton
	$arcDx11.Text = "DirectX 11"
	$arcDx11.Location = New-Object System.Drawing.Point(90, 80)
	$arcDx11.AutoSize = $true
	$arcDx11.Add_Click({
		changeGUI -category "dx" -key "11" -value $this.checked

	})
	$tooltip.SetToolTip($arcDx11, "Did you set Guildwars2 to use DirectX9 (default) or DirectX11?")
	$groupArc.Controls.Add($arcDx11)

	$main_form.Controls.Add($groupArc)

# TACO
	$groupTaco = New-Object System.Windows.Forms.GroupBox
	$groupTaco.Location = New-Object System.Drawing.Size(($groupArc.Location.X + $groupArc.Width + 10) , $groupArc.Location.Y)
	$groupTaco.AutoSize = $true
	$groupTaco.AutoSizeMode = 1
	$groupTaco.text = "TacO"

	$descriptionTaco = New-Object System.Windows.Forms.Label
	$descriptionTaco.Text = "Oldschool tool best known for map paths"
	$descriptionTaco.Location = New-Object System.Drawing.Point(10, 15)
	$descriptionTaco.AutoSize = $true
	$groupTaco.Controls.Add($descriptionTaco)

	$enabledTaco = New-Object System.Windows.Forms.CheckBox
	$enabledTaco.Text = "install + update"
	$enabledTaco.Location = New-Object System.Drawing.Point(10, 30)
	$enabledTaco.Add_CheckStateChanged({
		changeGUI -category "enable" -key "taco" -value $this.checked
	})
	$groupTaco.Controls.Add($enabledTaco)

	$pathTaco = New-Object System.Windows.Forms.Button
	$pathTaco.Location = New-Object System.Drawing.Size(10, 55)
	$pathTaco.Size = New-Object System.Drawing.Size(50, 20)
	$pathTaco.Text = "Edit"
	$pathTaco.Add_Click({
		changeGUI -category "path" -key "taco"
	})
	$groupTaco.Controls.Add($pathTaco)

	$pathTacoLabel = New-Object System.Windows.Forms.Label
	$pathTacoLabel.Text = "Select installation path first"
	$pathTacoLabel.Location = New-Object System.Drawing.Point(62, 58)
	$pathTacoLabel.AutoSize = $true
	$groupTaco.Controls.Add($pathTacoLabel)

	$TacoRun = New-Object System.Windows.Forms.CheckBox
	$TacoRun.Text = "auto start"
	$TacoRun.Size = New-Object System.Drawing.Point(200, 20)
	$TacoRun.Location = New-Object System.Drawing.Point(10, 80)
	$TacoRun.Add_CheckStateChanged({
		changeGUI -category "auto" -key "taco" -value $this.checked
	})
	$tooltip.SetToolTip($TacoRun, "Should TacO start automaticly when using this script?")
	$groupTaco.Controls.Add($TacoRun)

	$main_form.Controls.Add($groupTaco)

# BLISH
	$groupBlish = New-Object System.Windows.Forms.GroupBox
	$groupBlish.Location = New-Object System.Drawing.Size(($groupTaco.Location.X + $groupTaco.Width + 10) , $groupArc.Location.Y)
	$groupBlish.AutoSize = $true
	$groupBlish.AutoSizeMode = 1
	$groupBlish.text = "Blish HUD"

	$descriptionBlish = New-Object System.Windows.Forms.Label
	$descriptionBlish.Text = "Modern tool, better and bigger than TacO"
	$descriptionBlish.Location = New-Object System.Drawing.Point(10, 15)
	$descriptionBlish.AutoSize = $true
	$groupBlish.Controls.Add($descriptionBlish)

	$enabledBlish = New-Object System.Windows.Forms.CheckBox
	$enabledBlish.Text = "install + update"
	$enabledBlish.Location = New-Object System.Drawing.Point(10, 30)
	$enabledBlish.Add_CheckStateChanged({
		changeGUI -category "enable" -key "blish" -value $this.checked
	})
	$groupBlish.Controls.Add($enabledBlish)

	$pathBlish = New-Object System.Windows.Forms.Button
	$pathBlish.Location = New-Object System.Drawing.Size(10, 55)
	$pathBlish.Size = New-Object System.Drawing.Size(50, 20)
	$pathBlish.Text = "Edit"
	$pathBlish.Add_Click({
		changeGUI -category "path" -key "blish"
	})
	$groupBlish.Controls.Add($pathBlish)

	$pathBlishLabel = New-Object System.Windows.Forms.Label
	$pathBlishLabel.Text = "Select installation path first"
	$pathBlishLabel.Location = New-Object System.Drawing.Point(62, 58)
	$pathBlishLabel.AutoSize = $true
	$groupBlish.Controls.Add($pathBlishLabel)

	$BlishRun = New-Object System.Windows.Forms.CheckBox
	$BlishRun.Text = "auto start"
	$BlishRun.Size = New-Object System.Drawing.Point(200, 20)
	$BlishRun.Location = New-Object System.Drawing.Point(10, 80)
	$BlishRun.Add_CheckStateChanged({
		changeGUI -category "auto" -key "blish" -value $this.checked
	})
	$tooltip.SetToolTip($BlishRun, "Should Blish HUD start automaticly when using this script?")
	$groupBlish.Controls.Add($BlishRun)

	$main_form.Controls.Add($groupBlish)

# ARCDPS ADDONS
	$groupAddons = New-Object System.Windows.Forms.GroupBox
	$groupAddons.Location = New-Object System.Drawing.Size(($groupArc.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))
	$groupAddons.AutoSize = $true
	$groupAddons.AutoSizeMode = 1
	$groupAddons.text = "ArcDPS Addons"

	$i = 0
	$modules.ArcDPS.GetEnumerator() | foreach {
		$modules.ArcDPS[$_.key]["UI"] = New-Object System.Windows.Forms.CheckBox
		$modules.ArcDPS[$_.key]["UI"].Text = $_.value.name
		$modules.ArcDPS[$_.key]["UI"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.ArcDPS[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (20 * $i)))
		$modules.ArcDPS[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 20)
		$modules.ArcDPS[$_.key]["UI"].Add_CheckStateChanged({
			changeGUI -category "addons" -key $this.Value -value $this.checked
		})
		$tooltip.SetToolTip($modules.ArcDPS[$_.key]["UI"], $_.value.desc)
		$groupAddons.Controls.Add($modules.ArcDPS[$_.key]["UI"])

		$i++
	}

	$main_form.Controls.Add($groupAddons)

# PATHS
	$groupPaths = New-Object System.Windows.Forms.GroupBox
	$groupPaths.Location = New-Object System.Drawing.Size(($groupTaco.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))
	$groupPaths.AutoSize = $true
	$groupPaths.AutoSizeMode = 1
	$groupPaths.text = "Paths for Blish HUD and TacO"

	$i = 0
	$modules.Path.GetEnumerator() | foreach {
		$modules.Path[$_.key]["UI"] = New-Object System.Windows.Forms.Label
		$modules.Path[$_.key]["UI"].Text = $_.value.name
		$modules.Path[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (40 * $i)))
		$modules.Path[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 15)
		$tooltip.SetToolTip($modules.Path[$_.key]["UI"], $_.value.desc)
		$groupPaths.Controls.Add($modules.Path[$_.key]["UI"])

		$modules.Path[$_.key]["UI1"] = New-Object System.Windows.Forms.CheckBox

		$modules.Path[$_.key]["UI1"].Text = "Blish HUD"
		$modules.Path[$_.key]["UI1"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.Path[$_.key]["UI1"].Location = New-Object System.Drawing.Point(30, (35 + (40 * $i)))
		$modules.Path[$_.key]["UI1"].Size = New-Object System.Drawing.Point(80, 20)
		$modules.Path[$_.key]["UI1"].Add_CheckStateChanged({
			changeGUI -category "blish" -key $this.value -value $this.checked
		})
		$tooltip.SetToolTip($modules.Path[$_.key]["UI1"], $_.value.desc)
		$groupPaths.Controls.Add($modules.Path[$_.key]["UI1"])

		$modules.Path[$_.key]["UI2"] = New-Object System.Windows.Forms.CheckBox
		$modules.Path[$_.key]["UI2"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.Path[$_.key]["UI2"].Text = "TacO"
		$modules.Path[$_.key]["UI2"].Location = New-Object System.Drawing.Point(120, (35 + (40 * $i)))
		$modules.Path[$_.key]["UI2"].Size = New-Object System.Drawing.Point(80, 20)
		$modules.Path[$_.key]["UI2"].Add_CheckStateChanged({
			changeGUI -category "taco" -key $this.value -value $this.checked
		})
		$tooltip.SetToolTip($modules.Path[$_.key]["UI2"], $_.value.desc)
		$groupPaths.Controls.Add($modules.Path[$_.key]["UI2"])

		$i++
	}

	$main_form.Topmost = $true
	$main_form.Controls.Add($groupPaths)

# BLISH MODULES
	$groupModules = New-Object System.Windows.Forms.GroupBox
	$groupModules.Location = New-Object System.Drawing.Size(($groupBlish.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))
	$groupModules.AutoSize = $true
	$groupModules.AutoSizeMode = 1
	$groupModules.text = "Blish HUD modules"

	$i = 0
	$modules.BlishHUD.GetEnumerator() | foreach {
		$modules.BlishHUD[$_.key]["UI"] = New-Object System.Windows.Forms.CheckBox
		$modules.BlishHUD[$_.key]["UI"].Text = $_.value.name
		$modules.BlishHUD[$_.key]["UI"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.BlishHUD[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (20 * $i)))
		$modules.BlishHUD[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 20)
		$modules.BlishHUD[$_.key]["UI"].Add_CheckStateChanged({
			changeGUI -category "module" -key $this.Value -value $this.checked
		})
		$tooltip.SetToolTip($modules.BlishHUD[$_.key]["UI"], $_.value.desc)
		$groupModules.Controls.Add($modules.BlishHUD[$_.key]["UI"])

		$i++
	}

	$main_form.Controls.Add($groupModules)

# STUFF
	$max = (@($groupBlish.Height, $groupArc.Height, $groupTaco.Height) | measure -Maximum).Maximum

	$groupBlish.Height = $max
	$groupTaco.Height = $max
	$groupArc.Height = $max

	$max = (@($groupTaco.Width, $groupBlish.Width, $groupAddons.Width, $groupPaths.Width, $groupModules.Width, $groupArc.Width) | measure -Maximum).Maximum

	$groupTaco.Width = $max
	$groupBlish.Width = $max
	$groupAddons.Width = $max
	$groupPaths.Width = $max
	$groupModules.Width = $max
	$groupArc.Width = $max

	$groupTaco.Location = New-Object System.Drawing.Size(($groupArc.Location.X + $groupArc.Width + 10) , $groupArc.Location.Y)
	$groupBlish.Location = New-Object System.Drawing.Size(($groupTaco.Location.X + $groupTaco.Width + 10) , $groupArc.Location.Y)

	$groupPaths.Location = New-Object System.Drawing.Size(($groupTaco.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))
	$groupModules.Location = New-Object System.Drawing.Size(($groupBlish.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))

	$x = $groupTaco.Width * 1.5 + $groupTaco.x -35
	$y = (@($groupArc.Height, $groupBlish.Height, $groupTaco.Height) | measure -Maximum).Maximum + (@($groupAddons.Height, $groupPaths.Height, $groupModules.Height) | measure -Maximum).Maximum + $groupArc.y + 60

    $close = New-Object System.Windows.Forms.Button
    $close.Location = New-Object System.Drawing.Size($x, $y)
    $close.Size = New-Object System.Drawing.Size(70, 40)
    $close.Text = "Save and Run"
    $close.DialogResult = "OK"
	$close.Add_Click({
		changeGUI -category "save" -key "default" -value $false
	})
    $main_form.Controls.Add($close)


	$main_form.ShowDialog()

	validateGUI
}

function validateGUI {

}

function changeGUI($category, $key = 0, $value = 0) {
	switch($category) {
		"save" {
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}
	}

	#$modules.ArcDPS[$_.key]["UI"].Enabled = $false #arc
	#$modules.ArcDPS[$_.key]["UI"].Checked = $_.value.default

	#$modules.Path[$_.key]["UI"].Enabled = $false  #lable
	#$modules.Path[$_.key]["UI1"].Enabled = $false  #blish
	#$modules.Path[$_.key]["UI1"].Checked = $_.value.default
	#$modules.Path[$_.key]["UI2"].Enabled = $false  #taco
	#$modules.Path[$_.key]["UI2"].Checked = $_.value.default

	#$modules.BlishHUD[$_.key]["UI"].Enabled = $false
	#$modules.BlishHUD[$_.key]["UI"].Checked = $_.value.default

	Write-Host $category
	Write-Host $key
	Write-Host $value

	<#

	blish path

	$shell = New-Object -ComObject Shell.Application
		$path = $shell.BrowseForFolder(0, "Select where Blish HUD gets installed", 0).Self.Path

		while (
			-not (
				(Test-Path "$path\Blish HUD.exe") -or
				(Get-ChildItem "$path" -Recurse -File | Measure-Object | %{ return $_.Count -eq 0})
			)
		) {
			[System.Windows.Forms.MessageBox]::Show(
				"Blish HUD was not detected in the selected folder or it is not empthy. Select the folder containing Blish HUD. Or create a new empthy folder.",
				"Blish HUD.exe not found or folder not empthy",
				0,
				"Error"
			)

			$path = $shell.BrowseForFolder(0, "Select where Blish HUD gets installed", 0).Self.Path
		}

		if (
			(Test-Path "$path\Blish HUD.exe") -or
			(Get-ChildItem "$path" -Recurse -File | Measure-Object | %{ return $_.Count -eq 0})
		) {
			$BlishRun.Enabled = $true
		} else {
			$path = "Select installation path"
			$BlishRun.Enabled = $false
		}

		$pathBlishLabel.Text = $path


	blish install

	$pathBlish.Enabled = $enabledBlish.Checked
		$pathBlishLabel.Enabled = $enabledBlish.Checked

		if ($enabledBlish.Checked) {
			$enabledBlish.Text = "install + update"
		} else {
			$enabledBlish.Text = "uninstall"
		}

		$path = $pathBlishLabel.Text

		if (
			(Test-Path "$path\Blish HUD.exe") -or
			(Get-ChildItem "$path" | Measure-Object | %{ return $_.Count -eq 0})
		) {
			$path = "Select installation path"
			$BlishRun.Enabled = $false
		} else {
			$BlishRun.Enabled = $true
		}


	taco path

	$shell = New-Object -ComObject Shell.Application
		$path = $shell.BrowseForFolder(0, "Select where TacO gets installed", 0).Self.Path

		while (
			-not (
				(Test-Path "$path\GW2TacO.exe") -or
				(Get-ChildItem "$path" -Recurse -File | Measure-Object | %{ return $_.Count -eq 0})
			)
		) {
			[System.Windows.Forms.MessageBox]::Show(
				"TacO was not detected in the selected folder or it is not empthy. Select the folder containing TacO. Or create a new empthy folder.",
				"GW2TacO.exe not found or folder not empthy",
				0,
				"Error"
			)

			$path = $shell.BrowseForFolder(0, "Select where TacO gets installed", 0).Self.Path
		}

		if (
			(Test-Path "$path\GW2TacO.exe") -or
			(Get-ChildItem "$path" | Measure-Object | %{ return $_.Count -eq 0})
		) {
			$TacoRun.Enabled = $true
		} else {
			$path = "Select installation path"
			$TacoRun.Enabled = $false
		}

		$pathTacoLabel.Text = $path

		taco install

		$pathTaco.Enabled = $enabledTaco.Checked
		$pathTacoLabel.Enabled = $enabledTaco.Checked

		if ($enabledTaco.Checked) {
			$enabledTaco.Text = "install + update"
		} else {
			$enabledTaco.Text = "uninstall"
		}

		$path = $pathTacoLabel.Text

		if (
			(Test-Path "$path\GW2TacO.exe") -or
			(Get-ChildItem "$path" -Recurse -File | Measure-Object | %{ return $_.Count -eq 0})
		) {
			$path = "Select installation path"
			$TacoRun.Enabled = $false
		} else {
			$TacoRun.Enabled = $true
		}

		dx11
		$arcDx9.Checked = $false

		$modules.ArcDPS.GetEnumerator() | foreach {
			$modules.ArcDPS[$_.key]["UI"].Enabled = $true
		}

		dx9

		$arcDx11.Checked = $false

		$modules.ArcDPS.GetEnumerator() | foreach {
			$modules.ArcDPS[$_.key]["UI"].Enabled = $true
		}

		path arc

		$shell = New-Object -ComObject Shell.Application
		$path = $shell.BrowseForFolder(0, "Select where Guildwars 2 is installed", 0).Self.Path

		while (
			-not (
				(Test-Path "$path\Gw2-64.exe") -or
				($path.length -lt 3)
			)
		) {
			[System.Windows.Forms.MessageBox]::Show(
				"Guildwars 2 was not detected in the selected folder. Select the folder where Guildwars 2 is installed",
				"GW2-62.exe not found",
				0,
				"Error"
			)

			$path = $shell.BrowseForFolder(0, "Select where GW2 is installed", 0).Self.Path
		}

		if (-not (Test-Path "$path\Gw2-64.exe")) {
			$path = "Select installation path"
			$arcDx9.Enabled = $false
			$arcDx11.Enabled = $false
		} else {
			$arcDx9.Enabled = $true
			$arcDx11.Enabled = $true
		}

		$pathArcLabel.Text = $path

		enable arc
				$pathArc.Enabled = $enabledArc.Checked
		$pathArcLabel.Enabled = $enabledArc.Checked

		if ($enabledArc.Checked) {
			$enabledArc.Text = "install + update"
		} else {
			$enabledArc.Text = "uninstall"
		}

		$path = $pathArcLabel.Text
		if ((Test-Path "$path\Gw2-64.exe")) {
			$arcDx9.Enabled = $enabledArc.Checked
			$arcDx11.Enabled = $enabledArc.Checked
		} else {
			$arcDx9.Enabled = $false
			$arcDx11.Enabled = $false
		}




		dings

			$pathBlish.Enabled = $false
	$pathBlishLabel.Enabled = $false
	$BlishRun.Enabled = $false
	#>
}

#build config

if (-not (Test-Path "$Script_path\GW2start.ini")) {
	$conf = @{}

	$forceGUI = $true
} else {
	$conf = Get-IniContent "$Script_path\GW2start.ini"
}

if ($conf.paths -eq $null) {
	$conf.main = @{}
	$conf.addons = @{}
	$conf.paths = @{}
	$conf.modules = @{}
	$conf.versions_main = @{}
	$conf.versions_addons = @{}
	$conf.versions_paths = @{}
	$conf.versions_modules = @{}

	$forceGUI = $true
}

if ($conf.paths.Guildwars2 -eq $null) {
	@(
		"C:\Program Files",
		"D:\Program Files",
		"E:\Program Files",
		"F:\Program Files",
		"C:\Games",
		"D:\Games",
		"E:\Games",
		"F:\Games",
		"C:",
		"D:",
		"E:",
		"F:"
	) | foreach {
		if (Test-Path ($_ + "\Guild Wars 2\Gw2-64.exe")) {
			$conf.paths.Guildwars2 = ($_ + "\Guild Wars 2")
		}
	}

	$forceGUI = $true
}

if (
	($conf.paths.TacO -eq $null) -or
	($conf.paths.BlishHUD -eq $null) -or

	($conf.installation_paths -ne $null) -or
	($conf.configuration -ne $null) -or
	($conf.settings_ArcDPS -ne $null) -or
	($conf.settings_BlishHUD -ne $null) -or
	($conf.settings_Mappacks)
) {
	$forceGUI = $true

	$conf.psobject.properties.remove('installation_paths')
	$conf.psobject.properties.remove('configuration')
	$conf.psobject.properties.remove('settings_ArcDPS')
	$conf.psobject.properties.remove('settings_BlishHUD')
	$conf.psobject.properties.remove('settings_Mappacks')
	$conf.psobject.properties.remove('versions')
}











if ($forceGUI) {
	do {
		$r = showGUI
	} while ($r -ne "OK")
}

exit

# now the real magic:

$GW2_path = $conf.installation_paths.Guildwars2
$TacO_path = $conf.installation_paths.TacO
$BlishHUD_path = $conf.installation_paths.BlishHUD

Clear-Host

stopprocesses

nls 7

###############################################################################################################################################################################################

$older = $false

if (Test-Path "$Script_path\github.json") {
	$older = $true
} else {
	nls 3
	Write-Host "To change any settings for this script checkout the GW2start.ini file located " -NoNewline
	Write-Host "$Script_path\GW2start.ini" -ForegroundColor White
}


# give message about GW2 build id
$checkurl = "https://api.guildwars2.com/v2/build"

Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
$new = $json.id

if (
	($conf.versions.GW2 -eq $null) -or
	($conf.versions.GW2 -ne $new)
) {
	Write-Host "Guildwars 2 " -NoNewline -ForegroundColor White
	Write-Host "will update itself to build $new" -ForegroundColor Green

	$conf["versions"]["GW2"] = $new
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
} else {
	Write-Host "Guildwars 2 " -NoNewline -ForegroundColor White
	Write-Host "is up-to-date"
}

removefile "$checkfile"


# auto update this script itself (prepare the update to be done by the .bat file with the next start)
removefile "$Script_path\GW2start.txt"
removefile "$Script_path\GW2start.bat"

Invoke-WebRequest "https://github.com/Tinsus/GW2-updater-script/raw/main/GW2start.bat" -OutFile "$Script_path/GW2start.bat"

Write-Host "GW2start.bat " -NoNewline -ForegroundColor White
Write-Host "is " -NoNewline
Write-Host "updated " -NoNewline -ForegroundColor Green
Write-Host "every time"


# auto update ArcDPS
if ($conf.configuration.update_ArcDPS) {
	$checkurl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"
	$targeturl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$new = (Get-Content "$checkfile" -Raw).Trim()

	if (
		($conf.versions.ArcDPS -eq $null) -or
		($conf.versions.ArcDPS -ne $new)
	) {
		Write-Host "ArcDPS " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$GW2_path\bin64\d3d9.dll"
		removefile "$GW2_path\bin64\d3d11.dll"
		removefile "$GW2_path\d3d9.dll"
		removefile "$GW2_path\d3d11.dll"

		$targetfile = "$GW2_path\d3d11.dll"

		if ($conf.settings_ArcDPS.dx9) {
			$targetfile = "$GW2_path\bin64\d3d9.dll"
		}

		Invoke-WebRequest "$targeturl" -OutFile "$targetfile"

		$conf["versions"]["ArcDPS"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "ArcDPS " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update TacO
if ($conf.configuration.update_TacO) {
	checkGithub

	newdir "$TacO_path"

	$checkurl = "https://api.github.com/repos/BoyC/GW2TacO/releases/latest"
	$targetfile = "$TacO_path\"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.node_id

	if (
		($conf.versions.TacO -eq $null) -or
		($conf.versions.TacO -ne $new) -or
		(-not (Test-Path "$targetfile\GW2TacO.exe"))
	) {
		Write-Host "TacO " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

		Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$targetfile" -Force
		removefile "$checkfile.temp.zip"

		$conf["versions"]["TacO"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "TacO " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update arcdps-killproof.me-plugin
if ($conf.configuration.update_ArcDPS -and $conf.settings_ArcDPS.killproof) {
	checkGithub

	$checkurl = "https://api.github.com/repos/knoxfighter/arcdps-killproof.me-plugin/releases/latest"
	$targetfile = "$GW2_path\bin64\d3d9_arcdps_killproof_me.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name

	if (
		($conf.versions.ArcDPS_killproof -eq $null) -or
		($conf.versions.ArcDPS_killproof -ne $new)
	) {
		Write-Host "ArcDps-killproof.me-plugin " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		$conf["versions"]["ArcDPS_killproof"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "ArcDps-killproof.me-plugin " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update arcdps-Boon-Table-plugin
if ($conf.configuration.update_ArcDPS -and $conf.settings_ArcDPS.boon_table) {
	checkGithub

	$checkurl = "https://api.github.com/repos/knoxfighter/GW2-ArcDPS-Boon-Table/releases/latest"
	$targetfile = "$GW2_path\bin64\d3d9_arcdps_table.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name

	if (
		($conf.versions.ArcDPS_boontable -eq $null) -or
		($conf.versions.ArcDPS_boontable -ne $new)
	) {
		Write-Host "GW2-ArcDps-Boon-Table " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		$conf["versions"]["ArcDPS_boontable"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "GW2-ArcDps-Boon-Table " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update arcdps-healing-stats
if ($conf.configuration.update_ArcDPS -and $conf.settings_ArcDPS.healing_stats) {
	checkGithub

	$checkurl = "https://api.github.com/repos/Krappa322/arcdps_healing_stats/releases/latest"
	$targetfile = "$GW2_path\bin64\arcdps_healing_stats.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name

	if (
		($conf.versions.ArcDPS_healingstats -eq $null) -or
		($conf.versions.ArcDPS_healingstats -ne $new)
	) {
		Write-Host "arcdps-healing-stats " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		$conf["versions"]["ArcDPS_healingstats"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "arcdps-healing-stats " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update GW2-ArcDPS-Mechanics-Log
if ($conf.configuration.update_ArcDPS -and $conf.settings_ArcDPS.mechanics_log) {
	checkGithub

	$checkurl = "https://api.github.com/repos/knoxfighter/GW2-ArcDPS-Mechanics-Log/releases/latest"
	$targetfile = "$GW2_path\bin64\d3d9_arcdps_mechanics.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name

	if (
		($conf.versions.ArcDPS_mechanicslog -eq $null) -or
		($conf.versions.ArcDPS_mechanicslog -ne $new)
	) {
		Write-Host "GW2-ArcDPS-Mechanics-Log " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$targetfile"
		Invoke-WebRequest $json.assets[0].browser_download_url -OutFile "$targetfile"

		$conf["versions"]["ArcDPS_mechanicslog"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "GW2-ArcDPS-Mechanics-Log " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update BlishHUD
if ($conf.configuration.update_BlishHUD) {
	newdir "$BlishHUD_path"
	newdir "$MyDocuments_path\Guild Wars 2"
	newdir "$MyDocuments_path\Guild Wars 2\addons"
	newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud"
	newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\markers"
	newdir "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/Blish-HUD/releases/latest"
	$targetfile = "$BlishHUD_path"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.node_id

	if (
		($conf.versions.BlishHUD -eq $null) -or
		($conf.versions.BlishHUD -ne $new) -or
		(-not (Test-Path "$targetfile\Blish HUD.exe"))
	) {
		Write-Host "BlishHUD " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.zip"

		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$targetfile\" -Force
		removefile "$checkfile.zip"

		$conf["versions"]["BlishHUD"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "BlishHUD " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update BlishHUD-ArcDPS Bridge
if ($conf.configuration.update_ArcDPS -and $conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.ArcDPS_Bridge) {
	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/arcdps-bhud/releases/latest"
	$targetfile = "$GW2_path\bin64\arcdps_bhud.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.node_id

	if (
		($conf.versions.BlishHUD_ArcDPS_Bridge -eq $null) -or
		($conf.versions.BlishHUD_ArcDPS_Bridge -ne $new)
	) {
		Write-Host "BlishHUD-ArcDPS Bridge " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url[1] -OutFile "$checkfile.zip"

		removefile "$targetfile"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$GW2_path\bin64\" -Force
		removefile "$checkfile.zip"

		$conf["versions"]["BlishHUD_ArcDPS_Bridge"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "BlishHUD-ArcDPS Bridge " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update BlishHUD-Modules

# Pathing
if ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Pathing) {
	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/Pathing/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $($json.tag_name).Substring(1)

	if (
		($conf.versions.BlishHUD_Pathing -eq $null) -or
		($conf.versions.BlishHUD_Pathing -ne $new)
	) {
		$old = 0

		if ($conf.versions.BlishHUD_Pathing -ne $null) {
			$old = $conf.versions.BlishHUD_Pathing
		}

		Write-Host "BlishHUD-Module Pathing " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$checkpath\bh.community.pathing_$old.bhm"
		removefile "$checkpath\Pathing_v$old.bhm"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\bh.community.pathing_$new.bhm"

		# enable this version
		enforceBHM "bh.community.pathing"

		$conf["versions"]["BlishHUD_Pathing"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "BlishHUD-Module Pathing " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# KillProof-Module
if ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.KillProof_Module) {
	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/KillProof-Module/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"
	$targetfile = "$checkpath\KillProof.bhm"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $($json.tag_name).Substring(1)

	if (
		($conf.versions.BlishHUD_KillProof_Module -eq $null) -or
		($conf.versions.BlishHUD_KillProof_Module -ne $new)
	) {
		Write-Host "BlishHUD-Module KillProof " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$targetfile"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$targetfile"

		# enable this version
		enforceBHM "KillProofModule"

		$conf["versions"]["BlishHUD_KillProof_Module"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "BlishHUD-Module KillProof " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# Quick-Surrender and/or Mistwar

if (
	($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Quick_Surrender) -or
	($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Mistwar)
) {
	checkGithub

	$checkurl = "https://api.github.com/repos/agaertner/Blish-HUD-Modules-Releases/releases"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$jsonb = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json

	$WantQuickSurrender = ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Quick_Surrender)
	$WantMistwar = ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Mistwar)

	# Quick-Surrender
	$jsonb | foreach-object {
		$json = $_

		$targeturl = ""

		$json.assets | foreach-object {
			if ($_.name -match "Surrender") {
				$targeturl = $_
			}
		}

		if (
			($targeturl -ne "") -and
			($WantQuickSurrender)
		) {
			$WantQuickSurrender = $false

			$new = $($targeturl.name)
			$new = $new.Substring($new.Length - 9, 5)
			$name = $targeturl.name
			$targeturl = $targeturl.browser_download_url

			if (
				($conf.versions.BlishHUD_QuickSurrender -eq $null) -or
				($conf.versions.BlishHUD_QuickSurrender -ne $new)
			) {
				$old = 0

				if ($conf.versions.BlishHUD_QuickSurrender -ne $null) {
					$old = $conf.versions.BlishHUD_QuickSurrender
				}

				Write-Host "BlishHUD-Module Quick-Surrender " -NoNewline -ForegroundColor White
				Write-Host "is being updated" -ForegroundColor Green

				# remove old version
				removefile "$checkpath\Nekres.Quick_Surrender_Module_$old.bhm"
				removefile "$checkpath\$name"

				#  get new version
				Invoke-WebRequest $targeturl -OutFile "$checkpath\Nekres.Quick_Surrender_Module_$new.bhm"

				# enable this version
				enforceBHM "Nekres.Quick_Surrender_Module"

				$conf["versions"]["BlishHUD_QuickSurrender"] = $new
				Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
			} else {
				Write-Host "BlishHUD-Module Quick-Surrender " -NoNewline -ForegroundColor White
				Write-Host "is up-to-date"
			}
		}
	}

	# Mistwar
	$jsonb | foreach-object {
		$json = $_

		$targeturl = ""

		$json.assets | foreach-object {
			if ($_.name -match "Mistwar") {
				$targeturl = $_
			}
		}

		if (
			($targeturl -ne "") -and
			($WantMistwar)
		) {
			$WantMistwar = $false

			$new = $($targeturl.name)
			$new = $new.Substring($new.Length - 9, 5)
			$name = $targeturl.name
			$targeturl = $targeturl.browser_download_url

			if (
				($conf.versions.BlishHUD_MistWar -eq $null) -or
				($conf.versions.BlishHUD_MistWar -ne $new)
			) {
				$old = 0

				if ($conf.versions.BlishHUD_MistWar -ne $null) {
					$old = $conf.versions.BlishHUD_MistWar
				}

				Write-Host "BlishHUD-Module Mistwar " -NoNewline -ForegroundColor White
				Write-Host "is being updated" -ForegroundColor Green

				# remove old version
				removefile "$checkpath\Nekres.Mistwar_$old.bhm"
				removefile "$checkpath\$name"

				#  get new version
				Invoke-WebRequest $targeturl -OutFile "$checkpath\Nekres.Mistwar_$new.bhm"

				# enable this version
				enforceBHM "Nekres.Mistwar"

				$conf["versions"]["BlishHUD_MistWar"] = $new
				Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
			} else {
				Write-Host "BlishHUD-Module Mistwar " -NoNewline -ForegroundColor White
				Write-Host "is up-to-date"
			}
		}
	}

	removefile "$checkfile"
}


# BlishHud-HPGrid
if ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.HPGrid) {
	checkGithub

	$checkurl = "https://api.github.com/repos/manlaan/BlishHud-HPGrid/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name
	$name = $json.assets.name

	if (
		($conf.versions.BlishHUD_HPGrid -eq $null) -or
		($conf.versions.BlishHUD_HPGrid -ne $new)
	) {
		$old = 0

		if ($conf.versions.BlishHUD_HPGrid -ne $null) {
			$old = $conf.versions.BlishHUD_HPGrid
		}

		Write-Host "BlishHUD-Module HPGrid " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$checkpath\Manlaan.HPGrid_$old.bhm"
		removefile "$checkpath\$name"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\Manlaan.HPGrid_$new.bhm"

		# enable this version
		enforceBHM "Manlaan.HPGrid"

		$conf["versions"]["BlishHUD_HPGrid"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "BlishHUD-Module HPGrid " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# BlishHud-Timers
if ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Timers) {
	checkGithub

	$checkurl = "https://api.github.com/repos/Dev-Zhao/Timers_BlishHUD/releases/latest"
	$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name
	$new = $new.Substring($new.Length - 5, 5)
	$name = $json.assets.name

	if (
		($conf.versions.BlishHUD_Timers -eq $null) -or
		($conf.versions.BlishHUD_Timers -ne $new)
	) {
		$old = 0

		if ($conf.versions.BlishHUD_Pathing -ne $null) {
			$old = $conf.versions.BlishHUD_Pathing
		}

		Write-Host "BlishHUD-Module Timers " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		# remove old version
		removefile "$checkpath\Charr.Timers_BlishHUD_$old.bhm"
		removefile "$checkpath\$name"

		#  get new version
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkpath\Charr.Timers_BlishHUD_$new.bhm"

		# enable this version
		enforceBHM "Charr.Timers_BlishHUD"

		$conf["versions"]["BlishHUD_Timers"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "BlishHUD-Module Timers " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update TEKKIT
if (
	($conf.configuration.update_ArcDPS -or ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Pathing)) -and
	($conf.settings_Mappacks.use_TacO -or $conf.settings_Mappacks.use_BlishHUD) -and
	$conf.settings_Mappacks.tekkit
) {
	$checkurl = "http://tekkitsworkshop.net/index.php/gw2-taco/changelog"
	$targeturl = "http://tekkitsworkshop.net/index.php/component/jdownloads/send/2-taco-marker-packs/32-all-in-one"
	$targetfile = "tw_ALL_IN_ONE.taco"

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$new = $(Get-FileHash "$checkfile" -Algorithm MD5).Hash

	if (
		(
			$conf.settings_Mappacks.use_TacO -and
			(
				($conf.versions.Mappack_T_tekkit -eq $null) -or
				($conf.versions.Mappack_T_tekkit -ne $new)
			)
		) -or (
			$conf.settings_Mappacks.use_BlishHUD -and
			(
				($conf.versions.Mappack_B_tekkit -eq $null) -or
				($conf.versions.Mappack_B_tekkit -ne $new)
			)
		)
	) {
		Write-Host "TEKKIT " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$checkfile"
		Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

		if ($conf.settings_Mappacks.use_BlishHUD) {
			removefile "$path_b"
			Copy-Item "$checkfile" -Destination "$path_b"

			$conf["versions"]["Mappack_B_tekkit"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}

		if ($conf.settings_Mappacks.use_TacO) {
			removefile "$path_t"
			Copy-Item "$checkfile" -Destination "$path_t"

			$conf["versions"]["Mappack_T_tekkit"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}
	} else {
		Write-Host "TEKKIT " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update SCHATTENFLUEGEL
if (
	($conf.configuration.update_ArcDPS -or ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Pathing)) -and
	($conf.settings_Mappacks.use_TacO -or $conf.settings_Mappacks.use_BlishHUD) -and
	$conf.settings_Mappacks.schattenfluegel
) {
	checkGithub

	$checkurl = "https://api.github.com/repos/Schattenfluegel/SchattenfluegelTrails/contents/Download"
	$targeturl = "https://github.com/Schattenfluegel/SchattenfluegelTrails/raw/main/Download/SchattenfluegelTrails.taco"
	$targetfile = "SchattenfluegelTrails.taco"

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$new = $(Get-FileHash "$checkfile" -Algorithm MD5).Hash

	if (
		(
			$conf.settings_Mappacks.use_TacO -and
			(
				($conf.versions.Mappack_T_schattenfluegel -eq $null) -or
				($conf.versions.Mappack_T_schattenfluegel -ne $new)
			)
		) -or (
			$conf.settings_Mappacks.use_BlishHUD -and
			(
				($conf.versions.Mappack_B_schattenfluegel -eq $null) -or
				($conf.versions.Mappack_B_schattenfluegel -ne $new)
			)
		)
	) {
		Write-Host "SCHATTENFLUEGEL " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$checkfile"
		Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

		if ($conf.settings_Mappacks.use_TacO) {
			removefile "$path_t"
			Copy-Item "$checkfile" -Destination "$path_t"

			$conf["versions"]["Mappack_T_schattenfluegel"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}

		if ($conf.settings_Mappacks.use_BlishHUD) {
			removefile "$path_b"
			Copy-Item "$checkfile" -Destination "$path_b"

			$conf["versions"]["Mappack_B_schattenfluegel"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}
	} else {
		Write-Host "SCHATTENFLUEGEL " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update HEROMARKERS
# update for BlishHUD (no TacO support)
if (
	($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Pathing) -and
	$conf.settings_Mappacks.use_BlishHUD -and
	$conf.settings_Mappacks.heromarkers
) {
	checkGithub

	$checkurl = "https://api.github.com/repos/QuitarHero/Heros-Marker-Pack/releases/latest"
	$targetfile = "Hero.Blish.Pack.zip"

	$path_b = path_b $targetfile

	removefile "$checkfile"
	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.node_id

	if (
		($conf.versions.Mappack_B_heromarkers -eq $null) -or
		($conf.versions.Mappack_B_heromarkers -ne $new)
	) {
		Write-Host "HEROMARKERS " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$path_b"
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$path_b"

		$conf["versions"]["Mappack_B_heromarkers"] = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "HEROMARKERS " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}


# auto update CZOKALAPIK
if (
	($conf.configuration.update_ArcDPS -or ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Pathing)) -and
	($conf.settings_Mappacks.use_TacO -or $conf.settings_Mappacks.use_BlishHUD) -and
	$conf.settings_Mappacks.czokalapik
) {
	$checkurl = "https://api.bitbucket.org/2.0/repositories/czokalapik/czokalapiks-guides-for-gw2taco/commits"
	$targeturl = "https://bitbucket.org/czokalapik/czokalapiks-guides-for-gw2taco/get"
	$targetfile = "czokalapiks-guides.taco"

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"
	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$hash = $($json.values[0].hash).Substring(0, 12)
	$new = $hash

	if (
		(
			$conf.settings_Mappacks.use_TacO -and
			(
				($conf.versions.Mappack_T_czokalapik -eq $null) -or
				($conf.versions.Mappack_T_czokalapik -ne $new)
			)
		) -or (
			$conf.settings_Mappacks.use_BlishHUD -and
			(
				($conf.versions.Mappack_B_czokalapik -eq $null) -or
				($conf.versions.Mappack_B_czokalapik -ne $new)
			)
		)
	) {
		Write-Host "CZOKALAPIK " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest "$targeturl/$hash.zip" -OutFile "$checkfile.zip"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$Script_path\" -Force
		removefile "$checkfile.zip"
		Compress-Archive -Path "$Script_path\czokalapik-czokalapiks-guides-for-gw2taco-$hash\POIs\*" -DestinationPath "$checkfile.zip"
		Remove-Item "$Script_path\czokalapik-czokalapiks-guides-for-gw2taco-$hash" -Recurse -force

		if ($conf.settings_Mappacks.use_TacO) {
			removefile "$conf.settings_Mappacks.use_TacO"
			Copy-Item "$checkfile.zip" -Destination "$path_t"

			$conf["versions"]["Mappack_T_czokalapik"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}

		if ($conf.settings_Mappacks.use_BlishHUD) {
			removefile "$conf.settings_Mappacks.use_BlishHUD"
			Copy-Item "$checkfile.zip" -Destination "$path_b"

			$conf["versions"]["Mappack_B_czokalapik"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}
	} else {
		Write-Host "CZOKALAPIK " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}

# auto update REACTIF
if (
	($conf.configuration.update_ArcDPS -or ($conf.configuration.update_BlishHUD -and $conf.settings_BlishHUD.Pathing)) -and
	($conf.settings_Mappacks.use_TacO -or $conf.settings_Mappacks.use_BlishHUD) -and
	$conf.settings_Mappacks.reactif
) {
	$targeturl = "https://www.heinze.fr/taco/download.php?f=3"
	$targetfile = "reactif_en.taco"

	$new = Select-Xml -Content ((Invoke-WebRequest "https://heinze.fr/taco/rss-en.xml").Content) -XPath "//item/pubDate" | Select-Object -First 1 | foreach-object { $_.node.InnerXML }

	$path_t = path_t $targetfile
	$path_b = path_b $targetfile

	if (
		(
			$conf.settings_Mappacks.use_TacO -and
			(
				($conf.versions.Mappack_T_reactif -eq $null) -or
				($conf.versions.Mappack_T_reactif -ne $new)
			)
		) -or (
			$conf.settings_Mappacks.use_BlishHUD -and
			(
				($conf.versions.Mappack_B_reactif -eq $null) -or
				($conf.versions.Mappack_B_reactif -ne $new)
			)
		)
	) {
		Write-Host "REACTIF " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$checkfile"
		Invoke-WebRequest "$targeturl" -OutFile "$checkfile"

		if ($conf.configuration.start_TacO) {
			removefile "$path_t"
			Copy-Item "$checkfile" -Destination "$path_t"

			$conf["versions"]["Mappack_T_reactif"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}

		if ($conf.settings_Mappacks.use_BlishHUD) {
			removefile "$path_b"
			Copy-Item "$checkfile" -Destination "$path_b"

			$conf["versions"]["Mappack_B_reactif"] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		}
	} else {
		Write-Host "REACTIF " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}

	removefile "$checkfile"
}

# cleanup for older version of this script

removefile "$Script_path/LICENSE"
removefile "$Script_path/README.md"
Remove-Item "$Script_path/version_control/" -Recurse -force -ErrorAction SilentlyContinue

# done with updating

if (-not $older) {
	startGW2
	stopprocesses
}

removefile "$Script_path\github.json"


nls 1
Write-Host "see you soon"

Start-Sleep -Seconds 2
