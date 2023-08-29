# General Purpose Installation Program to copy binaries from the Public TNW-Tools area on github
# Copyright 2023 TheNetWorks LLC

$ArchiveName = $args[0]

$UriTnwTools = "https://github.com/mikeshev/TNW-Public/blob/main/Tools/"
$FullUrl = $UriTnwTools + $ArchiveName + "?raw=true"

Invoke-WebRequest -Uri $FullUrl -UseBasicParsing -Outfile $ArchiveName
