# TheNetWorks LLC - Pre Qualification script
# Copyright 2024 TheNetWorks LLC
# May need to set execution polciy prior to execution
# Version 1.2 Added AV Scanning Option
# Version 1.3 Added Local User Account checking

param (
    [string]$AvMode = "none",
    [Parameter(Mandatory=$false)][string]$ScanTyoe
)

$PrequalVersion = "1.3"

# Output banner and version
Write-Output " ------ TheNetWorks Pre-Qualification Analysis Version: $PrequalVersion ------- "

# Set-ExecutionPolicy -Scope Process Unrestricted
Write-Output " ------ Set-ExecutionPolicy -Scope Process Unrestricted ------- "

Write-Output "`r`n---------- Getting Disk Health ----------"
Get-PhysicalDisk
Start-Sleep 1

# Checking basic Disk Health
Write-Output "`r`n---------- Running chkdsk -----------"
# Make sure the disk itself is sound
chkdsk /scan c: /perf

# Make sure the Image is Sound
Write-Output "`r`n---------- Check Deployment Image ----------"
dism /online /cleanup-image /ScanHealth

Write-Output "`r`n--------- Running System File Checker ---------"
sfc /scannow

# Make sure updates have been happening
Write-Output "`r`n--------- Check for Windows Updates ---------"
(get-wmiobject -class win32_quickfixengineering | Out-String).Trim()

# Check Quarantine files
Write-Output "`r`n--------- Check for Quarantine Files ---------"
c:\"Program Files\Windows Defender"\MpCmdRun.exe -restore -listall

Write-Output "`r`n--------- Check for User Access Control Settings ---------"
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

# Check Startup Programs; looking for anything ususual
Write-Output "`r`n--------- Check Startup Programs ---------"
(Get-CimInstance Win32_StartupCommand).Command

# Check System Restore Configuration
Write-Output "`r`n--------- Check System Restore Configuration ---------"
(Get-ComputerRestorePoint | Out-String).Trim()

if($AvMode -ne "none"){
  if($AvMode -eq "Quick") {
    Write-Output "`r`n--------- Running Quick AV Scan (2-3 minutes) ---------" 
    Start-MpScan -ScanType QuickScan
  }
  elseif($AvMode -eq "Full") {
    Write-Output "`r`n--------- Running Full AV Scan (45-90 minutes) ---------" 
    Start-MpScan -ScanType FullScan
  }
  Get-MpThreatDetection
}

Write-Output "`r`n--------- Find Local User Accounts ---------"
(Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount=True" | Select Name, Disabled, Lockout, PasswordRequired | Out-String).Trim()

Write-Output "`r`n--------- Find Local Admin Accounts ---------"
((Get-WmiObject -Class Win32_Group -Filter "LocalAccount = TRUE and SID = 'S-1-5-32-544'").GetRelated("Win32_UserAccount", "Win32_GroupUser", "", "", "PartComponent", "GroupComponent", $false, $null)).Name

# Lastly check the Event Log for recent Critical Errors
Write-Output "`r`n --------- Launching Windows Event Log ---------"
eventvwr /c:System
