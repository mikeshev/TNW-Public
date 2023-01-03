# Collect all the data and compute the risk score on a system
# Copyright TheNetWorks 2022

function Remove-BomFromFile ($OldPath, $NewPath)
{
  $Content = Get-Content $OldPath -Raw
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [IO.File]::WriteAllLines($NewPath, $Content, $Utf8NoBomEncoding)
}

# Execution starts here --------------------------------------------
$VerboseFlag=$args[0]

$ResetsBOM = "\TheNetWorks\resetsBOM.txt"
$ResetsClr = "\TheNetWorks\resets.txt"
$PatchesInstalled = "\TheNetWorks\Installs.csv"
$PatchesTemp = "C:\TheNetWorks\updates.csv"

cd /TheNetWorks

# Set default encoding to UTF8; PowerShell defaults to multibyte
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Clear the environment of old files
if(test-path $PatchesInstalled){
  Remove-Item $PatchesInstalled
}
if(test-path $PatchesTemp){
  Remove-Item $PatchesTemp
}

# Start by getting the system restarts available in the Event Log. Note this is limited and older history deleted
#Write-Output "Getting System Reset Data"
wevtutil qe system "/q:*[System [(EventID=6005)]]" /rd:true /f:text | Select-String "Date:" > $ResetsBOM

Remove-BomFromFile -OldPath $ResetsBOM -NewPath $ResetsClr
del $ResetsBOM

# Next find all the patches installed on this system and output in CSV. Beware it contains everything including
# Microsoft Defender updates (can be more than 2x a day). Script from https://ss64.com/ps/get-hotfix.html
# Write-Output "Getting System Patch Data"

$Session = New-Object -ComObject "Microsoft.Update.Session"
$Searcher = $Session.CreateUpdateSearcher() 
$historyCount = $Searcher.GetTotalHistoryCount() 
$Searcher.QueryHistory(0, $historyCount) | Select-Object Title, Description, Date,     
   @{name="Operation"; expression={switch($_.operation){
         1 {"Installation"}; 2 {"Uninstallation"}; 3 {"Other"}
   }}},
   @{name="Status"; expression={switch($_.resultcode){
            1 {"In Progress"}; 2 {"Succeeded"}; 3 {"Succeeded With Errors"};
            4 {"Failed"}; 5 {"Aborted"}
            }}},
   @{name="KB"; expression={($_.title -split "(KB*.*)")[1]}} | export-csv $PatchesTemp -append -noTypeInformation

move $PatchesTemp $PatchesInstalled

# Now get the release days of Microsoft patches (Hmm)

# Run the Calculationn Engine which reads all the data files and computes
# ResetRiskScore: From Update Installed until system is rebooted
# Overall Risk Score from when the patch is released and when the system is rebooted
# Write-Output "Running the Risk Score Calculator"
/TheNetWorks/RiskScore.exe $VerboseFlag
