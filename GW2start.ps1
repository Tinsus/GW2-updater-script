param($forceGUIfromBat = "")

#TODO:
# scan für zeug, dass nicht von dem Script verwaltet wird [ignore in config]

# times für das timers module mitverwalten
# Warnung, wenn die Grafikeinstellungen falsch sind (geht einfach) und arc oder blish laufen
# als multithread: taco im installordner suchen, blishhud schauen, ob im documents ordner und dann pfad finden
# info, das repots gezogen werden
# setting, logindscreeninfo und autologin (als hidden setting ohne ui in der ini?)
# github prio nach datum des letzten scans
# die daten in das Timers-Module rein patchen

# Frage, ob ArcDPS gelöscht werden soll, wenn das game nach so 5 mins geschlossen wird (mit hash zum nur einmal fragen) [muss das noch? oder ist das jetzt besser geschützt?]

Add-Type -assembly System.Windows.Forms

$MyDocuments_path = [Environment]::GetFolderPath("MyDocuments")
$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$checkfile = "$Script_path\checkfile"

function stopprocesses() {
	if ($conf.main.runTaco) {
		Stop-Process -Name "GW2TacO" -ErrorAction SilentlyContinue
	}

	if ($conf.main.runBlish) {
		Stop-Process -Name "Blish HUD" -ErrorAction SilentlyContinue
	}

	if ($conf.main.enabledArc) {
		Stop-Process -Name "RazerCortex" -ErrorAction SilentlyContinue
	}

	Stop-Process -Name "Gw2-64" -ErrorAction SilentlyContinue
}

function removefile($path) {
	Remove-Item "$path" -ErrorAction SilentlyContinue
}

function newdir($path) {
	New-Item "$path" -ItemType Directory -ErrorAction SilentlyContinue
}

function startGW2() {
	# start TacO
	if ($conf.main.runTaco) {
		Start-Process -FilePath "$TacO_path\GW2TacO.exe" -WorkingDirectory "$TacO_path\" -ErrorAction SilentlyContinue
	}

	# start BlishHUD
	if ($conf.main.runBlish) {
		Start-Process -FilePath "$BlishHUD_path\Blish HUD.exe" -WorkingDirectory "$BlishHUD_path\" -ErrorAction SilentlyContinue
	}

	# start Guild Wars 2
	nls 2
	Write-Host "have fun in Guild Wars 2"

	if (($conf.main.hideinfo -eq $null) -and ($conf.main.nologin -eq $null)) {
		Start-Process -FilePath "$GW2_path\Gw2-64.exe" -WorkingDirectory "$GW2_path\" -ArgumentList '-autologin', '-bmp', '-mapLoadInfo' -wait -RedirectStandardError "$GW2_path\errorautocheck.txt"
	} elseif ($conf.main.hideinfo -eq $null) {
		Start-Process -FilePath "$GW2_path\Gw2-64.exe" -WorkingDirectory "$GW2_path\" -ArgumentList '-bmp', '-mapLoadInfo' -wait -RedirectStandardError "$GW2_path\errorautocheck.txt"
	} elseif ($conf.main.nologin -eq $null) {
		Start-Process -FilePath "$GW2_path\Gw2-64.exe" -WorkingDirectory "$GW2_path\" -ArgumentList '-bmp', '-autologin' -wait -RedirectStandardError "$GW2_path\errorautocheck.txt"
	}

	# if GW2 has an update removes ArcDPS
	if ($configuration.main.enabledArc -and (Test-Path "$GW2_path\errorautocheck.txt") -and ((Get-Item "$GW2_path\errorautocheck.txt").length -ne 0)) {
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

function path_a($key, $value) {
	$targetpath = "$GW2_path\addons"

	switch($key) {
		"GWRadialDD" {
			$targetpath = "$targetpath\gw2radial_d3d9"

			break
		}
		"GWRadial" {
			$targetpath = "$targetpath\gw2radial"

			break
		}
		default {
			switch($value.install_mode) {
				"arc" {
					$targetpath = "$GW2_path\addons\arcdps"

					if ($value.plugin_name -ne $null) {
						$targetpath = "$targetpath\" + $value.plugin_name
					}

					if ($value.host_type -eq "standalone") {
						$targetpath = "$targetpath\d3d9_arcdps_" + $value.addon_name + ".dll"
					}

					break
				}
				"binary" {
					$targetpath = "$targetpath\" + $key
				}

			}

		}
	}

	return $targetpath
}

function nls($total) {
	for ($i = 0; $i -lt $total; $i++) {
		Write-Host " "
	}
}

function checkGithub() {
	# check githubs API restrictions and waits until it's possible again
	Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"
	$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json
	removefile "$Script_path\github.json"

	if ($json.rate.remaining -lt 1) {
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

		startGW2
		stopprocesses

		nls 1
		Write-Host "OK - we will wait until the updates are possible again. You can close this window everytime. No data will be damaged or deleted." -ForegroundColor Yellow
		nls 1

		do {
			Start-Sleep -Seconds 60

			Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"
			$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json
			removefile "$Script_path\github.json"
		} until ($json.rate.remaining -ge 1)
	}
}

function checkGithubLite() {
	# check githubs API restrictions and waits until it's possible again
	Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"
	$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json
	removefile "$Script_path\github.json"

	if ($json.rate.remaining -lt 1) {
		$date = (Get-Date -Date "1970-01-01 00:00:00Z").toLocalTime().addSeconds($json.rate.reset)

		nls 3
		Write-Host "No more updates possible due to API limitations by github.com :(" -ForegroundColor Red
		nls 1
		Write-Host "The restrictions will be lifted on:"
		Write-Host $date -ForegroundColor Yellow
		nls 1
		Write-Host "Sorry for that."
		nls 2
		Write-Host "This script can't start doing anything now. So we need to wait until the updates are possible again."
		nls 2
		Write-Host "You can close this window everytime. No data will be damaged or deleted." -ForegroundColor Yellow
		nls 1

		do {
			Start-Sleep -Seconds 60

			Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"
			$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json
			removefile "$Script_path\github.json"
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

			if (($value -eq "True") -or ($value -eq "False")) {
				$value = ($value -eq "True")
			}

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
	Write-Host "Generating default files. This takes about 15 seconds." -ForegroundColor DarkGray
	Start-Process -FilePath "$BlishHUD_path\Blish HUD.exe" -WorkingDirectory "$BlishHUD_path\" -ErrorAction SilentlyContinue
	Start-Sleep -Seconds 18
	Stop-Process -Name "Blish HUD" -ErrorAction SilentlyContinue

	#modify settings.json
	if ($modulename -ne $null) {
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

function placingGUI {
	$max = (@($form.groupBlish.Height, $form.groupArc.Height, $form.groupTaco.Height) | measure -Maximum).Maximum

	$form.groupBlish.Height = $max
	$form.groupTaco.Height = $max
	$form.groupArc.Height = $max

	$max = (@($form.groupTaco.Width, $form.groupBlish.Width, $form.groupAddons.Width, $form.groupPaths.Width, $form.groupModules.Width, $form.groupArc.Width) | measure -Maximum).Maximum

	$form.groupTaco.Width = $max
	$form.groupBlish.Width = $max
	$form.groupAddons.Width = $max
	$form.groupPaths.Width = $max
	$form.groupModules.Width = $max
	$form.groupArc.Width = $max

	$form.groupTaco.Location = New-Object System.Drawing.Size(($form.groupArc.Location.X + $form.groupArc.Width + 10) , $form.groupArc.Location.Y)
	$form.groupBlish.Location = New-Object System.Drawing.Size(($form.groupTaco.Location.X + $form.groupTaco.Width + 10) , $form.groupArc.Location.Y)

	$form.groupAddons.Location = New-Object System.Drawing.Size(($form.groupArc.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))
	$form.groupPaths.Location = New-Object System.Drawing.Size(($form.groupTaco.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))
	$form.groupModules.Location = New-Object System.Drawing.Size(($form.groupBlish.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))

	$x = $form.groupTaco.Width * 1.5 + $form.groupTaco.x -35
	$y = (@($form.groupArc.Height, $form.groupBlish.Height, $form.groupTaco.Height) | measure -Maximum).Maximum + (@($form.groupAddons.Height, $form.groupPaths.Height, $form.groupModules.Height) | measure -Maximum).Maximum + $form.groupArc.y + 60

    $form.close.Location = New-Object System.Drawing.Size($x, $y)
    $form.reset.Location = New-Object System.Drawing.Size(($x - 100), $y)
}

function showGUI {
# prepare stuff
	$form.main_form = New-Object System.Windows.Forms.Form

	$form.tooltip = New-Object System.Windows.Forms.ToolTip
	$form.tooltip.AutoPopDelay = 30000;
	$form.tooltip.InitialDelay = 100;
	$form.tooltip.ReshowDelay = 500;

	$form.main_form.Text ='Config GW2start script'
	$form.main_form.AutoSize = $true
	$form.main_form.AutoSizeMode = 1

	$form.descriptionMain = New-Object System.Windows.Forms.Label
	$form.descriptionMain.Text = "Here you can config the GW2start script to your own need. This config shows up when new options are available.
	You can open this setting using the GW2start-config.bat placed next to your usual GW2start.bat"
	$form.descriptionMain.Location  = New-Object System.Drawing.Point(10, 10)
	$form.descriptionMain.AutoSize = $true
	$form.main_form.Controls.Add($form.descriptionMain)

# ARCDPS
	$form.groupArc = New-Object System.Windows.Forms.GroupBox
	$form.groupArc.Location = New-Object System.Drawing.Size(10, 40)
	$form.groupArc.AutoSize = $true
	$form.groupArc.AutoSizeMode = 1
	$form.groupArc.text = "ArcDPS"

	$form.descriptionArc = New-Object System.Windows.Forms.Label
	$form.descriptionArc.Text = "DPS meter with great expandability"
	$form.descriptionArc.Location = New-Object System.Drawing.Point(10, 15)
	$form.descriptionArc.AutoSize = $true
	$form.groupArc.Controls.Add($form.descriptionArc)

	$form.enabledArc = New-Object System.Windows.Forms.CheckBox
	$form.enabledArc.Text = "install + update"
	$form.enabledArc.Location = New-Object System.Drawing.Point(10, 30)
	$form.enabledArc.Add_CheckStateChanged({
		changeGUI -category "enable" -key "arc" -value $this.checked
	})
	$form.groupArc.Controls.Add($form.enabledArc)

	$form.pathArc = New-Object System.Windows.Forms.Button
	$form.pathArc.Location = New-Object System.Drawing.Size(10, 55)
	$form.pathArc.Size = New-Object System.Drawing.Size(50, 20)
	$form.pathArc.Text = "Edit"
	$form.pathArc.Add_Click({
		changeGUI -category "path" -key "arc"
	})
	$form.groupArc.Controls.Add($form.pathArc)

	$form.pathArcLabel = New-Object System.Windows.Forms.Label
	$form.pathArcLabel.Location = New-Object System.Drawing.Point(62, 58)
	$form.pathArcLabel.AutoSize = $true
	$form.pathArcLabel.Add_Click({
		changeGUI -category "path" -key "arc"
	})
	$form.groupArc.Controls.Add($form.pathArcLabel)

	$form.main_form.Controls.Add($form.groupArc)

# TACO
	$form.groupTaco = New-Object System.Windows.Forms.GroupBox
	$form.groupTaco.Location = New-Object System.Drawing.Size(($form.groupArc.Location.X + $form.groupArc.Width + 10) , $form.groupArc.Location.Y)
	$form.groupTaco.AutoSize = $true
	$form.groupTaco.AutoSizeMode = 1
	$form.groupTaco.text = "TacO"

	$form.descriptionTaco = New-Object System.Windows.Forms.Label
	$form.descriptionTaco.Text = "Oldschool tool best known for map paths"
	$form.descriptionTaco.Location = New-Object System.Drawing.Point(10, 15)
	$form.descriptionTaco.AutoSize = $true
	$form.groupTaco.Controls.Add($form.descriptionTaco)

	$form.enabledTaco = New-Object System.Windows.Forms.CheckBox
	$form.enabledTaco.Text = "install + update"
	$form.enabledTaco.Location = New-Object System.Drawing.Point(10, 30)
	$form.enabledTaco.Add_CheckStateChanged({
		changeGUI -category "enable" -key "taco" -value $this.checked
	})
	$form.groupTaco.Controls.Add($form.enabledTaco)

	$form.pathTaco = New-Object System.Windows.Forms.Button
	$form.pathTaco.Location = New-Object System.Drawing.Size(10, 55)
	$form.pathTaco.Size = New-Object System.Drawing.Size(50, 20)
	$form.pathTaco.Text = "Edit"
	$form.pathTaco.Add_Click({
		changeGUI -category "path" -key "taco"
	})
	$form.groupTaco.Controls.Add($form.pathTaco)

	$form.pathTacoLabel = New-Object System.Windows.Forms.Label
	$form.pathTacoLabel.Location = New-Object System.Drawing.Point(62, 58)
	$form.pathTacoLabel.AutoSize = $true
	$form.pathTacoLabel.Add_Click({
		changeGUI -category "path" -key "taco"
	})
	$form.groupTaco.Controls.Add($form.pathTacoLabel)

	$form.TacoRun = New-Object System.Windows.Forms.CheckBox
	$form.TacoRun.Text = "auto start"
	$form.TacoRun.Size = New-Object System.Drawing.Point(200, 20)
	$form.TacoRun.Location = New-Object System.Drawing.Point(10, 80)
	$form.TacoRun.Add_CheckStateChanged({
		changeGUI -category "auto" -key "taco" -value $this.checked
	})
	$form.tooltip.SetToolTip($form.TacoRun, "Should TacO start automaticly when using this script?")
	$form.groupTaco.Controls.Add($form.TacoRun)

	$form.main_form.Controls.Add($form.groupTaco)

# BLISH
	$form.groupBlish = New-Object System.Windows.Forms.GroupBox
	$form.groupBlish.Location = New-Object System.Drawing.Size(($form.groupTaco.Location.X + $form.groupTaco.Width + 10) , $form.groupArc.Location.Y)
	$form.groupBlish.AutoSize = $true
	$form.groupBlish.AutoSizeMode = 1
	$form.groupBlish.text = "Blish HUD"

	$form.descriptionBlish = New-Object System.Windows.Forms.Label
	$form.descriptionBlish.Text = "Modern tool, better and bigger than TacO"
	$form.descriptionBlish.Location = New-Object System.Drawing.Point(10, 15)
	$form.descriptionBlish.AutoSize = $true
	$form.groupBlish.Controls.Add($form.descriptionBlish)

	$form.enabledBlish = New-Object System.Windows.Forms.CheckBox
	$form.enabledBlish.Text = "install + update"
	$form.enabledBlish.Location = New-Object System.Drawing.Point(10, 30)
	$form.enabledBlish.Add_CheckStateChanged({
		changeGUI -category "enable" -key "blish" -value $this.checked
	})
	$form.groupBlish.Controls.Add($form.enabledBlish)

	$form.pathBlish = New-Object System.Windows.Forms.Button
	$form.pathBlish.Location = New-Object System.Drawing.Size(10, 55)
	$form.pathBlish.Size = New-Object System.Drawing.Size(50, 20)
	$form.pathBlish.Text = "Edit"
	$form.pathBlish.Add_Click({
		changeGUI -category "path" -key "blish"
	})
	$form.groupBlish.Controls.Add($form.pathBlish)

	$form.pathBlishLabel = New-Object System.Windows.Forms.Label
	$form.pathBlishLabel.Location = New-Object System.Drawing.Point(62, 58)
	$form.pathBlishLabel.AutoSize = $true
	$form.pathBlishLabel.Add_Click({
		changeGUI -category "path" -key "blish"
	})
	$form.groupBlish.Controls.Add($form.pathBlishLabel)

	$form.BlishRun = New-Object System.Windows.Forms.CheckBox
	$form.BlishRun.Text = "auto start"
	$form.BlishRun.Size = New-Object System.Drawing.Point(200, 20)
	$form.BlishRun.Location = New-Object System.Drawing.Point(10, 80)
	$form.BlishRun.Add_CheckStateChanged({
		changeGUI -category "auto" -key "blish" -value $this.checked
	})
	$form.tooltip.SetToolTip($form.BlishRun, "Should Blish HUD start automaticly when using this script?")
	$form.groupBlish.Controls.Add($form.BlishRun)

	$form.main_form.Controls.Add($form.groupBlish)

# ARCDPS ADDONS
	$form.groupAddons = New-Object System.Windows.Forms.GroupBox
	$form.groupAddons.Location = New-Object System.Drawing.Size(($form.groupArc.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))
	$form.groupAddons.AutoSize = $true
	$form.groupAddons.AutoSizeMode = 1
	$form.groupAddons.text = "ArcDPS Addons"

	$i = 0
	$modules.ArcDPS.GetEnumerator() | foreach {
		$modules.ArcDPS[$_.key]["UI"] = New-Object System.Windows.Forms.CheckBox
		$modules.ArcDPS[$_.key]["UI"].Text = ($(if ($_.value.default) { "* " } else { "" }) + $_.value.addon_name)
		$modules.ArcDPS[$_.key]["UI"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.ArcDPS[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (20 * $i)))
		$modules.ArcDPS[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 20)
		$modules.ArcDPS[$_.key]["UI"].Add_CheckStateChanged({
			changeGUI -category "addons" -key $this.Value -value $this.checked
		})
		$form.tooltip.SetToolTip($modules.ArcDPS[$_.key]["UI"], $_.value.description)
		$form.groupAddons.Controls.Add($modules.ArcDPS[$_.key]["UI"])

		$i++
	}

	$form.main_form.Controls.Add($form.groupAddons)

# PATHS
	$form.groupPaths = New-Object System.Windows.Forms.GroupBox
	$form.groupPaths.Location = New-Object System.Drawing.Size(($form.groupTaco.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))
	$form.groupPaths.AutoSize = $true
	$form.groupPaths.AutoSizeMode = 1
	$form.groupPaths.text = "Paths for Blish HUD and TacO"

	$i = 0

	$modules.Path.GetEnumerator() | foreach {
		$modules.Path[$_.key]["UI"] = New-Object System.Windows.Forms.Label
		$modules.Path[$_.key]["UI"].Text = $_.value.name
		$modules.Path[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (40 * $i)))
		$modules.Path[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 15)
		$form.tooltip.SetToolTip($modules.Path[$_.key]["UI"], $_.value.desc)
		$form.groupPaths.Controls.Add($modules.Path[$_.key]["UI"])

		$modules.Path[$_.key]["UI1"] = New-Object System.Windows.Forms.CheckBox
		$modules.Path[$_.key]["UI1"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.Path[$_.key]["UI1"].Text =  ($(if ($_.value.default) { "* " } else { "" }) + "Blish HUD")
		$modules.Path[$_.key]["UI1"].Location = New-Object System.Drawing.Point(30, (35 + (40 * $i)))
		$modules.Path[$_.key]["UI1"].Size = New-Object System.Drawing.Point(90, 20)
		$modules.Path[$_.key]["UI1"].Add_CheckStateChanged({
			changeGUI -category "blish" -key $this.value -value $this.checked
		})
		$form.tooltip.SetToolTip($modules.Path[$_.key]["UI1"], $_.value.desc)
		$form.groupPaths.Controls.Add($modules.Path[$_.key]["UI1"])

		$modules.Path[$_.key]["UI2"] = New-Object System.Windows.Forms.CheckBox
		$modules.Path[$_.key]["UI2"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.Path[$_.key]["UI2"].Text = "TacO"
		$modules.Path[$_.key]["UI2"].Location = New-Object System.Drawing.Point(130, (35 + (40 * $i)))
		$modules.Path[$_.key]["UI2"].Size = New-Object System.Drawing.Point(80, 20)
		$modules.Path[$_.key]["UI2"].Add_CheckStateChanged({
			changeGUI -category "taco" -key $this.value -value $this.checked
		})
		if ($_.value.blishonly) {
			$modules.Path[$_.key]["UI2"].Visible = $false
		}
		$form.tooltip.SetToolTip($modules.Path[$_.key]["UI2"], $_.value.desc)
		$form.groupPaths.Controls.Add($modules.Path[$_.key]["UI2"])

		$i++
	}

	#$form.main_form.Topmost = $true
	$form.main_form.Controls.Add($form.groupPaths)

# BLISH MODULES
	$form.groupModules = New-Object System.Windows.Forms.GroupBox
	$form.groupModules.Location = New-Object System.Drawing.Size(($form.groupBlish.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))
	$form.groupModules.AutoSize = $true
	$form.groupModules.AutoSizeMode = 1
	$form.groupModules.text = "Blish HUD modules"

	$i = 0
	$modules.BlishHUD.GetEnumerator() | foreach {
		$modules.BlishHUD[$_.key]["UI"] = New-Object System.Windows.Forms.CheckBox
		$modules.BlishHUD[$_.key]["UI"].Text = ($(if ($_.value.default) { "* " } else { "" }) + $_.value.name)
		$modules.BlishHUD[$_.key]["UI"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.BlishHUD[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (20 * $i)))
		$modules.BlishHUD[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 20)
		$modules.BlishHUD[$_.key]["UI"].Add_CheckStateChanged({
			changeGUI -category "module" -key $this.Value -value $this.checked
		})
		$form.tooltip.SetToolTip($modules.BlishHUD[$_.key]["UI"], $_.value.desc)
		$form.groupModules.Controls.Add($modules.BlishHUD[$_.key]["UI"])

		$i++
	}

	$form.main_form.Controls.Add($form.groupModules)

# STUFF
    $form.close = New-Object System.Windows.Forms.Button
    $form.close.Size = New-Object System.Drawing.Size(70, 40)
    $form.close.Text = "Save and Run"
    $form.close.DialogResult = "OK"
	$form.close.Add_Click({
		changeGUI -category "save" -key "ok" -value $false
	})
    $form.main_form.Controls.Add($form.close)

    $form.reset = New-Object System.Windows.Forms.Button
    $form.reset.Size = New-Object System.Drawing.Size(70, 40)
    $form.reset.Text = "Reload all"
    $form.reset.DialogResult = "OK"
	$form.reset.Add_Click({
		changeGUI -category "save" -key "reset" -value $false
	})
    $form.main_form.Controls.Add($form.reset)

	placingGUI

	validateGUI

	$initGUI = $false
	$form.main_form.ShowDialog()
}

function validateGUI {
# ARCDPS
	if ($conf.main.enabledArc -eq $null) {
		$form.enabledArc.Checked = $true
		$form.pathArc.Enabled = $true
		$form.pathArcLabel.Enabled = $true
	} else {
		$form.enabledArc.Checked = $conf.main.enabledArc
		$form.pathArc.Enabled = $conf.main.enabledArc
		$form.pathArcLabel.Enabled = $conf.main.enabledArc
	}

	if ($conf.main.pathArc -eq $null) {
		$form.pathArcLabel.Text = "Select installation path first"
	} else {
		$form.pathArcLabel.Text = $conf.main.pathArc
	}

	$validArc = (Test-Path ($form.pathArcLabel.Text + "\Gw2-64.exe"))

# TACO
	if ($conf.main.enabledTaco -eq $null) {
		$form.enabledTaco.checked = $true
		$form.pathTaco.enabled = $true
		$form.pathTacoLabel.enabled = $true
	} else {
		$form.enabledTaco.checked = $conf.main.enabledTaco
		$form.pathTaco.enabled = $conf.main.enabledTaco
		$form.pathTacoLabel.enabled = $conf.main.enabledTaco
	}

	if ($conf.main.pathTaco -eq $null) {
		$form.pathTacoLabel.Text = "Select installation path first"
	} else {
		$form.pathTacoLabel.Text = $conf.main.pathTaco
	}

	$validTaco = ((Test-Path ($form.pathTacoLabel.Text + "\GW2TacO.exe")) -or ((Test-Path $form.pathTacoLabel.Text) -and (Get-ChildItem $form.pathTacoLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })))

	$form.TacoRun.enabled = ($validTaco -and $form.enabledTaco.Checked)

	if ($conf.main.runTaco -eq $null) {
		$form.TacoRun.Checked = $false
	} else {
		$form.TacoRun.Checked = $conf.main.runTaco
	}

# BLISH
	if ($conf.main.enabledBlish -eq $null) {
		$form.enabledBlish.checked = $true
		$form.pathBlish.enabled = $true
		$form.pathBlishLabel.enabled = $true
	} else {
		$form.enabledBlish.checked = $conf.main.enabledBlish
		$form.pathBlish.enabled = $conf.main.enabledBlish
		$form.pathBlishLabel.enabled = $conf.main.enabledBlish
	}

	if ($conf.main.pathBlish -eq $null) {
		$form.pathBlishLabel.Text = "Select installation path first"
	} else {
		$form.pathBlishLabel.text = $conf.main.pathBlish
	}

	$validBlish = ((Test-Path ($form.pathBlishLabel.Text + "\Blish HUD.exe")) -or ((Test-Path $form.pathBlishLabel.Text) -and (Get-ChildItem $form.pathBlishLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })))

	$form.BlishRun.enabled = ($validBlish -and $form.enabledBlish.Checked)

	if ($conf.main.runBlish -eq $null) {
		$form.BlishRun.Checked = $true
	} else {
		$form.BlishRun.Checked = $conf.main.runBlish
	}

# ARCDPS ADDONS
	$modules.ArcDPS.GetEnumerator() | foreach {
		$modules.ArcDPS[$_.key]["UI"].enabled = ($validArc -and $form.enabledArc.checked)

		if ($conf.addons[$_.key] -eq $null) {
			$modules.ArcDPS[$_.key]["UI"].checked = $_.value.default
		} else {
			$modules.ArcDPS[$_.key]["UI"].checked = $conf.addons[$_.key]
		}
	}

	$modules.ArcDPS.GetEnumerator() | foreach {
		if (
			($modules.ArcDPS[$_.key].requires -ne $null) -and
			($modules.ArcDPS[$_.key]["UI"].checked -eq $true)
		) {
			$modules.ArcDPS[$_.key].requires | foreach {
				$req = $_ -replace '[^a-zA-Z]', ''

				if ($modules.ArcDPS[$req] -ne $null) {
					$modules.ArcDPS[$req]["UI"].checked = $true
					$modules.ArcDPS[$req]["UI"].enabled = $false
				}
			}
		}
	}

# BLISH MODULES
	$modules.BlishHUD.GetEnumerator() | foreach {
		$modules.BlishHUD[$_.key]["UI"].enabled = ($form.enabledBlish.Checked -and $validBlish)

		if ($conf.modules[$_.key] -eq $null) {
			$modules.BlishHUD[$_.key]["UI"].checked = $_.value.default
		} else {
			$modules.BlishHUD[$_.key]["UI"].checked = $conf.modules[$_.key]
		}
	}

# PATHS
	$modules.Path.GetEnumerator() | foreach {
		$modules.Path[$_.key]["UI"].enabled = $false
		$modules.Path[$_.key]["UI1"].enabled = $false

		if (-not $_.value.blishonly) {
			$modules.Path[$_.key]["UI2"].enabled = $false
		}

		if ($validBlish -and $form.enabledBlish.checked) {
			$modules.Path[$_.key]["UI"].enabled = $true
			$modules.Path[$_.key]["UI1"].enabled = $true
		}

		if ($conf.paths[$_.key + "_blish"] -eq $null) {
			$modules.Path[$_.key]["UI1"].checked = $_.value.default
		} else {
			$modules.Path[$_.key]["UI1"].checked = $conf.paths[$_.key + "_blish"]
		}

		if ($validTaco -and $form.enabledTaco.checked -and (-not $_.value.blishonly)) {
			$modules.Path[$_.key]["UI"].enabled = $true
			$modules.Path[$_.key]["UI2"].enabled = $true
		}

		if ($conf.paths[$_.key + "_taco"] -eq $null) {
			$modules.Path[$_.key]["UI2"].checked = $false
		} else {
			$modules.Path[$_.key]["UI2"].checked = $conf.paths[$_.key + "_taco"]
		}

		if ($modules.Path[$_.key].conflicts -ne $null) {
			$modules.Path[$_.key]["UI1"].enabled = (-not ($conf.paths[$modules.Path[$_.key].conflicts + "_blish"]) -or ($modules.Path[$modules.Path[$_.key].conflicts]["UI2"].checked))
			$modules.Path[$_.key]["UI2"].enabled = (-not ($conf.paths[$modules.Path[$_.key].conflicts + "_taco"]) -or ($modules.Path[$modules.Path[$_.key].conflicts]["UI1"].checked))
		}
	}

	placingGUI
}

function changeGUI($category, $key = 0, $value = 0) {
	if ($initGUI) {
		return
	}

	switch($category) {
		"save" {
			switch($key) {
				"reset" {
					$conf.versions_paths.Keys | foreach {
						$conf.versions_paths[$_] = 0
					}
					$conf.versions_main.Keys | foreach {
						$conf.versions_main[$_] = 0
					}
					$conf.versions_addons.Keys | foreach {
						$conf.versions_addons[$_] = 0
					}
					$conf.versions_modules.Keys | foreach {
						$conf.versions_modules[$_] = 0
					}

					$conf.ignore = @{}
				}
				"ok" {
					$conf.main.pathArc = $form.pathArcLabel.Text
					$conf.main.pathTaco = $form.pathTacoLabel.Text
					$conf.main.pathBlish = $form.pathBlishLabel.Text

					$conf.main.enabledArc = $form.enabledArc.checked
					$conf.main.enabledTaco = $form.enabledTaco.checked
					$conf.main.enabledBlish = $form.enabledBlish.checked

					$conf.main.runTaco = $form.TacoRun.Checked
					$conf.main.runBlish = $form.BlishRun.Checked

					$modules.ArcDPS.GetEnumerator() | foreach {
						$conf.addons[$_.key] = $modules.ArcDPS[$_.key]["UI"].checked
					}

					$modules.BlishHUD.GetEnumerator() | foreach {
						$conf.modules[$_.key] = $modules.BlishHUD[$_.key]["UI"].checked
					}

					$modules.Path.GetEnumerator() | foreach {
						$conf.paths[$_.key + "_blish"] = $modules.Path[$_.key]["UI1"].checked
						$conf.paths[$_.key + "_taco"] = $modules.Path[$_.key]["UI2"].checked
					}

					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"

					break
				}
			}
		}
		"enable" {
			switch($key) {
				"arc" {
					$form.pathArc.enabled = $value
					$form.pathArcLabel.enabled = $value

					if (Test-Path ($form.pathArcLabel.Text + "\Gw2-64.exe")) {
						$modules.ArcDPS.GetEnumerator() | foreach {
							$modules.ArcDPS[$_.key]["UI"].enabled = $value

							if (
								($modules.ArcDPS[$_.key].requires -ne $null) -and
								($modules.ArcDPS[$_.key]["UI"].checked -eq $true)
							) {
								$modules.ArcDPS[$_.key].requires | foreach {
									$req = $_ -replace '[^a-zA-Z]', ''

									if ($modules.ArcDPS[$req] -ne $null) {
										$modules.ArcDPS[$req]["UI"].checked = $true
										$modules.ArcDPS[$req]["UI"].enabled = $false
									}
								}
							}
						}
					} else {
						$modules.ArcDPS.GetEnumerator() | foreach {
							$modules.ArcDPS[$_.key]["UI"].enabled = $false
						}
					}

					break
				}

				"blish" {
					$form.pathBlish.enabled = $value
					$form.pathBlishLabel.enabled = $value

					$validBlish = ((Test-Path ($form.pathBlishLabel.Text + "\Blish HUD.exe")) -or ((Test-Path ($form.pathBlishLabel.Text + "\Blish HUD.exe")) -and (Get-ChildItem $form.pathBlishLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })))
					$validTaco = ((Test-Path ($form.pathTacoLabel.Text + "\GW2TacO.exe")) -or ((Test-Path $form.pathTacoLabel.Text) -and (Get-ChildItem $form.pathTacoLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })))

					$form.BlishRun.enabled = ($validBlish -and $value)

					$modules.BlishHUD.GetEnumerator() | foreach {
						$modules.BlishHUD[$_.key]["UI"].enabled = ($value -and $validBlish)
					}

					$modules.Path.GetEnumerator() | foreach {
						$modules.Path[$_.key]["UI"].enabled = (($validBlish -and $value) -or ($validTaco -and $form.TacoRun.enabled))
						$modules.Path[$_.key]["UI1"].enabled = ($validBlish -and $value)
					}

					break
				}
				"taco" {
					$form.pathTaco.enabled = $value
					$form.pathTacoLabel.enabled = $value

					$validBlish = ((Test-Path ($form.pathBlishLabel.Text + "\Blish HUD.exe")) -or ((Test-Path ($form.pathBlishLabel.Text + "\Blish HUD.exe")) -and (Get-ChildItem $form.pathBlishLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })))
					$validTaco = ((Test-Path ($form.pathTacoLabel.Text + "\GW2TacO.exe")) -or ((Test-Path $form.pathTacoLabel.Text) -and (Get-ChildItem $form.pathTacoLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })))

					$form.TacoRun.enabled = ($validTaco -and $value)

					$modules.Path.GetEnumerator() | foreach {
						if (-not $_.value.blishonly) {
							$modules.Path[$_.key]["UI"].enabled = (($validTaco -and $value) -or ($validBlish -and $form.BlishRun.enabled))
							$modules.Path[$_.key]["UI2"].enabled = ($validTaco -and $value)
						}

						$modules.Path[$_.key]["UI"].enabled = $true
						$modules.Path[$_.key]["UI1"].enabled = $true
					}

					break
				}
			}
			break
		}
		"path" {
			switch($key) {
				"arc" {
					$shell = New-Object -ComObject Shell.Application
					$path = $shell.BrowseForFolder(0, "Select where Guildwars 2 is installed", 0).Self.Path

					while (
						-not (
							(Test-Path "$path\Gw2-64.exe")
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

					$form.pathArcLabel.Text = $path

					$modules.ArcDPS.GetEnumerator() | foreach {
						$modules.ArcDPS[$_.key]["UI"].enabled = $value
					}

					break
				}
				"blish" {
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

					$form.pathBlishLabel.Text = $path

					$form.BlishRun.Enabled = $true

					$modules.BlishHUD.GetEnumerator() | foreach {
						$modules.BlishHUD[$_.key]["UI"].enabled = $true
					}

					$modules.BlishHUD.GetEnumerator() | foreach {
						$modules.BlishHUD[$_.key]["UI"].enabled = $true
					}

					$modules.Path.GetEnumerator() | foreach {
						$modules.Path[$_.key]["UI"].enabled = $true
						$modules.Path[$_.key]["UI1"].enabled = $true

						if ($modules.Path[$_.key].conflicts -ne $null) {
							$modules.Path[$_.key]["UI1"].enabled = (-not ($modules.Path[$modules.Path[$_.key].conflicts]["UI2"].checked))
							$modules.Path[$_.key]["UI2"].enabled = (-not ($modules.Path[$modules.Path[$_.key].conflicts]["UI1"].checked))
						}
					}

					break
				}
				"taco" {
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

					$form.pathTacoLabel.Text = $path

					$form.TacoRun.Enabled = $true

					$modules.Path.GetEnumerator() | foreach {
						if (-not $_.value.blishonly) {
							$modules.Path[$_.key]["UI"].enabled = $true
							$modules.Path[$_.key]["UI2"].enabled = $true
						}

						$modules.Path[$_.key]["UI"].enabled = $true
						$modules.Path[$_.key]["UI1"].enabled = $true

						if ($modules.Path[$_.key].conflicts -ne $null) {
							$modules.Path[$_.key]["UI1"].enabled = (-not ($modules.Path[$modules.Path[$_.key].conflicts]["UI2"].checked))
							$modules.Path[$_.key]["UI2"].enabled = (-not ($modules.Path[$modules.Path[$_.key].conflicts]["UI1"].checked))
						}
					}

					break
				}
			}

			placingGUI

			break
		}
		"blish" {
			$modules.Path.GetEnumerator() | foreach {
				if (
					($modules.Path[$_.key].conflicts -ne $null) -and
					($modules.Path[$_.key].conflicts -eq $key)
				) {
					$modules.Path[$_.key]["UI1"].enabled = (-not $value)
				}
			}

			break
		}
		"taco" {
			$modules.Path.GetEnumerator() | foreach {
				if (
					($modules.Path[$_.key].conflicts -ne $null) -and
					($modules.Path[$_.key].conflicts -eq $key)
				) {
					$modules.Path[$_.key]["UI2"].enabled = (-not $value)
				}
			}

			break
		}
		"addons" {
			$modules.ArcDPS[$key]["UI"].checked = $value

			$modules.ArcDPS.GetEnumerator() | foreach {
				$modules.ArcDPS[$_.key]["UI"].enabled = $true

				if (
					($modules.ArcDPS[$_.key].requires -ne $null) -and
					($modules.ArcDPS[$_.key]["UI"].checked -eq $true)
				) {
					$modules.ArcDPS[$_.key].requires | foreach {
						$req = $_ -replace '[^a-zA-Z]', ''

						if ($modules.ArcDPS[$req] -ne $null) {
							$modules.ArcDPS[$req]["UI"].checked = $true
							$modules.ArcDPS[$req]["UI"].enabled = $false
						}
					}
				}
			}

			break
		}
	}
}

function checkPathValidity() {
	return (
		(
			($conf.main.enabledArc) -and
			(-not (Test-Path ($conf.main.pathArc + "\Gw2-64.exe")))
		) -or (
			($conf.main.enabledBlish) -and
			(
				-not (
					(Test-Path ($conf.main.pathBlish + "\Blish HUD.exe")) -or
					(
						(Test-Path $conf.main.pathBlish) -and
						(Get-ChildItem $conf.main.pathBlish -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })
					)
				)
			)
		) -or (
			($conf.main.enabledTaco) -and
			(
				-not (
					(Test-Path ($conf.main.pathTaco + "\GW2TacO.exe")) -or
					(
						(Test-Path $conf.main.pathTaco) -and
						(Get-ChildItem $conf.main.pathTaco -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })
					)
				)
			)
		)
	)
}

# collect packages
$modules = @{}
$modules.Main = @{}
$modules.ArcDPS = @{}
$modules.Path = @{}
$modules.BlishHud = @{}

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
	nls 1
	Write-Host "Please wait a moment - we need to add some dependencies. This is needed oncy only."
	nls 1

	if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
		Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
	}

    Install-Module -Name powershell-yaml -Scope CurrentUser -Force

	nls 1
}

#some "welcoming" text
Clear-Host
nls 4
checkGithubLite
nls 2
Write-Host "Before we can do any nice stuff let us see what nice stuff is out there."
nls 1
Write-Host "Find interesting addons like ArcDPS plugins and other stuff."

Invoke-WebRequest "https://github.com/gw2-addon-loader/Approved-Addons/archive/refs/heads/master.zip" -OutFile "$checkfile.zip"
Expand-Archive -Path "$checkfile.zip" -DestinationPath "$Script_path\" -Force
removefile "$checkfile.zip"

gci -Path "$Script_path\Approved-Addons-master\" -recurse -file -filter *.yaml | foreach {
	$yaml = ConvertFrom-Yaml -Yaml (Get-Content -Path $_.fullname -Raw)
	$name = $yaml.addon_name -replace '[^a-zA-Z]', ''

	if (
		($name -ne "ArcDPS") -and
		($name -ne "ArcDPSBlishHUDIntegration") -and
		($name -ne "ddwrapper") -and
		($name -ne "examplename") -and
		$true
	) {
		$modules.ArcDPS[$name] = $yaml

		$modules.ArcDPS[$name].default = (
			($name -eq "ArcDPSBoonTable") -or
			($name -eq "ArcDPSHealingStats") -or
			($name -eq "ArcDPSKillproofmePlugin") -or
			($name -eq "ArcDPSMechanicsPlugin") -or
			$false
		)
	}
}

Remove-Item "$Script_path\Approved-Addons-master" -recurse -force

$modules.Path.schattenfluegel = @{
	name = "Schattenfluegel"
	desc = "map pack to show be better than TEKKIT. It adds shotcuts and way better pathes. Way better design, but not as complete as TEKKIT."
	default = $true
	repo = "Schattenfluegel/SchattenfluegelTrails"
	targetfile = "SchattenfluegelTrails.taco"
	platform = "github-raw"
	blishonly = $false
}

$modules.Path.czokalapiks = @{
	name = "Czokalapiks"
	desc = "map pack for easy hero points farm runs. Includes all needed waypoints, easy to follow."
	default = $true
	repo = "czokalapik/czokalapiks-guides-for-gw2taco"
	subfolder = "POIs/"
	targetfile = "czokalapiks-guides.taco"
	platform = "bitbucket"
	blishonly = $false
}

Write-Host "Get the newest Blish HUD modules like the Pathing or Timers module."

Invoke-WebRequest "https://mp-repo.blishhud.com/repo.json" -OutFile "$checkfile"
$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
removefile "$checkfile"

$json | foreach {
	$name = $_.Name -replace '[^a-zA-Z]', ''

	$modules.Path[$name] = @{}
	$modules.Path[$name].name = $_.Name
	$modules.Path[$name].desc = $_.Description
	$modules.Path[$name].platform = "blishrepo"
	$modules.Path[$name].targeturl = $_.Download
	$modules.Path[$name].targetfile = $_.FileName
	$modules.Path[$name].version = $_.LastUpdate

	$modules.Path[$name].default = (
		($name -eq "ReActifEN") -or
		($name -eq "HerosMarkerPack") -or
		($name -eq "TekkitsAllInOne") -or
		$false
	)

	$modules.Path[$name].blishonly = (
		($name -eq "HerosMarkerPack") -or
		$false
	)
}

$modules.Path["ReActifEN"].conflicts = "ReActifFR"
$modules.Path["ReActifFR"].conflicts = "ReActifEN"

Write-Host "Now checkout some excellent paths out of the 'Neuland' some of you may know."

Invoke-WebRequest "https://pkgs.blishhud.com/packages.gz" -OutFile "$checkfile.gz"
DeGZip-File "$checkfile.gz"
removefile "$checkfile.gz"
$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
removefile "$checkfile"

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

	$name = $_.namespace -replace '[^a-zA-Z]', ''

	if (
		($modules.BlishHud[$name] -ne $null) -and
		($modules.BlishHud[$name].version -gt $_.version)
	) {
		$filtered = $false
	}

	if ($filtered) {
		$modules.BlishHud[$name] = @{}
		$modules.BlishHud[$name].name = $_.name
		$modules.BlishHud[$name].desc = $_.description
		$modules.BlishHud[$name].targeturl = $_.location
		$modules.BlishHud[$name].version = $_.version
		$modules.BlishHud[$name].namespace = $_.namespace

		$modules.BlishHud[$name].default = (
			($name -eq "CharrTimersBlishHUD") -or
			($name -eq "KillProofModule") -or
			($name -eq "ManlaanHPGrid") -or
			($name -eq "NekresMistwar") -or
			($name -eq "NekresQuickSurrenderModule") -or
			($name -eq "bhcommunityetm") -or
			($name -eq "bhcommunitypathing") -or
			($name -eq "bhgeneraldiscordrp") -or
			($name -eq "bhgeneralevents") -or
			$false
		)
	}
}

Write-Host "We got them all. Lets check out your setting."

#build config
$form = @{}
$initGUI = $true
$forceGUI = ($forceGUIfromBat.length -ne 0)

if (-not (Test-Path "$Script_path\GW2start.ini")) {
	$conf = @{}

	$forceGUI = $true
} else {
	$conf = Get-IniContent "$Script_path\GW2start.ini"
}

if ($conf.main -eq $null) {
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

if ($conf.ignore -eq $null) {
	$conf.ignore = @{}
}

if ($conf.main.pathArc -eq $null) {
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
			$conf.main.pathArc = ($_ + "\Guild Wars 2")
		}

		if (Test-Path ($_ + "\Gw2-64.exe")) {
			$conf.main.pathArc = ($_ + "\")
		}
	}

	$forceGUI = $true
}

if ($forceGUI) {
	do {
		$r = showGUI
	} while ($r -ne "OK")
}

$GW2_path = $conf.main.pathArc
$TacO_path = $conf.main.pathTaco
$BlishHUD_path = $conf.main.pathBlish

while (checkPathValidity) {
	$r = showGUI
}

$GW2_path = $conf.main.pathArc
$TacO_path = $conf.main.pathTaco
$BlishHUD_path = $conf.main.pathBlish

nls 2
Write-Host "To change any settings for this script checkout the GW2start-config.bat file located " -NoNewline
Write-Host "$Script_path\GW2start-config.bat" -ForegroundColor White

#check what is (un)installed and what should get installed
if (-not $forceGUI) {
	#scan if there are unmanged Blish HUD modules
	if ($conf.main.enabledBlish) {
		$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules\"

		$modules.BlishHUD.GetEnumerator() | foreach {
			$targetfile = $checkpath + $_.value.namespace + "*"
			$targeted = Test-Path $targetfile

			if ($conf.ignore[$_.key] -eq $null) {
				if (
					($conf.modules[$_.key] -eq $null) -and
					($_.value.default -eq $true)
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("Do you want to checkout the recommanded Blish HUD module '" + $_.value.name + "'?\r\n\r\n" + $_.value.desc),
						"New Blish HUD module",
						4,
						"Question"
					)

					$conf.modules[$_.key] = ($r -eq "Yes")
				} elseif (
					($conf.modules[$_.key] -eq $false) -and
					($targeted -eq $true)
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have installed '" + $_.value.name + "' but it is not managed here.\r\n\r\n" + $_.value.desc + "\r\n\r\nDo you want this script to manage it?"),
						"Unmanaged Blish HUD module",
						3,
						"Question"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $targetfile -Force -ErrorAction SilentlyContinue

						$conf.modules[$_.key] = $true
						$conf.versions_modules[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}
				} elseif (
					($conf.modules[$_.key] -eq $true) -and
					($targeted -eq $false)
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have uninstalled '" + $_.value.name + "' but this script is configurated to update it.\r\n\r\n" + $_.value.desc + "\r\n\r\nDo you want this script to reinstall it?"),
						"Missing Blish HUD module",
						3,
						"Warning"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $targetfile -Force -ErrorAction SilentlyContinue

						$conf.modules[$_.key] = $true
						$conf.versions_modules[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}
				}
			}
		}
	}

	#scan if there are unmanged paths
	if ($conf.main.enabledBlish -or $conf.main.enabledTaco) {
		$modules.Path.GetEnumerator() | foreach {
			$path_b = path_b $_.value.targetfile
			$path_t = path_t $_.value.targetfile

			$targeted_b = Test-Path $path_b
			$targeted_t = Test-Path $path_t

			if ($conf.ignore[$_.key] -eq $null) {
				if (
					($conf.paths[$_.key + "_blish"] -eq $null) -and
					($_.value.default -eq $true) -and
					$conf.main.enabledBlish
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("Do you want to checkout the recommanded path '" + $_.value.name + "'?\r\n\r\n" + $_.value.desc),
						"New path for Blish HUD pathing module",
						4,
						"Question"
					)

					$conf.paths[$_.key + "_blish"] = ($r -eq "Yes")
					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				} elseif (
					($conf.paths[$_.key + "_blish"] -eq $false) -and
					($targeted_b -eq $true) -and
					$conf.main.enabledBlish
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have installed '" + $_.value.name + "' for Blish HUD.\r\n\r\n" + $_.value.desc + "\r\n\r\nDo you want this script to manage it?"),
						"Unmanaged Blish HUD path",
						3,
						"Question"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $path_b -Force -ErrorAction SilentlyContinue

						$conf.paths[$_.key + "_blish"] = $true
						$conf.versions_paths[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}

					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				} elseif (
					($conf.paths[$_.key + "_blish"] -eq $true) -and
					($targeted_b -eq $false) -and
					$conf.main.enabledBlish
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have uninstalled '" + $_.value.name + "' for Blish HUD but this script is configurated to update it.\r\n\r\n" + $_.value.description + "\r\n\r\nDo you want this script to reinstall it?"),
						"Missing Blish HUD path",
						3,
						"Warning"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $targeted_b -Force -ErrorAction SilentlyContinue

						$conf.paths[$_.key + "_blish"] = $true
						$conf.versions_paths[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}

					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				} elseif (
					($conf.paths[$_.key + "_taco"] -eq $false) -and
					($targeted_t -eq $true) -and
					$conf.main.enabledTaco
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have installed '" + $_.value.name + "' for TacO.\r\n\r\n" + $_.value.description + "\r\n\r\nDo you want this script to manage it?"),
						"Unmanaged TacO path",
						3,
						"Question"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $path_t -Force -ErrorAction SilentlyContinue

						$conf.paths[$_.key + "_taco"] = $true
						$conf.versions_paths[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}

					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				} elseif (
					($conf.paths[$_.key + "_taco"] -eq $true) -and
					($targeted_t -eq $false) -and
					$conf.main.enabledTaco
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have uninstalled '" + $_.value.name + "' for TacO but this script is configurated to update it.\r\n\r\n" + $_.value.description + "\r\n\r\nDo you want this script to reinstall it?"),
						"Missing TacO path",
						3,
						"Warning"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $targeted_t -Force -ErrorAction SilentlyContinue

						$conf.paths[$_.key + "_taco"] = $true
						$conf.versions_paths[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}

					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				}
			}
		}
	}

	#scan if there are unmanged ArcDPS addons
	if ($conf.main.enabledArc) {
		$modules.ArcDPS.GetEnumerator() | foreach {
			$targetfile = path_a -key $_.key -value $_.value
			$targeted = Test-Path $targetfile

			if ($conf.ignore[$_.key] -eq $null) {
				if (
					($conf.addons[$_.key] -eq $null) -and
					($_.value.default -eq $true)
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("Do you want to checkout the recommanded ArcDPS addon '" + $_.value.addon_name + "'?\r\n\r\n" + $_.value.description),
						"New ArcDPS addon",
						4,
						"Question"
					)

					$conf.addons[$_.key] = ($r -eq "Yes")
				} elseif (
					($conf.addons[$_.key] -eq $false) -and
					($targeted -eq $true)
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have installed '" + $_.value.addon_name + "' but it is not managed here.\r\n\r\n" + $_.value.description + "\r\n\r\nDo you want this script to manage it?"),
						"Unmanaged ArcDPS addon",
						3,
						"Question"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $targetfile -Force -Recurse -ErrorAction SilentlyContinue

						$conf.addons[$_.key] = $true
						$conf.versions_addons[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}
				} elseif (
					($conf.addons[$_.key] -eq $true) -and
					($targeted -eq $false)
				) {
					$r = [System.Windows.Forms.MessageBox]::Show(
						("You have uninstalled '" + $_.value.addon_name + "' but this script is configurated to update it.\r\n\r\n" + $_.value.description + "\r\n\r\nDo you want this script to reinstall it?"),
						"Missing ArcDPS addon",
						3,
						"Warning"
					)

					if ($r -eq "No") {
						$conf.ignore[$_.key] = $true
					} elseif ($r -eq "Yes") {
						Remove-Item $targetfile -Force -Recurse -ErrorAction SilentlyContinue

						$conf.addons[$_.key] = $true
						$conf.versions_addons[$_.key] = "0"
					} else {
						Write-Host "I will ask you again ;)"
					}
				}
			}
		}
	}
}

# now the real magic:
stopprocesses

# give message about GW2 build id
$checkurl = "https://api.guildwars2.com/v2/build"
Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
$new = $json.id
removefile "$checkfile"

if (
	($conf.versions_main.GW2 -eq $null) -or
	($conf.versions_main.GW2 -ne $new)
) {
	Write-Host "Guildwars 2 " -NoNewline -ForegroundColor White
	Write-Host "will update itself to " -NoNewline
	Write-Host "build $new" -ForegroundColor Green

	$conf.versions_main.GW2 = $new
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
} else {
	Write-Host "Guildwars 2 " -NoNewline -ForegroundColor White
	Write-Host "is up-to-date"
}

# auto update this script itself (prepare the update to be done by the .bat file with the next start)
Write-Host "GW2start.bat " -NoNewline -ForegroundColor White
Write-Host "and " -NoNewline
Write-Host "GW2start-config.bat " -NoNewline -ForegroundColor White
Write-Host "are " -NoNewline
Write-Host "updated " -NoNewline -ForegroundColor Green
Write-Host "every time"

removefile "$Script_path\GW2start.bat"
Invoke-WebRequest "https://github.com/Tinsus/GW2-updater-script/raw/main/GW2start.bat" -OutFile "$Script_path/GW2start.bat"
removefile "$Script_path\GW2start-config.bat"
Invoke-WebRequest "https://github.com/Tinsus/GW2-updater-script/raw/main/GW2start-config.bat" -OutFile "$Script_path/GW2start-config.bat"

# auto update Core-Loader from the GW2-Addon-loader geniuses
if ($conf.main.enabledArc) {
	checkGithub

	$checkurl = "https://api.github.com/repos/gw2-addon-loader/loader-core/releases/latest"
	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.tag_name
	removefile "$checkfile"

	if (
		($conf.versions_main.loadercore -eq $null) -or
		($conf.versions_main.loadercore -ne $new) -or
		(-not (Test-Path "$GW2_path\bin64\d3d9.dll")) -or
		(-not (Test-Path "$GW2_path\addonLoader.dll")) -or
		(-not (Test-Path "$GW2_path\d3d11.dll")) -or
		(-not (Test-Path "$GW2_path\dxgi.dll"))
	) {
		Write-Host "Addon-Loader-Core " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.zip"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$GW2_path\" -Force
		removefile "$checkfile.zip"

		$conf.versions_main.loadercore = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "Addon-Loader-Core " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}
} else {
	removefile "$GW2_path\bin64\d3d9.dll"
	removefile "$GW2_path\addonLoader.dll"
	removefile "$GW2_path\d3d11.dll"
	removefile "$GW2_path\dxgi.dll"

	$conf.version_main.psobject.properties.remove('loadercore')
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

# auto update d3d9_wrapper
if ($conf.main.enabledArc) {
	$checkurl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum"
	$targeturl = "https://www.deltaconnected.com/arcdps/x64/d3d9.dll"
	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$new = (Get-Content "$checkfile" -Raw).Trim()
	removefile "$checkfile"

	if (
		($conf.versions_main.ArcDPS -eq $null) -or
		($conf.versions_main.ArcDPS -ne $new) -or
		(-not (Test-Path "$GW2_path\addons\arcdps\gw2addon_arcdps.dll"))
	) {
		Write-Host "d3d9_wrapper " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		removefile "$GW2_path\addons\arcdps\gw2addon_arcdps.dll"

		newdir "$GW2_path\addons\"
		newdir "$GW2_path\addons\arcdps\"

		Invoke-WebRequest "$targeturl" -OutFile "$GW2_path\addons\arcdps\gw2addon_arcdps.dll"

		$conf.versions_main.ArcDPS = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "d3d9_wrapper " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}
} else {
	removefile "$GW2_path\addons\arcdps\gw2addon_arcdps.dll"

	$conf.version_main.psobject.properties.remove('ArcDPS')
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

# auto update ArcDPS
if ($conf.main.enabledArc) {
	checkGithub
	Invoke-WebRequest "https://api.github.com/repos/gw2-addon-loader/d3d9_wrapper/releases/latest" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name
	removefile "$checkfile"

	if (
		($conf.main.d3d9_wrapper -eq $null) -or
		($conf.main.d3d9_wrapper -ne $new) -or
		(-not (Test-Path "$GW2_path\d3d9_wrapper"))
	) {
		Write-Host "Addon '" -NoNewline
		Write-Host "d3d9_wrapper" -NoNewline -ForegroundColor White
		Write-Host "' is being updated" -ForegroundColor Green

		Remove-Item "$GW2_path\d3d9_wrapper" -Recurse -Force -ErrorAction SilentlyContinue
		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.zip"
		newdir "$checkfile"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$checkfile\" -Force
		removefile "$checkfile.zip"

		newdir "$GW2_path\d3d9_wrapper"

		gci -Path "$checkfile" -recurse -file | foreach {
			Copy-Item $_.fullname -Destination "$GW2_path\d3d9_wrapper\"
		}

		Remove-Item "$checkfile" -recurse -force

		$conf.main.d3d9_wrapper = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "Addon '" -NoNewline
		Write-Host "d3d9_wrapper" -NoNewline -ForegroundColor White
		Write-Host "' is up-to-date"
	}
} else {
	Remove-Item "$GW2_path\d3d9_wrapper" -Recurse -Force -ErrorAction SilentlyContinue

	$conf.main.psobject.properties.remove("d3d9_wrapper")
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

# auto update TacO
if ($conf.main.enabledTaco) {
	checkGithub

	newdir "$TacO_path"

	$checkurl = "https://api.github.com/repos/BoyC/GW2TacO/releases/latest"
	$targetfile = "$TacO_path\"
	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.node_id
	removefile "$checkfile"

	if (
		($conf.versions_main.TacO -eq $null) -or
		($conf.versions_main.TacO -ne $new) -or
		(-not (Test-Path "$targetfile\GW2TacO.exe"))
	) {
		Write-Host "TacO " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.temp.zip"

		Expand-Archive -Path "$checkfile.temp.zip" -DestinationPath "$targetfile" -Force
		removefile "$checkfile.temp.zip"

		$conf.versions_main.TacO = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "TacO " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}
} else {
	Remove-Item -Path "$TacO_path\*" -force -recurse

	$conf.versions_main.psobject.properties.remove('TacO')
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

# auto update BlishHUD
if ($conf.main.enabledBlish) {
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
	$new = $json.tag_name
	removefile "$checkfile"

	if (
		($conf.versions_main.BlishHUD -eq $null) -or
		($conf.versions_main.BlishHUD -ne $new) -or
		(-not (Test-Path "$targetfile\Blish HUD.exe"))
	) {
		Write-Host "BlishHUD " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.zip"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$targetfile\" -Force
		removefile "$checkfile.zip"

		$conf.versions_main.BlishHUD = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"

		enforceBHM
	} else {
		Write-Host "BlishHUD " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}
} else {
	Remove-Item -Path "$BlishHUD_path\*" -force -recurse

	$conf.versions_main.psobject.properties.remove('BlishHUD')
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

# auto update BlishHUD_ArcDPS_Bridge
if ($conf.main.enabledBlish -and $conf.main.enabledArc) {
	checkGithub

	$checkurl = "https://api.github.com/repos/blish-hud/arcdps-bhud/releases/latest"
	$targetfile = "$GW2_path\bin64\arcdps_bhud.dll"

	Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

	$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
	$new = $json.name
	removefile "$checkfile"

	if (
		($conf.versions_main.BlishHUD_ArcDPS_Bridge -eq $null) -or
		($conf.versions_main.BlishHUD_ArcDPS_Bridge -ne $new) -or
		(-not (Test-Path "$targetfile"))
	) {
		Write-Host "BlishHUD-ArcDPS Bridge " -NoNewline -ForegroundColor White
		Write-Host "is being updated" -ForegroundColor Green

		Invoke-WebRequest $json.assets.browser_download_url[1] -OutFile "$checkfile.zip"
		Expand-Archive -Path "$checkfile.zip" -DestinationPath "$GW2_path\bin64\" -Force
		removefile "$checkfile.zip"

		$conf.versions_main.BlishHUD_ArcDPS_Bridge = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	} else {
		Write-Host "BlishHUD_ArcDPS_Bridge " -NoNewline -ForegroundColor White
		Write-Host "is up-to-date"
	}
} else {
	removefile "$GW2_path\bin64\arcdps_bhud.dll"

	$conf.versions_main.psobject.properties.remove('BlishHUD_ArcDPS_Bridge')
	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

# auto update BlishHUD-Modules
$modules.BlishHUD.GetEnumerator() | foreach {
	if ($conf.modules[$_.key] -and $conf.main.enabledBlish) {
		$checkpath = "$MyDocuments_path\Guild Wars 2\addons\blishhud\modules\"
		$targetfile = ($checkpath + $_.value.namespace + "_" + $_.value.version + ".bhm")
		$new = $_.value.version

		if (
			($conf.versions_modules[$_.key] -eq $null) -or
			($conf.versions_modules[$_.key] -ne $new) -or
			(-not (Test-Path "$targetfile"))
		) {
			Write-Host "BlishHUD module '" -NoNewline
			Write-Host $_.value.name -NoNewline -ForegroundColor White
			Write-Host "' is being updated" -ForegroundColor Green

			Remove-Item ($checkpath + $_.value.namespace + "*") -Force -ErrorAction SilentlyContinue

			Invoke-WebRequest $_.value.targeturl -OutFile $targetfile

			enforceBHM $_.value.namespace

			$conf.versions_modules[$_.key] = $new
			Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
		} else {
			Write-Host "BlishHUD module '" -NoNewline
			Write-Host $_.value.name -NoNewline -ForegroundColor White
			Write-Host "' is up-to-date"
		}
	} else {
		removefile ($checkpath + $_.value.namespace + "_" + $_.value.version + ".bhm")

		$conf.versions_modules.psobject.properties.remove($_.key)
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	}
}

# auto update Paths
$modules.Path.GetEnumerator() | foreach {
	if (
		($conf.paths[$_.key + "_blish"] -and $conf.main.enabledBlish) -or
		($conf.paths[$_.key + "_taco"] -and $conf.main.enabledTaco)
	) {
		$path_t = path_t $_.value.targetfile
		$path_b = path_b $_.value.targetfile

		if ($_.value.platform -eq "blishrepo") {
			$new = $_.value.version

			if (
				($conf.versions_paths[$_.key] -eq $null) -or
				($conf.versions_paths[$_.key] -ne $new) -or (
					($conf.paths[$_.key + "_taco"]) -and
					(-not (Test-Path "$path_t"))
				) -or (
					($conf.paths[$_.key + "_blish"]) -and
					(-not (Test-Path "$path_b"))
				)
			) {
				Write-Host "Path '" -NoNewline
				Write-Host $_.value.name -NoNewline -ForegroundColor White
				Write-Host "' is being updated" -ForegroundColor Green

				Invoke-WebRequest $_.value.targeturl -OutFile "$checkfile"

				if (Test-Path $checkfile) {
					if ($conf.paths[$_.key + "_blish"]) {
						removefile "$path_b"

						Copy-Item "$checkfile" -Destination "$path_b"
					}

					if ($conf.paths[$_.key + "_taco"]) {
						removefile "$path_t"

						Copy-Item "$checkfile" -Destination "$path_t"
					}

					$conf.versions_paths[$_.key] = $new
					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				}

				removefile "$checkfile"
			} else {
				Write-Host "Path '" -NoNewline
				Write-Host $_.value.name -NoNewline -ForegroundColor White
				Write-Host "' is up-to-date"
			}
		} elseif ($_.value.platform -eq "github-raw") {
			checkGithub
			Invoke-WebRequest ("https://api.github.com/repos/" + $_.value.repo + "/contents/Download") -OutFile "$checkfile"
			$new = $(Get-FileHash "$checkfile" -Algorithm MD5).Hash
			removefile "$checkfile"

			if (
				($conf.versions_paths[$_.key] -eq $null) -or
				($conf.versions_paths[$_.key] -ne $new) -or (
					($conf.paths[$_.key + "_taco"]) -and
					(-not (Test-Path "$path_t"))
				) -or (
					($conf.paths[$_.key + "_blish"]) -and
					(-not (Test-Path "$path_b"))
				)
			) {
				Write-Host "Path '" -NoNewline
				Write-Host $_.value.name -NoNewline -ForegroundColor White
				Write-Host "' is being updated" -ForegroundColor Green

				Invoke-WebRequest ("https://github.com/" + $_.value.repo + "/raw/main/Download/" + $_.value.targetfile) -OutFile "$checkfile"

				if (Test-Path $checkfile) {
					if ($conf.paths[$_.key + "_blish"]) {
						removefile "$path_b"

						Copy-Item "$checkfile" -Destination "$path_b"
					}

					if ($conf.paths[$_.key + "_taco"]) {
						removefile "$path_t"

						Copy-Item "$checkfile" -Destination "$path_t"
					}

					$conf.versions_paths[$_.key] = $new
					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				}

				removefile "$checkfile"
			} else {
				Write-Host "Path '" -NoNewline
				Write-Host $_.value.name -NoNewline -ForegroundColor White
				Write-Host "' is up-to-date"
			}
		} elseif ($_.value.platform -eq "bitbucket") {
			Invoke-WebRequest ("https://api.bitbucket.org/2.0/repositories/" + $_.value.repo + "/commits") -OutFile "$checkfile"
			$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
			$new = $($json.values[0].hash).Substring(0, 12)
			removefile "$checkfile"

			if (
				($conf.versions_paths[$_.key] -eq $null) -or
				($conf.versions_paths[$_.key] -ne $new) -or (
					($conf.paths[$_.key + "_taco"]) -and
					(-not (Test-Path "$path_t"))
				) -or (
					($conf.paths[$_.key + "_blish"]) -and
					(-not (Test-Path "$path_b"))
				)
			) {
				Write-Host "Path '" -NoNewline
				Write-Host $_.value.name -NoNewline -ForegroundColor White
				Write-Host "' is being updated" -ForegroundColor Green

				Invoke-WebRequest ("https://bitbucket.org/" + $_.value.repo + "/get/" + $new + ".zip") -OutFile "$checkfile.zip"

				if (Test-Path "$checkfile.zip") {
					Expand-Archive -Path "$checkfile.zip" -DestinationPath "$Script_path\" -Force
					removefile "$checkfile.zip"
					Compress-Archive -Path ("$Script_path\" + ($($_.value.repo).Replace("/", "-")) + "-$new\" + $_.value.subfolder + "*") -DestinationPath "$checkfile.zip"
					Remove-Item ("$Script_path\" + ($($_.value.repo).Replace("/", "-")) + "-$new") -Recurse -force

					if ($conf.paths[$_.key + "_blish"]) {
						removefile "$path_b"

						Copy-Item "$checkfile.zip" -Destination "$path_b"
					}

					if ($conf.paths[$_.key + "_taco"]) {
						removefile "$path_t"

						Copy-Item "$checkfile.zip" -Destination "$path_t"
					}

					$conf.versions_paths[$_.key] = $new
					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				}

				removefile "$checkfile.zip"
			} else {
				Write-Host "Path '" -NoNewline
				Write-Host $_.value.name -NoNewline -ForegroundColor White
				Write-Host "' is up-to-date"
			}
		}
	}

	if (-not ($conf.paths[$_.key + "_blish"] -and $conf.main.enabledBlish)) {
		removefile (path_b $_.value.targetfile)
	}

	if (-not ($conf.paths[$_.key + "_taco"] -and $conf.main.enabledTaco)) {
		removefile (path_t $_.value.targetfile)
	}

	if (
		(-not ($conf.paths[$_.key + "_blish"] -and $conf.main.enabledBlish)) -and
		(-not ($conf.paths[$_.key + "_taco"] -and $conf.main.enabledTaco))
	) {
		$conf.versions_paths.psobject.properties.remove($_.key)
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	}
}

# auto update ArcDPS addons
$modules.ArcDPS.GetEnumerator() | foreach {
	$key = $_.key
	$value = $_.value

	$targetpath = path_a -key $key -value $value

	if ($conf.addons[$key] -and $conf.main.enabledArc) {
		if ($value.host_type -eq "github") {
			checkGithub
			Invoke-WebRequest $value.host_url -OutFile "$checkfile"

			$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
			$new = $json.name
			removefile "$checkfile"

			if (
					($value.download_type -eq "archive") -and
					($value.install_mode -eq "binary")
			) {
				if (
					($conf.versions_addons[$key] -eq $null) -or
					($conf.versions_addons[$key] -ne $new) -or
					(-not (Test-Path "$targetpath"))
				) {
					Write-Host "Addon '" -NoNewline
					Write-Host $value.addon_name -NoNewline -ForegroundColor White
					Write-Host "' is being updated" -ForegroundColor Green

					Remove-Item ("$targetpath") -Recurse -Force -ErrorAction SilentlyContinue
					Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.zip"
					newdir "$checkfile"
					Expand-Archive -Path "$checkfile.zip" -DestinationPath "$checkfile\" -Force
					removefile "$checkfile.zip"

					newdir "$targetpath"

					gci -Path "$checkfile" -recurse -file | foreach {
						Copy-Item $_.fullname -Destination "$targetpath\"
					}

					Remove-Item "$checkfile" -recurse -force

					$conf.versions_addons[$key] = $new
					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				} else {
					Write-Host "Addon '" -NoNewline
					Write-Host $value.addon_name -NoNewline -ForegroundColor White
					Write-Host "' is up-to-date"
				}
			} elseif (
					($value.download_type -eq "archive") -and
					($value.install_mode -eq "arc")
			) {
				if (
					($conf.versions_addons[$key] -eq $null) -or
					($conf.versions_addons[$key] -ne $new) -or
					(-not (Test-Path "$targetpath"))
				) {
					Write-Host "Addon '" -NoNewline
					Write-Host $value.addon_name -NoNewline -ForegroundColor White
					Write-Host "' is being updated" -ForegroundColor Green

					Invoke-WebRequest $json.assets.browser_download_url -OutFile "$checkfile.zip"
					Remove-Item "$checkfile" -Recurse -Force -ErrorAction SilentlyContinue
					newdir "$checkfile\"
					Expand-Archive -Path "$checkfile.zip" -DestinationPath "$checkfile\" -Force
					removefile "$checkfile.zip"

					gci -Path "$checkfile\*" -recurse -file -filter *.dll | foreach {
						Copy-Item $_.fullname -Destination "$targetpath"
					}

					Remove-Item "$checkfile" -recurse -force

					$conf.versions_addons[$key] = $new
					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				} else {
					Write-Host "Addon '" -NoNewline
					Write-Host $value.addon_name -NoNewline -ForegroundColor White
					Write-Host "' is up-to-date"
				}
			} elseif (
					($value.download_type -eq ".dll") -and
					($value.install_mode -eq "arc")
			) {
				if (
					($conf.versions_addons[$key] -eq $null) -or
					($conf.versions_addons[$key] -ne $new) -or
					(-not (Test-Path "$targetpath"))
				) {
					Write-Host "Addon '" -NoNewline
					Write-Host $value.addon_name -NoNewline -ForegroundColor White
					Write-Host "' is being updated" -ForegroundColor Green

					removefile "$targetpath"

					$download = $json.assets.browser_download_url

					$json.assets | foreach {
						if ($_.browser_download_url -like "*.dll") {
							$download = $_.browser_download_url
						}
					}

					Invoke-WebRequest $download -OutFile "$targetpath"

					$conf.versions_addons[$key] = $new
					Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
				} else {
					Write-Host "Addon '" -NoNewline
					Write-Host $value.addon_name -NoNewline -ForegroundColor White
					Write-Host "' is up-to-date"
				}
			}
		} elseif ($value.host_type -eq "standalone") {
			Invoke-WebRequest $value.website -OutFile "$checkfile"
			$new = $(Get-FileHash "$checkfile" -Algorithm MD5).Hash
			removefile "$checkfile"

			if (
				($conf.versions_addons[$key] -eq $null) -or
				($conf.versions_addons[$key] -ne $new) -or
				(-not (Test-Path "$targetpath"))
			) {
				Write-Host "Addon '" -NoNewline
				Write-Host $value.addon_name -NoNewline -ForegroundColor White
				Write-Host "' is being updated" -ForegroundColor Green

				Invoke-WebRequest $value.host_url -OutFile "$targetpath"

				$conf.versions_addons[$key] = $new
				Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
			} else {
				Write-Host "Addon '" -NoNewline
				Write-Host $value.addon_name -NoNewline -ForegroundColor White
				Write-Host "' is up-to-date"
			}
		}
	} else {
		if (
			("$targetpath" -ne "$GW2_path\addons") -and
			("$targetpath" -ne "$GW2_path\addons\arcdps")
		) {
			Remove-Item "$targetpath" -Recurse -Force -ErrorAction SilentlyContinue
			removefile "$targetpath"
		}

		$conf.versions_addons.psobject.properties.remove($key)
		Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
	}
}

# done with updating
startGW2
stopprocesses

removefile "$checkfile"
removefile "$checkfile.zip"
removefile "$Script_path\github.json"

nls 1
Write-Host "see you soon"

Start-Sleep -Seconds 2
