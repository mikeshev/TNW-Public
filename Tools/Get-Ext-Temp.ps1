		$Computer="Keslar-Lisa2"
        	$DefaultExtPath = 'AppData\Local\Google\Chrome\User Data\Default\Extensions'
        	$ProfilesExtPath = 'AppData\Local\Google\Chrome\User Data\Profile *'

	  	# Set Default & Optional user profiles that contain a Chrome extensions folder
                $DefaultPath = Join-path -path "fileSystem::\\$Computer\C$\Users\*" -ChildPath $DefaultExtPath
		$ProfilePath = Join-path -Path "fileSystem::\\$Computer\C$\Users\*" -ChildPath $ProfileExtPath

		$Paths = @()
                $Extensions =@()
		$Paths += $DefaultPath

		Get-ChildItem $ProfilePath -Filter "Profile *" -Directory | %{$_.fullname} | ForEach-Object {
echo $_
		    $Paths += $_
		}

		ForEach ($ExtPath in $Paths){
                  Get-Item -Path $ExtPath -ErrorAction SilentlyContinue | ForEach-Object{
                    $Extensions += Get-ChildItem -Path $_ -Directory -ErrorAction SilentlyContinue
                  }
		}

echo $Extensions