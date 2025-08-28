<#
.SYNOPSIS
  Bulk-create Entra ID users from CSV and assign a license via Microsoft Graph using Managed Identity.

.PARAMETER CsvContent
  CSV string content with columns:
  UserPrincipalName,DisplayName,GivenName,Surname,UsageLocation,LicenseSkuId,Department,JobTitle
  If UsageLocation or LicenseSkuId is empty per row, falls back to the provided defaults.

.PARAMETER DefaultUsageLocation
  Fallback usage location (e.g., "AU") if a row doesn’t provide one.

.PARAMETER DefaultLicenseSkuId
  Fallback SKU id (GUID) for license assignment. If omitted and a row doesn’t provide a SKU, that row won’t get a license.
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$CsvContent,

  [Parameter(Mandatory = $false)]
  [string]$DefaultUsageLocation = "AU",

  [Parameter(Mandatory = $false)]
  [string]$DefaultLicenseSkuId
)

# --- Modules & Graph auth (Managed Identity) ---
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users          -ErrorAction Stop
Import-Module Microsoft.Graph.Users.Actions  -ErrorAction Stop

Connect-MgGraph -Identity -NoWelcome
Select-MgProfile -Name "v1.0"

function New-TempPassword {
  # Generates a complex-ish temporary password (length ~ 20)
  $bytes = New-Object 'System.Byte[]' (16)
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $base = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','a').Replace('/','b')
  # Ensure complexity: add Aa1!
  return ($base + "Aa1!")
}

# Parse CSV
try {
  $rows = $CsvContent | ConvertFrom-Csv
} catch {
  throw "CSV parsing failed: $($_.Exception.Message)"
}

if (-not $rows) {
  Write-Error "No rows found in CsvContent."
  throw
}

$results = New-Object System.Collections.Generic.List[Object]

foreach ($row in $rows) {
  # Trim all cell values (PowerShell 5/7 compatible — no null-conditional operator)
  $obj = @{}
  $row.PSObject.Properties | ForEach-Object {
    $val = ($_.Value -as [string])
    if ($null -ne $val) { $val = $val.Trim() }
    $obj[$_.Name] = $val
  }

  $upn          = $obj.UserPrincipalName
  $displayName  = $obj.DisplayName
  $givenName    = $obj.GivenName
  $surname      = $obj.Surname
  $dept         = $obj.Department
  $jobTitle     = $obj.JobTitle
  $rowUsageLoc  = $obj.UsageLocation
  $rowSku       = $obj.LicenseSkuId

  $effectiveUsage = if ([string]::IsNullOrWhiteSpace($rowUsageLoc)) { $DefaultUsageLocation } else { $rowUsageLoc }
  $effectiveSku   = if ([string]::IsNullOrWhiteSpace($rowSku))      { $DefaultLicenseSkuId } else { $rowSku }

  $rowOutcome = [ordered]@{
    UserPrincipalName = $upn
    Created           = $false
    Updated           = $false
    UsageLocationSet  = $false
    LicenseAssigned   = $false
    LicenseSkuId      = $effectiveSku
    Message           = ""
    Error             = $null
  }

  if ([string]::IsNullOrWhiteSpace($upn) -or [string]::IsNullOrWhiteSpace($displayName)) {
    $rowOutcome.Error = "Missing required fields (UserPrincipalName, DisplayName)."
    $results.Add([pscustomobject]$rowOutcome)
    Write-Warning "Row skipped: $($rowOutcome.Error)"
    continue
  }

  try {
    # Try to find user
    $user = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ConsistencyLevel eventual -CountVariable c

    if (-not $user) {
      # Create new user
      $mailNick = ($upn.Split('@')[0])
      $pwd = New-TempPassword

      $newParams = @{
        AccountEnabled   = $true
        DisplayName      = $displayName
        UserPrincipalName= $upn
        MailNickname     = $mailNick
        PasswordProfile  = @{
          ForceChangePasswordNextSignIn = $true
          Password = $pwd
        }
        UsageLocation    = $effectiveUsage  # set at creation time
      }
      if ($givenName) { $newParams.GivenName = $givenName }
      if ($surname)   { $newParams.Surname   = $surname }
      if ($dept)      { $newParams.Department = $dept }
      if ($jobTitle)  { $newParams.JobTitle   = $jobTitle }

      $user = New-MgUser @newParams
      $rowOutcome.Created = $true
      $rowOutcome.Message = "User created; temp password set (force change at next sign-in)."
      Write-Output "Created user $upn"
    }
    else {
      # User exists: patch profile & usage location if needed
      $patch = @{}
      if ($displayName -and $displayName -ne $user.DisplayName) { $patch.DisplayName = $displayName }
      if ($givenName   -and $givenName   -ne $user.GivenName)   { $patch.GivenName   = $givenName }
      if ($surname     -and $surname     -ne $user.Surname)     { $patch.Surname     = $surname }
      if ($dept        -and $dept        -ne $user.Department)  { $patch.Department  = $dept }
      if ($jobTitle    -and $jobTitle    -ne $user.JobTitle)    { $patch.JobTitle    = $jobTitle }

      # Get latest model with usageLocation if not present
      $current = Get-MgUser -UserId $user.Id -Property "usageLocation,accountEnabled" -Select "usageLocation,accountEnabled"

      if ([string]::IsNullOrWhiteSpace($current.UsageLocation) -or $current.UsageLocation -ne $effectiveUsage) {
        $patch.UsageLocation = $effectiveUsage
      }

      if ($patch.Keys.Count -gt 0) {
        Update-MgUser -UserId $user.Id @patch
        $rowOutcome.Updated = $true
        if ($patch.ContainsKey('UsageLocation')) { $rowOutcome.UsageLocationSet = $true }
        Write-Output "Updated user $upn ($(($patch.Keys -join ', ')))"
      }
    }

    # Assign license if we have an effective SKU
    if ($effectiveSku) {
      # Check existing license details to avoid duplicates
      $lic = Invoke-MgGraphRequest -Method GET -Uri "/users/$($user.Id)/licenseDetails" -ErrorAction SilentlyContinue
      $licVals = @()
      if ($lic -and $lic.value) { $licVals = $lic.value }

      $hasSku = $false
      foreach ($ld in $licVals) { if ($ld.skuId -eq $effectiveSku) { $hasSku = $true; break } }

      if (-not $hasSku) {
        $body = @{
          addLicenses    = @(@{ skuId = $effectiveSku })
          removeLicenses = @()
        }
        Set-MgUserLicense -UserId $user.Id -BodyParameter $body
        $rowOutcome.LicenseAssigned = $true
        Write-Output "Assigned license $effectiveSku to $upn"
      } else {
        Write-Output "License $effectiveSku already present for $upn"
      }
    }

  } catch {
    $rowOutcome.Error = $_.Exception.Message
    Write-Error "Failed row for $upn : $($rowOutcome.Error)"
  }

  $results.Add([pscustomobject]$rowOutcome)
}

# Final summary
$ok   = ($results | Where-Object { -not $_.Error }).Count
$fail = ($results | Where-Object { $_.Error }).Count

Write-Output "Summary: $ok succeeded, $fail failed out of $($results.Count) rows."
Write-Output ("ResultsJson: " + ($results | ConvertTo-Json -Depth 4 -Compress))
