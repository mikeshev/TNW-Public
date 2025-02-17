# Script to Lockdown Chrome & Edge Browsers so users can uses incognito/private nor
# Delete the History
# Copyright TheNetWorks LLC 2025

# If no arguments assume we are setting up Lockdown
if($args[0] -eq $null){
  Write-Host "Disabling Incognito/Inprivate and ability to delete browser history"
  # Disable Incognito/Inprivate for Chrome & Edge
  reg add HKLM\SOFTWARE\Policies\Google\Chrome /v IncognitoModeAvailability /t REG_DWORD /d 1 /f
  reg add HKLM\SOFTWARE\Policies\Microsoft\Edge /v InPrivateModeAvailability /t REG_DWORD /d 1 /f

  # Disable Delete Browser History: Chrome & Edge
  reg add HKLM\Software\Policies\Google\Chrome /v AllowDeletingBrowserHistory /t REG_DWORD /d 0 /f
  reg add HKLM\Software\Policies\Microsoft\Edge /v AllowDeletingBrowserHistory /t REG_DWORD /d 0 /f
}
else {  # if any argument is given assume its to back out changes. Maybe smarter parsing later
  Write-Host "Re-eabling Incognito/Inprivate and ability to delete browser history"
  # Section to Re-enable the items above
  reg add HKLM\SOFTWARE\Policies\Google\Chrome /v IncognitoModeAvailability /t REG_DWORD /d 0 /f
  reg add HKLM\SOFTWARE\Policies\Microsoft\Edge /v InPrivateModeAvailability /t REG_DWORD /d 0 /f

  # Re-enable Delete Browser History: Chrome & Edge
  reg add HKLM\Software\Policies\Google\Chrome /v AllowDeletingBrowserHistory /t REG_DWORD /d 1 /f
  reg add HKLM\Software\Policies\Microsoft\Edge /v AllowDeletingBrowserHistory /t REG_DWORD /d 1 /f
}


