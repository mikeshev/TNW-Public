function Get-Extensions {
<#
 .SYNOPSIS
    Gets Browser Extensions from a local or remote computer
 .DESCRIPTION
    Gets the name, version and description of the installed extensions
    Admin rights are required to access other profiles on the local computer or
    any profiles on a remote computer.
    Internet access is required to lookup the extension ID on the web store
 .PARAMETER Computername
    The name of the computer to connect to
    The default is the local machine
 .PARAMETER Username
    The username to query i.e. the userprofile (c:\users\<username>)
    If this parameter is omitted, all userprofiles are searched
 .EXAMPLE
    PS C:\> Get-Extensions
    This command will get the Browser extensions from all the user profiles on the local computer
 .EXAMPLE
    PS C:\> Get-Extensions -username Jsmith
    This command will get the Browser extensions installed under c:\users\jsmith on the local computer
 .EXAMPLE
    PS C:\> Get-Extensions -Computername PC1234,PC4567
    This command will get the Browser extensions from all the user profiles on the two remote computers specified
 .NOTES
    Version 1.0
    Author:GD
    Website: write-verbose.com
    Twitter: @writeverbose
#>
    [cmdletbinding()]
    PARAM(
        [parameter(Position = 0)]
        [string]$Computername = $ENV:COMPUTERNAME
        ,
        [parameter(Position = 1)]
        [string]$Username
    )
    BEGIN {
        #REGION --- Child functions

        function Print-State($ExtID, $State) {
            "{0, -32} {1, 4}" -f $ExtID, $State
        }

        # Access Preferences file; run parser. Called 1X for each user/profile/browser combo
        function Get-Pref-Data($Username, $Vendor, $Browser, $Profile) {
            $PrefPath="/Users/$Username/AppData/Local/$Vendor/$Browser/User Data/$Profile/Preferences"

            if($Browser -eq "Edge"){
                # Hack to fix non-compliant JSON parser. Spec is case sensitive but MS Parser is NOT
                $Str=Get-Content $PrefPath		# Read file into a String
                $Pos=$Str.IndexOf('"extensions":')	# Get Position of new start
                $Str2=$Str.Substring($Pos)		# Form new string from old

                return $Str2.Insert(0, '{') | ConvertFrom-Json	# Insert a leading '{'
            }
            else {
                return Get-Content $PrefPath | ConvertFrom-Json
            }
        }

        function Get-Ext-State($ExtID, $Prefs) {
            $State=$Prefs.extensions.settings.$ExtID.state
            return $State
        }

        function Q($Var){	# All Text Arguments in SQL Query must be enclosed in single quotes
          return "'" + $Var + "'"
        }

        function AddRec($ID, $Name, $State, $Browser, $Version, $DateInst, $User, $Profile, $Hostname, $Score, $Estimate){

            # Quote all text Arguments for SQL Query formatting
            $ID=Q($ID)
            $Name=Q($Name)
            $State=Q($State)
            $Browser=Q($Browser)
            $Version=Q($Version)
            $DateInst=Q($DateInst)
            $User=Q($User)
            $Profile=Q($Profile)
            $Hostname=Q($Hostname)
            $Score=Q($Score)

            $NewRec="INSERT INTO Extensions(ScanDate, ScannerVer, ID, Name, State, Browser, Version, Installed, User, Profile, Hostname, Score, Estimate) VALUES($ScanDate, $ScannerVer, $ID,  $Name, $State, $Browser, $Version, $DateInst, $User, $Profile, $Hostname, $Score, $Estimate);"

            Invoke-SqliteQuery -Query $NewRec -SQLiteConnection $Conn
            }

        # Get the risk of the "latest" version of the extension (even though that version is not installed)
        function Get-LatestVer($ExtensionID)
        {
            $Ext_Url = "https://api.crxcavator.io/v1/report/$ExtensionID" + "?platform=$Browser"

            $ExtResponse=Invoke-WebRequest -Uri $Ext_Url -UseBasicParsing

            # Get location to after "version": tag
            $RespLength=$ExtResponse.RawContentLength

            if($RespLength -gt 100){	# some reasonable (non-null) response
                # Next find the last "version" tag
                $index=$ExtResponse.Content.LastIndexOf("version")

                $LatestVerStr=$ExtResponse.Content.SubString($index+10, 15)
                $LatestVerStr=($LatestVerStr.Split('"'))[0]
             }
        return $LatestVerStr
        }

        function Get-ExtRisk ($ExtensionID, $VerNum) {
            $MatchFound=1	# Assume we'll find it!

            # Check a couple non-store Extensions
            if($ExtID -eq "nmmhkkegccagdldgiimedpiccmgmieda") {
                return 0 }		# Google Wallet
            if($ExtID -eq "mhjfbmdgcfjbbpaeojofohoefgiehjai") {
                return 0 }		# Chrome PDF Viewer
            if($ExtID -eq "ghbmnnjooekpmoecnnnilnnbdlolhkhi") {
                return 0 }		# Microsoft Edge Addons

            $Ext_Url = "https://api.crxcavator.io/v1/report/$ExtID/$VerNum" + "?platform=$Browser"
            $ExtResponse=Invoke-WebRequest -Uri $Ext_Url

            if($ExtResponse.RawContentLength -lt 16){
                $LatestVer = Get-LatestVer $ExtensionID

                if(!$LatestVer){	# If empty then not in CRX
                    return "xxx"
                }
                else{		# Make a request with the latest version
                    $Ext_Url = "https://api.crxcavator.io/v1/report/$ExtensionID/$LatestVer" + "?platform=$Browser"
                    $ExtResponse=Invoke-WebRequest -Uri $Ext_Url
                    $MatchFound=0
                }
            }

            $ExtDetails=$ExtResponse | ConvertFrom-Json

            $RiskDetailProps=@{
                ContentSecurityPolicy=$ExtDetails.data.risk.csp.total        
                Permissions=$ExtDetails.data.risk.permissions.total
                RetireJS=$ExtDetails.data.risk.retire.total    
                Webstore =$ExtDetails.data.risk.webstore.total
           }
           $p=@{
                RiskScore=$ExtDetails.data.risk.total
                RiskLevel=switch ($ExtDetails.data.risk.total) {
                    {$_ -le 377} { "L" }
                    {$_ -gt 377 -and $_ -le 478} { "M" }
                    {$_ -gt 478} { "H" }
                    Default {"N/A"}
                }
            }

            if($MatchFound -eq 0){
                # Signify that we DIDN'T find and exact match
                return $ExtDetails.data.risk.total.ToString() + "*"}
            else{
                return $ExtDetails.data.risk.total}
        }

        function Write-Ext-Details($Extension, $Version) {

            $ThisPath="C:\Users\$UserName\AppData\Local\$Vendor\$Browser\User Data\$Profile\Extensions\$Extension"
            $ExtDate = Get-ChildItem -Path $ThisPath | Get-Date -Format "MM/dd/yy"
            # If there are multiple versions of the SAME extension you'll get multiple dates. Pick latest
            if($ExtDate.Count -gt 1){
                $ExtDate = $ExtDate[0]}

            $W_Title=21
            $W_Version=13
            $W_Date=8
            $W_UserName=12
            $W_Profile=9
            $W_Computer=12
            $W_ExtRisk=4

            $ExtRisk = Get-ExtRisk $Extension $Version

            # Now write this data to the database
            $Estimate=0	# Assume not estimated

            if($ExtRisk.GetType() -is [int]){	# If estimated it is a string-not int
                $Estimate=1
                $ExtRisk = $ExtRisk.Trim("*")
            }

            # Output to Db before truncating happens
            AddRec $Extension $Title $State $Browser $Version $ExtDate $UserName $Profile $Computer $ExtRisk $Estimate

            # Truncate field lengths for sake of display in Pulsweay
            if($Title.length -gt $W_Title){
                $Title=$Title.substring(0,$W_Title)}
            if($Version.length -gt $W_Version){
                $Version=$Version.substring(0,$W_Version)}
            if($UserName.length -gt $W_UserName){
                $UserNameStr=$UserName.substring(0,$W_UserName)}
            if($Computer.length -gt $W_Computer){
                $Computer=$Computer.substring(0,$W_Computer)}

            "{0,-$W_Title} {1,-$W_Version} {2,-$W_Date} {3,-$W_UserName} {4,-$W_Profile} {5,-$W_Computer} {6, -$W_ExtRisk}" -f $Title, $Version, $ExtDate, $UserNameStr, $Profile, $Computer, $ExtRisk
        }

        function Get-ExtensionInfo {
            <#
         .SYNOPSIS
            Get Name and Version of the extension
         .PARAMETER Folder
            A directory object (under %userprofile%\AppData\Local\[Vendor]\[Browser]\User Data\Default\Extensions)
        #>
            [cmdletbinding()]
            PARAM(
                [parameter(Position = 0)]
                [IO.DirectoryInfo]$Folder
            )
            BEGIN{

                $BuiltInExtensions = @{
                    'nmmhkkegccagdldgiimedpiccmgmieda' = 'Google Wallet'
                    'mhjfbmdgcfjbbpaeojofohoefgiehjai' = 'Chrome PDF Viewer'
                    'pkedcjkdefgpdelpbcmbmeomcjbeemfm' = 'Chrome Cast'
                }

            }
            PROCESS {
                $ScannerVer=Q("$ScannerVer")
                $ScanDate=Q(Get-Date -Format "MM/dd/yy")

                # Extension folders are under %userprofile%\AppData\Local\[Vendor]\[Browser]\User Data\Default\Extensions
                # Folder names match extension ID e.g. blpcfgokakmgnkcojhhkbfbldkacnbeo
                $ExtID = $Folder.Name

                if($Folder.FullName -match '\\Users\\(?<username>[^\\]+)\\'){
                    $Username = $Matches['username']
                }else{
                    $Username = ''
                }

                # There can be more than one version installed. Get the latest one
                $LastestExtVersionInstallFolder = Get-ChildItem -Path $Folder.Fullname | Where-Object { $_.Name -match '^[0-9\._-]+$' } | Sort-Object -Property CreationTime -Descending | Select-Object -First 1 -ExpandProperty Name

                # Get the version from the JSON manifest
                if (Test-Path -Path "$($Folder.Fullname)\$LastestExtVersionInstallFolder\Manifest.json") {

                    $Manifest = Get-Content -Path "$($Folder.Fullname)\$LastestExtVersionInstallFolder\Manifest.json" -Raw | ConvertFrom-Json
                    if ($Manifest) {
                        if (-not([string]::IsNullOrEmpty($Manifest.version))) {
                            $Version = $Manifest.version
                        }
                    }
                } else {
                    # Just use the folder name as the version
                    $Version = $LastestExtVersionInstallFolder.Name
                }

                if($BuiltInExtensions.ContainsKey($ExtID)){
                    # Built-in extensions do not appear in the Web Store
                    $Title = $BuiltInExtensions[$ExtID]
                    $Description = ''

                }else{
                    # Lookup the extension in the Store
                    $url = $WebStore + $ExtID + "?hl=en-us"
                    try {
                        # You may need to include proxy information
                        # $WebRequest = Invoke-WebRequest -Uri $url -ErrorAction Stop -Proxy 'http://proxy:port' -ProxyUseDefaultCredentials
                        $WebRequest = Invoke-WebRequest -Uri $url -ErrorAction Stop

                        if ($WebRequest.StatusCode -eq 200) {

                            # Get the HTML Page Title but remove ' - [Vendor] Web Store'
                            if (-not([string]::IsNullOrEmpty($WebRequest.ParsedHtml.title))) {

                                $ExtTitle = $WebRequest.ParsedHtml.title
                                if ($ExtTitle -match '\s-\s.*$') {
                                    $Title = $ExtTitle -replace '\s-\s.*$',''
                                    $extType = $Browser + "Store"
                                } else {
                                    $Title = $ExtTitle
                                }
                            }

                            # Screen scrape the Description meta-data
                            $Description = $webRequest.AllElements.InnerHTML | Where-Object { $_ -match '<meta name="Description" content="([^"]+)">' } | Select-object -First 1 | ForEach-Object { $Matches[1] }
                        }
                    } catch {
                        Write-Warning "Error during webstore lookup for '$ExtID' - '$_'"

                    }
                }
                $State=Get-Ext-State $ExtID $Prefs
                Write-Ext-Details $ExtID $Version
            }
        }#End function
        #ENDREGION -----

        $DefaultExtPath = "AppData\Local\$Vendor\$Browser\User Data\Default\Extensions"
        $ProfilesExtPath = "AppData\Local\$Vendor\$Browser\User Data\Profile *"
    }

    PROCESS {
        Foreach ($Computer in $Computername) {
            $Paths = @()
            $Extensions =@()

            if ($Username) {	# Single userprofile
                $Path = Join-path -path "fileSystem::\\$Computer\C$\Users\$Username" -ChildPath $DefaultExtPath
                if(!(Test-Path -Path $Path))
                {
                    # Try the alternate Profile x path
                    $Path = Join-path -path "fileSystem::\\$Computer\C$\Users\$Username" -ChildPath $ExtensionFolderPath1
                }
                if(Test-Path -Path $Path)	# Check the Path before attempting to Get-ChildItem(s)
                {
                    $Extensions = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
                }
            } else {		# All user profiles (Default & Optional) that contain an extensions folder

                # Get Default user profiles that contains Browser extensions folder
                $DefaultPath = Join-path -path "fileSystem::\\$Computer\C$\Users\*" -ChildPath $DefaultExtPath
                $ProfilesPath = Join-path -Path "fileSystem::\\$Computer\C$\Users\*" -ChildPath $ProfilesExtPath

                $Paths += $DefaultPath

                Get-ChildItem $ProfilesPath -Filter "Profile *" -Directory | %{$_.fullname} | ForEach-Object {
                    $Paths += $_ + "\Extensions"
                }

                ForEach ($ExtPath in $Paths){
                    # Extract the Profile part. Currently supports Default or Profile 1, Profile 2, etc.
                    $Profile=$ExtPath -replace ".*User Data\\"
                    $Profile=$Profile -replace "\\Extensions"
                    Get-Item -Path $ExtPath -ErrorAction SilentlyContinue | ForEach-Object{

                        # Extract the Username from path
                        $Un=$_ -replace '\\AppData.*', ''
                        $Username=$Un -replace '.*\\Users\\',''

                        # Get the data from the Preferences file, 1X per User, Browser Profile Combo
                        $Prefs = Get-Pref-Data $Username $Vendor $Browser $Profile

                        $Extensions += Get-ChildItem -Path $_ -Directory -ErrorAction SilentlyContinue

                        Foreach ($Extension in $Extensions) {
                            if($Extension.ToString() -ne "Temp"){	# Ignore Temp Directory
                                $Output = Get-ExtensionInfo -Folder $Extension
                                $Output | Add-Member -Force -MemberType NoteProperty -Name 'Computername' -Value $Computer
                                $Output}
                            $Extensions =@()
                        }
                    }
                }
            }
        }#foreach
    }
}

# -------------- Execution Starts Here -------------------
$Database="c:/TheNetWorks/sqlite/TNW.db"
#$ScannerVer="1.1"	# Update this for DB Format or major functional changes
$ScannerVer="1.2"	# Write Untruncated fields to the database

$Conn=New-SQLiteConnection -DataSource $Database

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 2
Add-Type -Path "C:\Program Files (x86)\Microsoft.NET\Primary Interop Assemblies\microsoft.mshtml.dll"

$Vendor="Google"
$Browser="Chrome"
$WebStore="https://chrome.google.com/webstore/detail/"
Get-Extensions