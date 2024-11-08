REM Script to open ports for Windows Device Management 

REM Add Ping
netsh advfirewall firewall add rule name="All ICMP V4" protocol=icmpv4:any,any dir=in action=allow

REM Add Remote Desktop
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes

REM Enable PDQ Management - Open Ports
netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes
netsh advfirewall firewall add rule name="TNW: Open Port 135" dir=in action=allow protocol=TCP localport=135
netsh advfirewall firewall add rule name="TNW: Open Port 139" dir=in action=allow protocol=TCP localport=139
netsh advfirewall firewall add rule name="TNW: Open Port 445" dir=in action=allow protocol=TCP localport=445
netsh advfirewall firewall add rule name="TNW: Open UDP Port 137" dir=in action=allow protocol=UDP localport=137
netsh advfirewall firewall add rule name="TNW: Open UDP Port 138" dir=in action=allow protocol=UDP localport=138
netsh advfirewall firewall add rule name="TNW: Open UDP Port 445" dir=in action=allow protocol=UDP localport=445
winrm quickconfig -force