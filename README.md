# GW2-updater-script
updating all the nice helpers for Guildwars 2 automaticly

# install

to share or download GW2start use this direct link: https://github.com/Tinsus/GW2-updater-script/archive/refs/heads/main.zip

You only need the GW2start.bat file containing in the downloaded archive.
Place it somewhere in your filesystem and add a shortcut to it e.g. on your Desktop.

than run GW2start by your shortcut or double-clicking the GW2start.bat

# config

on first usage the window will open with some questions for you to answer.

for easy-mode choose the default-mode, if you like to config everything on your own choose the pro-mode.

GW2start will add a GW2start.ini file next to the GW2start.bat files containing all your settings. If you want to edit them open the file using editor or deleate the file to restart the configuration the next time you open the script.

# usage

from now on start GW2 by double clicking the GW2start.bat file (only).

nothing is more easy as adding a shortcut to your desktop to start the .bat file from there instead of your regular GW2-shortcut

Please hold in mind: ArcDPS causes GW2 crashes if your PC is running Razer Cortex. Cause of that - if you did not disabled ArcDPS in configuration - the script automaticly closes Razer Cortex.

# troubleshooting

If the script don't work the first time make sure to check the file settings of the downloaded .bat-file: add the tick for downloaded files to be executable in the file properties.

Powershell need to be set to allow script files from your computer this is done automatically but you need do give administrators privileges once OR change tzhe ExecutionPolicy yourself by open powershell as administrator and do: Set-ExecutionPolicy RemoteSigned -Force
