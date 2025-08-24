param(
  [Parameter(Mandatory=$true)][string]$Upn,
  [Parameter(Mandatory=$true)][string]$DisplayName,
  [Parameter(Mandatory=$true)][string]$SkuId
)
$pwd = [System.Web.Security.Membership]::GeneratePassword(16,3)
$body = @{
  accountEnabled = $true
  displayName = $DisplayName
  mailNickname = ($DisplayName -replace " ","")
  userPrincipalName = $Upn
  passwordProfile = @{ password = $pwd; forceChangePasswordNextSignIn = $true }
}
$newUser = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users" -Body ($body | ConvertTo-Json)
# assign license
$licenseBody = @{ addLicenses = @(@{ skuId = $SkuId }); removeLicenses = @() }
Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users/$($newUser.id)/assignLicense" -Body ($licenseBody | ConvertTo-Json)
Write-Output "Created $Upn with temporary password $pwd"
