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

	$form.groupPaths.Location = New-Object System.Drawing.Size(($form.groupTaco.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))
	$form.groupModules.Location = New-Object System.Drawing.Size(($form.groupBlish.Location.X), ($form.groupArc.Location.Y + $form.groupArc.height + 10))

	$x = $form.groupTaco.Width * 1.5 + $form.groupTaco.x -35
	$y = (@($form.groupArc.Height, $form.groupBlish.Height, $form.groupTaco.Height) | measure -Maximum).Maximum + (@($form.groupAddons.Height, $form.groupPaths.Height, $form.groupModules.Height) | measure -Maximum).Maximum + $form.groupArc.y + 60

    $form.close.Location = New-Object System.Drawing.Size($x, $y)
}

function showGUI {
# prepare stuff
	Add-Type -assembly System.Windows.Forms

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
	$form.groupArc.Controls.Add($form.pathArcLabel)

	$form.arcDx9 = New-Object System.Windows.Forms.RadioButton
	$form.arcDx9.Text = "DirectX 9"
	$form.arcDx9.Location = New-Object System.Drawing.Point(10, 80)
	$form.arcDx9.AutoSize = $true
	$form.arcDx9.Add_Click({
		changeGUI -category "dx" -key "9" -value $this.checked
	})
	$form.tooltip.SetToolTip($form.arcDx9, "Did you set Guildwars2 to use DirectX9 (default) or DirectX11?")
	$form.groupArc.Controls.Add($form.arcDx9)

	$form.arcDx11 = New-Object System.Windows.Forms.RadioButton
	$form.arcDx11.Text = "DirectX 11"
	$form.arcDx11.Location = New-Object System.Drawing.Point(90, 80)
	$form.arcDx11.AutoSize = $true
	$form.arcDx11.Add_Click({
		changeGUI -category "dx" -key "11" -value $this.checked

	})
	$form.tooltip.SetToolTip($form.arcDx11, "Did you set Guildwars2 to use DirectX9 (default) or DirectX11?")
	$form.groupArc.Controls.Add($form.arcDx11)

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
		$modules.ArcDPS[$_.key]["UI"].Text = ($(if ($_.value.default) { "* " } else { "" }) + $_.value.name)
		$modules.ArcDPS[$_.key]["UI"] | Add-Member -MemberType NoteProperty -Name 'Value' -Value $_.key
		$modules.ArcDPS[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (20 * $i)))
		$modules.ArcDPS[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 20)
		$modules.ArcDPS[$_.key]["UI"].Add_CheckStateChanged({
			changeGUI -category "addons" -key $this.Value -value $this.checked
		})
		$form.tooltip.SetToolTip($modules.ArcDPS[$_.key]["UI"], $_.value.desc)
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
		changeGUI -category "save" -key "default" -value $false
	})
    $form.main_form.Controls.Add($form.close)

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

	$form.arcDx9.enabled = ($validArc -and $form.enabledArc.Checked)
	$form.arcDx11.enabled = ($validArc -and $form.enabledArc.Checked)

	if ($conf.main.dx -eq $null) {
		$form.arcDx9.checked = $false
		$form.arcDx11.checked = $false
	} else {
		$form.arcDx9.checked = ($conf.main.dx -eq 9)
		$form.arcDx11.checked = ($conf.main.dx -eq 11)
	}

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
		$modules.ArcDPS[$_.key]["UI"].enabled = (($validArc) -and ($form.arcDx9.checked -or $form.arcDx11.checked))

		if ($conf.addons[$_.key] -eq $null) {
			$modules.ArcDPS[$_.key]["UI"].checked = $_.value.default
		} else {
			$modules.ArcDPS[$_.key]["UI"].checked = $conf.addons[$_.key]
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
	}

	placingGUI
}

function changeGUI($category, $key = 0, $value = 0) {
	if ($initGUI) {
		return
	}

	switch($category) {
		"save" {
			$conf.main.pathArc = $form.pathArcLabel.Text
			$conf.main.pathTaco = $form.pathTacoLabel.Text
			$conf.main.pathBlish = $form.pathBlishLabel.Text

			$conf.main.enabledArc = $form.enabledArc.checked
			$conf.main.enabledTaco = $form.enabledTaco.checked
			$conf.main.enabledBlish = $form.enabledBlish.checked

			if ($form.arcDx9.checked) {
				$conf.main.dx = 9
			} elseif ($form.arcDx11.checked) {
				$conf.main.dx = 11
			}

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
		"enable" {
			switch($key) {
				"arc" {
					$form.pathArc.enabled = $value
					$form.pathArcLabel.enabled = $value

					if ((Test-Path ($form.pathArcLabel.Text + "\Gw2-64.exe"))) {
						$form.arcDx9.Enabled = $value
						$form.arcDx11.Enabled = $value
					} else {
						$form.arcDx9.Enabled = $false
						$form.arcDx11.Enabled = $false
					}

					$modules.ArcDPS.GetEnumerator() | foreach {
						$modules.ArcDPS[$_.key]["UI"].enabled = ($value -and ($form.arcDx9.checked -or $form.arcDx11.checked))
					}

					break
				}

				"blish" {
					$form.pathBlish.enabled = $value
					$form.pathBlishLabel.enabled = $value

					$validBlish = ((Test-Path ($form.pathBlishLabel.Text + "\Blish HUD.exe")) -or (Get-ChildItem $form.pathBlishLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 }))
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

					$validBlish = ((Test-Path ($form.pathBlishLabel.Text + "\Blish HUD.exe")) -or (Get-ChildItem $form.pathBlishLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 }))
					$validTaco = ((Test-Path ($form.pathTacoLabel.Text + "\GW2TacO.exe")) -or ((Test-Path $form.pathTacoLabel.Text) -and (Get-ChildItem $form.pathTacoLabel.Text -Recurse -File | Measure-Object | %{ return $_.Count -eq 0 })))

					$form.TacoRun.enabled = ($validTaco -and $value)

					$modules.Path.GetEnumerator() | foreach {
						if (-not $_.value.blishonly) {
							$modules.Path[$_.key]["UI"].enabled = (($validTaco -and $value) -or ($validBlish -and $form.BlishRun.enabled))
							$modules.Path[$_.key]["UI2"].enabled = ($validTaco -and $value)
						}
					}

					break
				}
			}
			break
		}
		"dx" {
			$modules.ArcDPS.GetEnumerator() | foreach {
				$modules.ArcDPS[$_.key]["UI"].enabled = $true
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

					$form.pathArcLabel.Text = $path

					$form.arcDx9.Enabled = $true
					$form.arcDx11.Enabled = $true

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
					}

					break
				}
			}

			placingGUI

			break
		}
	}
}

# collect packages

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

$json | foreach {
	$name = $_.Name -replace '[^a-zA-Z]', ''

	$modules.Path[$name] = @{}
	$modules.Path[$name].name = $_.Name
	$modules.Path[$name].desc = $_.Description
	$modules.Path[$name].platform = "blishrepo"
	$modules.Path[$name].targeturl = $_.Download
	$modules.Path[$name].targetfile = $_.FileMane
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

		$modules.BlishHud[$name].default = (
			($name -eq "Timers") -or
			$false
		)
	}
}

$form = @{}
$initGUI = $true

#build config

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
	}

	$forceGUI = $true
}

if (
	($conf.main.pathTaco -eq $null) -or
	($conf.main.pathBlish -eq $null) -or

	($conf.installation_paths -ne $null) -or
	($conf.configuration -ne $null) -or
	($conf.settings_ArcDPS -ne $null) -or
	($conf.settings_BlishHUD -ne $null) -or
	($conf.settings_Mappacks -ne $null)
) {
	$conf.psobject.properties.remove('installation_paths')
	$conf.psobject.properties.remove('configuration')
	$conf.psobject.properties.remove('settings_ArcDPS')
	$conf.psobject.properties.remove('settings_BlishHUD')
	$conf.psobject.properties.remove('settings_Mappacks')
	$conf.psobject.properties.remove('versions')

	$forceGUI = $true
}










$forceGUI = $true; cls ############################################### TESTING ##############################################################################

if ($forceGUI) {
	do {
		$r = showGUI
	} while ($r -ne "OK")
} else {
	# dings  das prüft, ob die config passt oder was fehlt oder hinzugefügt wurde. Message immer: ja nein ignore

	# info mit timeout für arcdps
	# gw2 pfad validität
	# taco pfad validität
	# blish pfad validität
	# scan auf arcdps addons
	# scan auf paths
	# scan mit wildcard auf modules
}




exit

# now the real magic:

$GW2_path = $conf.main.pathArc
$TacO_path = $conf.main.pathTaco
$BlishHUD_path = $conf.main.pathBlish

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
