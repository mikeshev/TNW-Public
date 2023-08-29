function Get-ChromeExtension {
<#
 .SYNOPSIS
    Gets Chrome Extensions from a local or remote computer
 .DESCRIPTION
    Gets the name, version and description of the installed extensions
    Admin rights are required to access other profiles on the local computer or
    any profiles on a remote computer.
    Internet access is required to lookup the extension ID on the Chrome web store
 .PARAMETER Computername
    The name of the computer to connect to
    The default is the local machine
 .PARAMETER Username
    The username to query i.e. the userprofile (c:\users\<username>)
    If this parameter is omitted, all userprofiles are searched
 .EXAMPLE
    PS C:\> Get-ChromeExtension
    This command will get the Chrome extensions from all the user profiles on the local computer
 .EXAMPLE
    PS C:\> Get-ChromeExtension -username Jsmith
    This command will get the Chrome extensions installed under c:\users\jsmith on the local computer
 .EXAMPLE
    PS C:\> Get-ChromeExtension -Computername PC1234,PC4567
    This command will get the Chrome extensions from all the user profiles on the two remote computers specified
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
        #REGION --- Child function
        function Get-ExtensionInfo {
            <#
         .SYNOPSIS
            Get Name and Version of the a Chrome extension
         .PARAMETER Folder
            A directory object (under %userprofile%\AppData\Local\Google\Chrome\User Data\Default\Extensions)
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
                # Extension folders are under %userprofile%\AppData\Local\Google\Chrome\User Data\Default\Extensions
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
                    # Built-in extensions do not appear in the Chrome Store
                    $Title = $BuiltInExtensions[$ExtID]
                    $Description = ''

                }else{
                    # Lookup the extension in the Store
                    $url = "https://chrome.google.com/webstore/detail/" + $ExtID + "?hl=en-us"
                    try {
                        # You may need to include proxy information
                        # $WebRequest = Invoke-WebRequest -Uri $url -ErrorAction Stop -Proxy 'http://proxy:port' -ProxyUseDefaultCredentials
                        $WebRequest = Invoke-WebRequest -Uri $url -ErrorAction Stop

                        if ($WebRequest.StatusCode -eq 200) {

                            # Get the HTML Page Title but remove ' - Chrome Web Store'
                            if (-not([string]::IsNullOrEmpty($WebRequest.ParsedHtml.title))) {

                                $ExtTitle = $WebRequest.ParsedHtml.title
                                if ($ExtTitle -match '\s-\s.*$') {
                                    $Title = $ExtTitle -replace '\s-\s.*$',''
                                    $extType = 'ChromeStore'
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

                [PSCustomObject][Ordered]@{
                    Name        = $Title
                    Version     = $Version
#                    Description = $Description
                   Username    = $Username
#                    ID          = $ExtID
                }

            }
        }#End function
        #ENDREGION -----

        $DefaultExtPath = 'AppData\Local\Google\Chrome\User Data\Default\Extensions'
	$ProfilesExtPath = 'AppData\Local\Google\Chrome\User Data\Profile *'
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
            } else {		# All user profiles (Default & Optional) that contain a Chrome extensions folder

	  	# Get Default user profiles that contain this a Chrome extensions folder
                $DefaultPath = Join-path -path "fileSystem::\\$Computer\C$\Users\*" -ChildPath $DefaultExtPath
		$ProfilesPath = Join-path -Path "fileSystem::\\$Computer\C$\Users\*" -ChildPath $ProfilesExtPath

		$Paths += $DefaultPath

		Get-ChildItem $ProfilesPath -Filter "Profile *" -Directory | %{$_.fullname} | ForEach-Object {
		    $Paths += $_ + "\Extensions"
		}

		ForEach ($ExtPath in $Paths){
                  Get-Item -Path $ExtPath -ErrorAction SilentlyContinue | ForEach-Object{
                    $Extensions += Get-ChildItem -Path $_ -Directory -ErrorAction SilentlyContinue
                  }
		}
            }

            if (-not($null -eq $Extensions)) {

                Foreach ($Extension in $Extensions) {
		    if($Extension.ToString() -ne "Temp"){	# Ignore Temp Directory
                        $Output = Get-ExtensionInfo -Folder $Extension
                        $Output | Add-Member -MemberType NoteProperty -Name 'Computername' -Value $Computer
                        $Output}
                }

            } else {
                Write-Warning "$Computer : no extensions were found"
            }

        }#foreach
    }
}

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 2
Get-ChromeExtension