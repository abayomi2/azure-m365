param(
  [Parameter(Mandatory=$true)]  [string]$UserPrincipalName,
  [Parameter(Mandatory=$true)]  [string]$UsageLocation,
  [Parameter(Mandatory=$false)] [string]$SkuId
)

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users          -ErrorAction Stop
Import-Module Microsoft.Graph.Users.Actions  -ErrorAction Stop

Connect-MgGraph -Identity -NoWelcome
Select-MgProfile -Name "v1.0"

# Resolve user
$user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -ConsistencyLevel eventual -CountVariable c
if (-not $user) { throw "User '$UserPrincipalName' not found." }

# Set usage location
Update-MgUser -UserId $user.Id -UsageLocation $UsageLocation
Write-Output "Set usageLocation='$UsageLocation' on $UserPrincipalName"

# Optionally assign license
if ($SkuId) {
  $body = @{ addLicenses = @(@{ skuId = $SkuId }); removeLicenses = @() }
  Set-MgUserLicense -UserId $user.Id -BodyParameter $body
  Write-Output "Assigned license $SkuId to $UserPrincipalName"
}

# Echo back current state
$u2 = Get-MgUser -UserId $user.Id -Property "userPrincipalName,usageLocation,accountEnabled" -Select "userPrincipalName,usageLocation,accountEnabled"
Write-Output ("AfterUpdate: " + ($u2 | ConvertTo-Json -Compress))
