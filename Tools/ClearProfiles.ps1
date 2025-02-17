# Script to clear accumulated user profiles. Expects to be run directly from the mounted USB Drive
# Copyright TheNetWorks LLC 2025

# $ProfilePattern='resident*'
$ProfilePattern='mshev_*'

# If no arguments execute a test run only
if($args[0] -eq $null) {
  Write-Host "Doing a sample run with the pattern $ProfilePattern"
  ./delprof2 /l /id:$ProfilePattern
}
else {
  # Argument passed: Now really delete profiles"
  Write-Host "Deleting Profiles with Pattern $ProfilePattern"
  ./delprof2 /id:$ProfilePattern
}


