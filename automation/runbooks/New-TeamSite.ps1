<#
.SYNOPSIS
  Create a Microsoft 365 Group (backed by a SharePoint Team Site).
.PARAMETER GroupDisplayName
  Name for the M365 group.
.PARAMETER GroupAlias
  MailNickname/alias (unique). If not provided, derived from display name.
.PARAMETER Teamify
  Switch. If set, create a Microsoft Team bound to the group.
#>

param(
  [Parameter(Mandatory=$true)][string]$GroupDisplayName,
  [Parameter(Mandatory=$false)][string]$GroupAlias,
  [switch]$Teamify
)

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Groups         -ErrorAction Stop
# (No roll-up import)
Connect-MgGraph -Identity -NoWelcome
Select-MgProfile -Name "v1.0"

if (-not $GroupAlias) {
  $GroupAlias = ($GroupDisplayName -replace "[^a-zA-Z0-9]", "").ToLower()
}

Write-Output "Creating M365 Group: $GroupDisplayName ($GroupAlias)"
$group = New-MgGroup -DisplayName $GroupDisplayName `
  -MailEnabled:$true -MailNickname $GroupAlias -SecurityEnabled:$false `
  -GroupTypes @("Unified")

Write-Output "Group created: $($group.Id). SharePoint Team Site will provision automatically."

if ($Teamify) {
  Write-Output "Creating Microsoft Team on this group..."
  # Team creation uses the Team endpoint
  $teamBody = @{
    "memberSettings" = @{ "allowCreatePrivateChannels" = $true }
    "messagingSettings" = @{ "allowUserEditMessages" = $true; "allowUserDeleteMessages" = $true }
    "funSettings" = @{ "allowGiphy" = $true; "giphyContentRating" = "moderate" }
  } | ConvertTo-Json -Depth 5

  # POST /groups/{id}/team
  Invoke-MgGraphRequest -Method PUT `
    -Uri ("https://graph.microsoft.com/v1.0/groups/{0}/team" -f $group.Id) `
    -Body $teamBody `
    -ContentType "application/json"

  Write-Output "Team created for group $($group.Id)."
}
