$ExtID = $args[0]
$url = "https://chrome.google.com/webstore/detail/" + $ExtID + "?hl=en-us"
$WebRequest = Invoke-WebRequest -Uri $url -ErrorAction Stop
echo $WebRequest

if ($WebRequest.StatusCode -eq 200) {
  # Get the HTML Page Title but remove ' - Chrome Web Store'
echo $WebRequest.ParsedHtml.title
  if (-not([string]::IsNullOrEmpty($WebRequest.ParsedHtml.title))) {
    $ExtTitle = $WebRequest.ParsedHtml.title
echo $ExtTitle
    if ($ExtTitle -match '\s-\s.*$') {
      $Title = $ExtTitle -replace '\s-\s.*$',''
      $extType = 'ChromeStore'
    } else {
      $Title = $ExtTitle
    }
  }
}
else {
 echo "WebRequest Failed"}

echo $Title