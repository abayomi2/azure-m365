<#
.SYNOPSIS
  Create a simple Windows 10+ compliance policy in Intune.
.PARAMETER PolicyName
  Display name for the policy.
#>

param(
  [Parameter(Mandatory=$false)][string]$PolicyName = "ISH - Windows Baseline Compliance"
)

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Connect-MgGraph -Identity -NoWelcome
Select-MgProfile -Name "beta"

$policy = @{
  "@odata.type"        = "#microsoft.graph.windows10CompliancePolicy"
  displayName          = $PolicyName
  passwordRequired     = $true
  passwordRequiredType = "deviceDefault"
  osMinimumVersion     = "10.0.19041.0"
}

Write-Output "Creating Intune compliance policy: $PolicyName"
Invoke-MgGraphRequest -Method POST `
  -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" `
  -Body ($policy | ConvertTo-Json -Depth 5) `
  -ContentType "application/json"

Write-Output "Done."
