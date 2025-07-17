# Script to get a snapshot of the current Windows Defender configurations on this PC
# Next compare them with the expected values defined in the Policy File
# Copyright 2025 TheNetWorks LLC 
# Last Revision 7/17/25

function Remove-BomFromFile ($OldPath, $NewPath)
{
  $Content = Get-Content $OldPath -Raw
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [IO.File]::WriteAllLines($NewPath, $Content, $Utf8NoBomEncoding)
}

# Execution starts here --------------------------------------------------

$OrgFile     = "\TheNetWorks\DefenderPrefsBOM.txt"
$PrefsData   = "\TheNetWorks\DefenderPrefs.txt"
$PrefsPolicy = "\TheNetWorks\DefenderPrefs.cfg."

# Set default encoding to UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Set the Console Width as wide as possible so we minimize wrapped lines
$SaveWindow = $host.UI.RawUI.WindowSize		# Remember Current

$host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(240, 44)

# Now Restore the Window Size
$host.UI.RawUI.WindowSize = $SaveWindow		# Restore Value

# Get the statistics and write to the file
Get-MpPreference | Out-File $OrgFile -Encoding UTF8

Remove-BomFromFile -OldPath $OrgFile -NewPath $PrefsData

del $OrgFile

# Now that we have gathered the configurations Parse them for compliance
/TheNetWorks/DefenderMon.exe $PrefsData $PrefsPolicy
