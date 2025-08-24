param([string]$Alias, [string]$Title)
Connect-PnPOnline -Url "https://<yourtenant>.sharepoint.com" -Interactive
New-PnPSite -Type TeamSite -Title $Title -Alias $Alias -IsPublic:$false
Write-Output "Created site $Alias"
