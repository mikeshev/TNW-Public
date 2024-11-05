# TheNetWorks LLC - Pre Qualification script
# Copyright 2024 TheNetWorks LLC
# May need to set execution polciy prior to execution

param (
    [string]$AvMode = "none",
    [Parameter(Mandatory=$false)][string]$ScanTyoe
)

$PrequalVersion = "1.2"	# Added AV Scanning Option

# Output banner and version
Write-Output " ------ TheNetWorks Pre-Qualification Analysis Version $PrequalVersion ------- "

# Set-ExecutionPolicy -Scope Process Unrestricted
Write-Output " ------ Set-ExecutionPolicy -Scope Process Unrestricted ------- "

# Checking basic Disk Health
Write-Output "----------Running chkdsk -----------"

# Make sure the disk itself is sound
chkdsk /scan c:

Write-Output "---------- Getting Disk Health ----------"
Get-PhysicalDisk

# Make sure the Image is Sound
Write-Output "---------- Check Deployment Image ----------"
dism /online /cleanup-image /ScanHealth

Write-Output "--------- Running File System Checker ---------"
sfc /scannow

# Make sure updates have been happening
Write-Output "--------- Check for Windows Updates ---------"
get-wmiobject -class win32_quickfixengineering | Format-Table

# Check Quarantine files
Write-Output "--------- Check for Quarantine Files ---------"
c:\"Program Files\Windows Defender"\MpCmdRun.exe -restore -listall
Write-Output ""

Write-Output "--------- Check for User Access Control Settings ---------"
# Check UAC Prompts are enabled correctly
$Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" 

# Inititalize the String Variables
$UAC_Str = "Disabled,"		# Values: 0=Disabled, 1=Enabled
$Consent_Str = "Disabled,"	# Values: 0=No Consent, No Auth, 2=Prompt for Consent, 5=Prompt Admins(default)
$Prompt_Str = "Disabled"	# Values: 0=Disabled, 1=Enabled

# Get the UAC Enabled & Settings
$UAC_Value			  = Get-ItemPropertyValue -Path $Key -Name 'EnableLUA' -ErrorAction SilentlyContinue
$ConsentPromptBehaviorAdmin_Value = Get-ItemPropertyValue -Path $Key -Name "ConsentPromptBehaviorAdmin"
$PromptOnSecureDesktop_Value	  = Get-ItemPropertyValue -Path $Key -Name "PromptOnSecureDesktop" 

if ($null -eq $UAC_Value) { $UAC_Str = "Not Configured" }
elseif ($UAC_Value -eq 0) { $UAC_Str = "Disabled" }
else { $UAC_Str = "Enabled" }

if ($ConsentPromptBehaviorAdmin_Value -eq 5)		{ $Consent_Str = "Default" }
elseif ($ConsentPromptBehaviorAdmin_Value -eq 2)	{ $Consent_Str = "Most Secure" }
elseif ($ConsentPromptBehaviorAdmin_Value -eq 0)	{ $Consent_Str = "Not Secure" }
else { $Consent_Str = $ConsentPromptBehaviorAdmin_Value }

if ($PromptOnSecureDesktop_Value -eq 1 ) { $Prompt_Str = "Enabled" }

Write-Output "UAC is  $UAC_Str, ConsentPromptBehavior is $Consent_Str, Prompt is $Prompt_Str"
Write-Output ""

# Check Startup Programs; looking for anything ususual
Write-Output "--------- Check Startup Programs ---------"
wmic startup get command
Write-Output ""

# Check System Restore Configuration
Write-Output "--------- Check System Restore Configuration ---------"
Get-ComputerRestorePoint
Write-Output ""

if($AvMode -ne "none"){
  if($AvMode -eq "Quick") {
    Write-Output "--------- Running Quick AV Scan (2-3 minutes) ---------" 
    Start-MpScan -ScanType QuickScan
  }
  elseif($AvMode -eq "Full") {
    Write-Output "--------- Running Full AV Scan (45-90 minutes) ---------" 
    Start-MpScan -ScanType FullScan
  }
  Get-MpThreatDetection
  Write-Output ""
}

# Lastly check the Event Log for recent Critical Errors
Write-Output "--------- Check Windows Event Log ---------"
eventvwr /c:System
