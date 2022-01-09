# GW2-updater-script
updating all the nice helpers for Guildwars 2 automaticly

# install

config your PowerShell installation before using the script

start PowerShell as admin once and type:

Set-ExecutionPolicy "RemoteSigned" -Force

# config

open the .bat file and:
- setup GW2_path to the installation path of Guildwars 2
- setup TacO_path to where you want TacO to be installed. Don't choose your Documents or Guildwars 2 folder for that
- setup BlishHUD_path to where you want BlishHub to be installed. Don't choose your Documents or Guildwars 2 folder for that

- set use_ArcDPS to 0 if you don't want to get ArcDPS installed, 1 means enabled and is the default value
- set use_TacO to 0 if you don't want to install, update or open TacO, 1 means enabled and is the default value
- set use_BHud to 0 if you don't want to install, update or open BlishHud, 1 means enabled and is the default value


-> info: make sure to enable the donwloaded modules within the BlishHud Userinterface yourself

# usage

from now on start GW2 by double clicking the .bat file (only).

nothing is more easy as adding a shortcut to your desktop to start the .bat file from there instead of your regular GW2-shortcut

# download

to share or download this file use this direct link: https://github.com/Tinsus/GW2-updater-script/archive/refs/heads/main.zip


# troubleshooting

if the script don't work the first time make sure:

- you did the config change in powershell under the install headline
- check the file settings of the two downloaded files: make sure the tick is set for downloaded files to be executable

if you don't make this changes the script will open and close without doing anything in under 1 second
