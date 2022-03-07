#testing stuff for dev only

if ($false) {
	cls

# prepare stuff

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

	$modules.Path.schatten = @{
		name = "Schattenfluegel"
		desc = "map pack to show be better than TEKKIT. It adds shotcuts and way better pathes. Way better design, but not as complete as TEKKIT."
		default = $true
		checkurl = "https://api.github.com/repos/Schattenfluegel/SchattenfluegelTrails/contents/Download"
		targeturl = "https://github.com/Schattenfluegel/SchattenfluegelTrails/raw/main/Download/SchattenfluegelTrails.taco"
		targetfile = "SchattenfluegelTrails.taco"
		platform = "github-raw"
		blishonly = $false
	}


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
	})
	$groupArc.Controls.Add($enabledArc)

	$pathArc = New-Object System.Windows.Forms.Button
	$pathArc.Location = New-Object System.Drawing.Size(10, 55)
	$pathArc.Size = New-Object System.Drawing.Size(50, 20)
	$pathArc.Text = "Edit"
	$pathArc.Enabled = $false
	$pathArc.Add_Click({
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
	})
	$groupArc.Controls.Add($pathArc)

	$pathArcLabel = New-Object System.Windows.Forms.Label
	$pathArcLabel.Text = "Select installation path first"
	$pathArcLabel.Enabled = $false
	$pathArcLabel.Location = New-Object System.Drawing.Point(62, 58)
	$pathArcLabel.AutoSize = $true
	$groupArc.Controls.Add($pathArcLabel)

	$arcDx9 = New-Object System.Windows.Forms.RadioButton
	$arcDx9.Text = "DirectX 9"
	$arcDx9.Enabled = $false
	$arcDx9.Location = New-Object System.Drawing.Point(10, 80)
	$arcDx9.AutoSize = $true
	$arcDx9.Add_Click({
		$arcDx11.Checked = $false

		$modules.ArcDPS.GetEnumerator() | foreach {
			$modules.ArcDPS[$_.key]["UI"].Enabled = $true
		}
	})
	$tooltip.SetToolTip($arcDx9, "Did you set Guildwars2 to use DirectX9 (default) or DirectX11?")
	$groupArc.Controls.Add($arcDx9)

	$arcDx11 = New-Object System.Windows.Forms.RadioButton
	$arcDx11.Text = "DirectX 11"
	$arcDx11.Enabled = $false
	$arcDx11.Location = New-Object System.Drawing.Point(90, 80)
	$arcDx11.AutoSize = $true
	$arcDx11.Add_Click({
		$arcDx9.Checked = $false

		$modules.ArcDPS.GetEnumerator() | foreach {
			$modules.ArcDPS[$_.key]["UI"].Enabled = $true
		}
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
	})
	$groupTaco.Controls.Add($enabledTaco)

	$pathTaco = New-Object System.Windows.Forms.Button
	$pathTaco.Location = New-Object System.Drawing.Size(10, 55)
	$pathTaco.Size = New-Object System.Drawing.Size(50, 20)
	$pathTaco.Text = "Edit"
	$pathTaco.Enabled = $false
	$pathTaco.Add_Click({
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
	})
	$groupTaco.Controls.Add($pathTaco)

	$pathTacoLabel = New-Object System.Windows.Forms.Label
	$pathTacoLabel.Text = "Select installation path first"
	$pathTacoLabel.Enabled = $false
	$pathTacoLabel.Location = New-Object System.Drawing.Point(62, 58)
	$pathTacoLabel.AutoSize = $true
	$groupTaco.Controls.Add($pathTacoLabel)

	$TacoRun = New-Object System.Windows.Forms.CheckBox
	$TacoRun.Text = "auto start"
	$TacoRun.Enabled = $false
	$TacoRun.Size = New-Object System.Drawing.Point(200, 20)
	$TacoRun.Location = New-Object System.Drawing.Point(10, 80)
	$TacoRun.Add_CheckStateChanged({
		if ($TacoRun.Checked) {
			$TacoRun.Text = "auto start"
		} else {
			$TacoRun.Text = "manually started"
		}
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
	})
	$groupBlish.Controls.Add($enabledBlish)

	$pathBlish = New-Object System.Windows.Forms.Button
	$pathBlish.Location = New-Object System.Drawing.Size(10, 55)
	$pathBlish.Size = New-Object System.Drawing.Size(50, 20)
	$pathBlish.Text = "Edit"
	$pathBlish.Enabled = $false
	$pathBlish.Add_Click({
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
	})
	$groupBlish.Controls.Add($pathBlish)

	$pathBlishLabel = New-Object System.Windows.Forms.Label
	$pathBlishLabel.Text = "Select installation path first"
	$pathBlishLabel.Enabled = $false
	$pathBlishLabel.Location = New-Object System.Drawing.Point(62, 58)
	$pathBlishLabel.AutoSize = $true
	$groupBlish.Controls.Add($pathBlishLabel)

	$BlishRun = New-Object System.Windows.Forms.CheckBox
	$BlishRun.Text = "auto start"
	$BlishRun.Enabled = $false
	$BlishRun.Size = New-Object System.Drawing.Point(200, 20)
	$BlishRun.Location = New-Object System.Drawing.Point(10, 80)
	$BlishRun.Add_CheckStateChanged({
		if ($BlishRun.Checked) {
			$BlishRun.Text = "auto start"
		} else {
			$BlishRun.Text = "manually started"
		}
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
		$modules.ArcDPS[$_.key]["UI"].Enabled = $false
		$modules.ArcDPS[$_.key]["UI"].Text = $_.value.name
		$modules.ArcDPS[$_.key]["UI"].Checked = $_.value.default
		$modules.ArcDPS[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (20 * $i)))
		$modules.ArcDPS[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 20)
		$modules.ArcDPS[$_.key]["UI"].Add_CheckStateChanged({
			Write-Host $this.Text
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
		#$modules.Path[$_.key]["UI"].Enabled = $false
		#$modules.Path[$_.key]["UI"].Checked = $_.value.default
		$modules.Path[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (70 * $i)))
		$modules.Path[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 15)
		$tooltip.SetToolTip($modules.Path[$_.key]["UI"], $_.value.desc)
		$groupPaths.Controls.Add($modules.Path[$_.key]["UI"])
		
		$modules.Path[$_.key]["UI1"] = New-Object System.Windows.Forms.CheckBox
		#$modules.Path[$_.key]["UI1"].Enabled = $false
		$modules.Path[$_.key]["UI1"].Text = "Blish HUD"
		#$modules.Path[$_.key]["UI1"].Checked = $_.value.default
		$modules.Path[$_.key]["UI1"].Location = New-Object System.Drawing.Point(30, (35 + (100 * $i)))
		$modules.Path[$_.key]["UI1"].Size = New-Object System.Drawing.Point(80, 20)
		$modules.Path[$_.key]["UI1"].Add_CheckStateChanged({
			Write-Host $this.Text
		})
		$tooltip.SetToolTip($modules.Path[$_.key]["UI1"], $_.value.desc)
		$groupPaths.Controls.Add($modules.Path[$_.key]["UI1"])
		
		$modules.Path[$_.key]["UI2"] = New-Object System.Windows.Forms.CheckBox
		#$modules.Path[$_.key]["UI2"].Enabled = $false
		$modules.Path[$_.key]["UI2"].Text = "TacO"
		#$modules.Path[$_.key]["UI2"].Checked = $_.value.default
		$modules.Path[$_.key]["UI2"].Location = New-Object System.Drawing.Point(120, (35 + (100 * $i)))
		$modules.Path[$_.key]["UI2"].Size = New-Object System.Drawing.Point(80, 20)
		$modules.Path[$_.key]["UI2"].Add_CheckStateChanged({
			Write-Host $this.Text
		})
		$tooltip.SetToolTip($modules.Path[$_.key]["UI2"], $_.value.desc)
		$groupPaths.Controls.Add($modules.Path[$_.key]["UI2"])

		$i++
	}

	$main_form.Controls.Add($groupPaths)

# BLISH MODULES
	$groupModules = New-Object System.Windows.Forms.GroupBox
	$groupModules.Location = New-Object System.Drawing.Size(($groupBlish.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))
	$groupModules.AutoSize = $true
	$groupModules.AutoSizeMode = 1
	$groupModules.text = "Blish HUD modules"

	$i = 0
	$modules.ArcDPS.GetEnumerator() | foreach {
		$modules.ArcDPS[$_.key]["UI"] = New-Object System.Windows.Forms.CheckBox
		$modules.ArcDPS[$_.key]["UI"].Enabled = $false
		$modules.ArcDPS[$_.key]["UI"].Text = $_.value.name
		$modules.ArcDPS[$_.key]["UI"].Checked = $_.value.default
		$modules.ArcDPS[$_.key]["UI"].Location = New-Object System.Drawing.Point(10, (20 + (20 * $i)))
		$modules.ArcDPS[$_.key]["UI"].Size = New-Object System.Drawing.Point(200, 20)
		$modules.ArcDPS[$_.key]["UI"].Add_CheckStateChanged({
			Write-Host $this.Text
		})
		$tooltip.SetToolTip($modules.ArcDPS[$_.key]["UI"], $_.value.desc)
		$groupModules.Controls.Add($modules.ArcDPS[$_.key]["UI"])

		$i++
	}

	$main_form.Controls.Add($groupModules)



# STUFF


	if (
		($groupBlish.Height -le $groupArc.Height) -and
		($groupTaco.Height -le $groupArc.Height)
	) {
		$groupBlish.Height = $groupArc.Height
		$groupTaco.Height = $groupArc.Height
	} elseif (
		($groupArc.Height -le $groupTaco.Height) -and
		($groupBlish.Height -le $groupTaco.Height)
	) {
		$groupArc.Height = $groupTaco.Height
		$groupBlish.Height = $groupTaco.Height
	} else {
		$groupArc.Height = $groupBlish.Height
		$groupTaco.Height = $groupBlish.Height
	}


#groupArc
	if (
		($groupTaco.Width -le $groupArc.Width) -and
		($groupBlish.Width -le $groupArc.Width) -and
		($groupAddons.Width -le $groupArc.Width) -and
		($groupPaths.Width -le $groupArc.Width) -and
		($groupModules.Width -le $groupArc.Width)
	) {
		$groupTaco.Width = $groupArc.Width
		$groupBlish.Width = $groupArc.Width
		$groupAddons.Width = $groupArc.Width
		$groupPaths.Width = $groupArc.Width
		$groupModules.Width = $groupArc.Width
#groupTaco
	} elseif (
		($groupArc.Width -le $groupTaco.Width) -and
		($groupBlish.Width -le $groupTaco.Width) -and
		($groupAddons.Width -le $groupTaco.Width) -and
		($groupPaths.Width -le $groupTaco.Width) -and
		($groupModules.Width -le $groupTaco.Width)
	) {
		$groupArc.Width = $groupTaco.Width
		$groupBlish.Width = $groupTaco.Width
		$groupAddons.Width = $groupTaco.Width
		$groupPaths.Width = $groupTaco.Width
		$groupModules.Width = $groupTaco.Width
#groupBlish
	} elseif (
		($groupArc.Width -le $groupBlish.Width) -and
		($groupTaco.Width -le $groupBlish.Width) -and
		($groupAddons.Width -le $groupBlish.Width) -and
		($groupPaths.Width -le $groupBlish.Width) -and
		($groupModules.Width -le $groupBlish.Width)
	) {
		$groupArc.Width = $groupBlish.Width
		$groupTaco.Width = $groupBlish.Width
		$groupAddons.Width = $groupBlish.Width
		$groupPaths.Width = $groupBlish.Width
		$groupModules.Width = $groupBlish.Width
#groupAddons
	} elseif (
		($groupArc.Width -le $groupAddons.Width) -and
		($groupTaco.Width -le $groupAddons.Width) -and
		($groupBlish.Width -le $groupAddons.Width) -and
		($groupPaths.Width -le $groupAddons.Width) -and
		($groupModules.Width -le $groupAddons.Width)
	) {
		$groupArc.Width = $groupAddons.Width
		$groupTaco.Width = $groupAddons.Width
		$groupBlish.Width = $groupAddons.Width
		$groupPaths.Width = $groupAddons.Width
		$groupModules.Width = $groupAddons.Width
#groupPaths
	} elseif (
		($groupArc.Width -le $groupPaths.Width) -and
		($groupTaco.Width -le $groupPaths.Width) -and
		($groupBlish.Width -le $groupPaths.Width) -and
		($groupAddons.Width -le $groupPaths.Width) -and
		($groupModules.Width -le $groupPaths.Width)
	) {
		$groupArc.Width = $groupPaths.Width
		$groupTaco.Width = $groupPaths.Width
		$groupBlish.Width = $groupPaths.Width
		$groupAddons.Width = $groupPaths.Width
		$groupModules.Width = $groupPaths.Width
#groupModules
	} else {
		$groupArc.Width = $groupModules.Width
		$groupTaco.Width = $groupModules.Width
		$groupBlish.Width = $groupModules.Width
		$groupAddons.Width = $groupModules.Width
		$groupPaths.Width = $groupModules.Width
	}

	$groupTaco.Location = New-Object System.Drawing.Size(($groupArc.Location.X + $groupArc.Width + 10) , $groupArc.Location.Y)
	$groupBlish.Location = New-Object System.Drawing.Size(($groupTaco.Location.X + $groupTaco.Width + 10) , $groupArc.Location.Y)

	$groupPaths.Location = New-Object System.Drawing.Size(($groupTaco.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))
	$groupModules.Location = New-Object System.Drawing.Size(($groupBlish.Location.X), ($groupArc.Location.Y + $groupArc.height + 10))



	$main_form.ShowDialog()

<#
    CheckBox – used to list some options and select them prior to running script;
    RadioButton – lists some text options and allows to select only one of them;
    TextBox – user can write some text. It can be used to get the value of the PoSh script parameter;
    Label – used for labeling some parts of scripts’ GUI;
    ChekedListBox – shows a list of items;
    DataGridView – allows to view some tabular data;
    GroupBox – allows viewing and grouping a set of controls together;
    ListBox – can store several text items;
    TabControl – allows you to split your form into different areas (tabs);
    ListView – displays a list of items with text and (optionally) an icon;
    TreeView – hierarchical objects view;
    DateTimePicker – allows to select date and time;
    TrackBar – scrollable control;
    PictureBox – allows to show a picture on the form;
    ProgressBar – indicates the operation progress;
    HScrollBar – horizontal scroll bar;
    VScrollBar – vertical scroll bar;
    ContextMenu – right-click menus;
    Menu – top menu in your form.
#>

	exit
}

#no more "big" testing stuff


# you really really don't need to change anything here - except you know exactly what you are doing


#some magic stuff for pathes and options

param($GW2_path_old, $TacO_path_old, $BlishHUD_path_old, $use_ArcDPS_old, $use_TacO_old, $use_BHud_old)

$MyDocuments_path = [Environment]::GetFolderPath("MyDocuments")
$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$checkfile = "$Script_path\checkfile"

# some functions for lazy people

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
	nls 2
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
	nls 2
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

$TacO_path = $conf.installation_paths.TacO

if ($conf.installation_paths.BlishHUD -eq $null) {
	nls 2
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
	nls 2
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
	nls 2
	$default = $true

	Write-Host "ArcDPS " -NoNewline -ForegroundColor Yellow
	Write-Host "is a great tool to monitor the DPS and other stuff of you and your group. (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"
	Write-Host "Warning: sometimes the game crashes after updates, especially after some game updates. This is may caused by ArcDPS. If this happens delete: " -NoNewline -ForegroundColor Red
	Write-Host "$GW2_path\bin64\d3d9.dll " -NoNewline
	Write-Host "and " -NoNewline -ForegroundColor Red
	Write-Host "$GW2_path\d3d11.dll " -NoNewline
	Write-Host "(only one should be there) Keep this warning in mind!" -ForegroundColor Red

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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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

if ($conf.settings_ArcDPS.dx9 -eq $null) {
	nls 2
	$default = $true

	Write-Host "The game uses " -NoNewline
	Write-Host "DirectX9 " -NoNewline -ForegroundColor Yellow
	Write-Host "as default. ArcDPS and all its dependencies will NOT work if you swap to " -NoNewline
	Write-Host "DirectX11 " -NoNewline -ForegroundColor Yellow
	Write-Host "in the ingame video-settings."
	Write-Host "The settings here needs to match your video settings."
	Write-Host "If you change it without changing the ArcDPS version the game may crash when you try to start it." -ForegroundColor Yellow
	Write-Host "Remember this setting - changing the DirectX9 ingame later on may makes the game unplayable until you delete ArcDPS from your system." -ForegroundColor Red
	Write-Host "Do you want this script to install ArcDPS for DirectX9 instead of DirectX11? (default: " -NoNewline
	Write-Host $default -NoNewline -ForegroundColor White
	Write-Host ")"

	if (-not $conf.configuration.defaultmode) {
		if (-not $conf.configuration.update_ArcDPS) {
			Write-Host "ArcDPS will not get installed or updated. Choose n!" -ForegroundColor Red
		}

		do {
			$input = Read-Host -Prompt "Type 9 if you play Guildwars2 using DirectX9, or 11 if you use DirectX11: "
		} while (-not(
			($input -eq "9") -or
			($input -eq "11") -or
			($input -eq "ll")
		))

		$default = $input -eq "9"
	}

	$conf["settings_ArcDPS"]["dx9"] = $default

	Out-IniFile -InputObject $conf -FilePath "$Script_path\GW2start.ini"
}

if ($conf.settings_ArcDPS.killproof -eq $null) {
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
			$input = Read-Host -Prompt "Type y to autoupdate Quci Surrender-Module, n if don't want it: "
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
	nls 2
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
			Write-Host "BlishHUD-pathing-Module will not used for map-packs. Choose n!!" -ForegroundColor Red
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

if ($conf.versions -eq $null) {
	$conf["versions"] = @{}
}

# clean up before anything else starts

stopprocesses

# some information for our user (yes, I'm talking about YOU, you creepy coder)

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
