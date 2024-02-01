# Script to use ARP to get network devices announced to this PC and get the 
# Hostname of the device. Focuses on dynamic ARP entries attempting to avoid
# all the multicast entries typically present - and unresolvable
# Copyright 2024 TheNetWorks LLC

$NameServer=10.0.1.1
$DEVS=arp -a

foreach($LINE in $DEVS){
  # Only Process Entries marked dynamic (static are generally multicast)
  $TokenStr = $LINE.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)

  $TYPE=$TokenStr[2]
  if($TYPE -eq "dynamic") {
    $IP=$TokenStr[0]
    $MAC=$TokenStr[1]
    $NameStr=Resolve-DnsName $IP -Server $NameServer 2> $nul
    if($NameStr) {
      $Name=$NameStr.NameHost}
    else {
      $Name="Unknown"}

    # Output the Record
    "{0, -16} {1, -20} {2, -20}" -f $IP, $MAC, $Name
  }
}