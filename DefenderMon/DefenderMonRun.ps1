# Copyright 2022 TheNetWorks LLC 
# Last Revision 4/25/22
# Script to get a snapshot of the current versions on an updated machine

function Remove-BomFromFile ($OldPath, $NewPath)
{
  $Content = Get-Content $OldPath -Raw
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [IO.File]::WriteAllLines($NewPath, $Content, $Utf8NoBomEncoding)
}

# Execution starts here --------------------------------------------------

$OrgFile = "\TheNetWorks\DefenderStatBOM.txt"
$OutFile = "\TheNetWorks\DefenderStat.txt"
$VerUrl="https://www.microsoft.com/en-us/wdsi/defenderupdates"
$VerFile="\TheNetWorks\DefenderStat.cfg"

# Get the web page and extract the version numbers
$VerStr1=\windows\system32\curl -s $VerUrl | find '"Version: "'
$VerStr2=$VerStr1 -replace  '<[^>]+>',''
$VerStr3=$VerStr2 -replace '\s+',''
$VerStr3 -replace ':',' ' | Out-File $VerFile -Encoding UTF8

# Set default encoding to UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Get the statistics and write to the file
Get-MpComputerStatus | Out-File $OrgFile -Encoding UTF8

Remove-BomFromFile -OldPath $OrgFile -NewPath $OutFile

del $OrgFile

# Now that we have gathered the statistics Parse them for compliance
/TheNetWorks/DefenderMon.exe $OutFile
