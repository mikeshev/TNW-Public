# Installer for TneNetWorks tools on a new machine
# Creates the directory TheNetWorks then pulls the archive from github and unpacks it
# Copyright 2023 TheNetWorks LLC
# To enable this script running execute: 
# Set-ExecutionPolicy -Scope Process Unrestricted

$ArchiveName = "InstallTNW.zip"
$UriTnwTools = "https://github.com/mikeshev/TNW-Public/blob/main/Tools/"
$FullUrl = $UriTnwTools + $ArchiveName + "?raw=true"

md /TheNetWorks | Out-Null
cd /TheNetWorks

# Pull the Archive from GitHub
Invoke-WebRequest -Uri $FullUrl -UseBasicParsing -Outfile $ArchiveName

# Extract the components from the Archive into this directory TheNetWorks
tar xvf InstallTNW.zip
del InstallTNW.zip

# Install the Redistributable package
./VC_redist.x86.exe /Q /Passive