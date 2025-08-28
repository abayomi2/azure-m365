terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.70" }
    azuread = { source = "hashicorp/azuread", version = "~> 2.50" }
  }
}

provider "azuread" {} # uses same auth context; must be tenant-scoped creds with permissions to consent app roles

resource "azurerm_automation_account" "aa" {
  name                = var.automation_account_name
  location            = var.location
  resource_group_name = var.rg_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

# --- Microsoft Graph Service Principal (well-known) ---
data "azuread_service_principal" "msgraph" {
  display_name = "Microsoft Graph"
}

# Helper: find Graph app role IDs by value (permission names)
locals {
  graph_role_values = [
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Group.ReadWrite.All",
    "Device.ReadWrite.All",
    "DeviceManagementConfiguration.ReadWrite.All" # Intune
  ]

  graph_app_role_map = {
    for r in data.azuread_service_principal.msgraph.app_roles :
    r.value => r.id
    if r.value != null && r.value != "" && contains(local.graph_role_values, r.value)
  }
}

# Assign Graph application roles to the Automation Account's managed identity service principal
# Note: principal_object_id must be the service principal objectId of the MI, not the user-assigned identity.
resource "azuread_app_role_assignment" "aa_msgraph_roles" {
  for_each = local.graph_app_role_map

  principal_object_id = azurerm_automation_account.aa.identity[0].principal_id
  app_role_id         = each.value
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# --- Import PowerShell modules into Automation (Graph + PnP if you later choose) ---
# Microsoft.Graph rollup
resource "azurerm_automation_module" "msgraph" {
  name                    = "Microsoft.Graph"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph/2.18.0"
  }
}

# Optional PnP.PowerShell (only if you’ll use cert-based SPO provisioning)
# resource "azurerm_automation_module" "pnp" {
#   name                    = "PnP.PowerShell"
#   resource_group_name     = var.rg_name
#   automation_account_name = azurerm_automation_account.aa.name
#   module_link {
#     uri = "https://www.powershellgallery.com/api/v2/package/PnP.PowerShell/2.5.1"
#   }
# }

# --- Upload Runbooks ---
# Expect files to exist at ../../../../automation/runbooks/*.ps1 relative to envs/dev
resource "azurerm_automation_runbook" "onboard_users" {
  name                    = "Onboard-Users"
  location                = var.location
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  log_progress            = true
  log_verbose             = true
  description             = "Create users and assign licenses via Graph with Managed Identity"
  runbook_type            = "PowerShell"

  content = file("${path.module}/../../../automation/runbooks/Onboard-Users.ps1")
}

resource "azurerm_automation_runbook" "new_teamsite" {
  name                    = "New-TeamSite"
  location                = var.location
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  log_progress            = true
  log_verbose             = true
  description             = "Create M365 Group (SharePoint site auto-provisioned); optional Teams team"
  runbook_type            = "PowerShell"

  content = file("${path.module}/../../../automation/runbooks/New-TeamSite.ps1")
}

resource "azurerm_automation_runbook" "intune_policies" {
  name                    = "Intune-Policies"
  location                = var.location
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  log_progress            = true
  log_verbose             = true
  description             = "Seed Intune compliance policy (Windows) via Graph"
  runbook_type            = "PowerShell"

  content = file("${path.module}/../../../automation/runbooks/Intune-Policies.ps1")
}


# --- Microsoft Graph submodules needed by your runbooks ---
resource "azurerm_automation_module" "msgraph_auth" {
  name                    = "Microsoft.Graph.Authentication"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  module_link { uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Authentication/2.18.0" }
}

resource "azurerm_automation_module" "msgraph_users" {
  name                    = "Microsoft.Graph.Users"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  module_link { uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Users/2.18.0" }
}

resource "azurerm_automation_module" "msgraph_groups" {
  name                    = "Microsoft.Graph.Groups"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  module_link { uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Groups/2.18.0" }
}

# Optional (future Intune cmdlets; not required if you stick to Invoke-MgGraphRequest):
resource "azurerm_automation_module" "msgraph_devicemgmt" {
  name                    = "Microsoft.Graph.DeviceManagement"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  module_link { uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.DeviceManagement/2.18.0" }
}

# Needed for Set-MgUserLicense
resource "azurerm_automation_module" "msgraph_users_actions" {
  name                    = "Microsoft.Graph.Users.Actions"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  module_link { uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Users.Actions/2.18.0" }
}

# OPTIONAL: only if you insist on using 'Import-Module Microsoft.Graph' in runbooks
resource "azurerm_automation_module" "msgraph_applications" {
  name                    = "Microsoft.Graph.Applications"
  resource_group_name     = var.rg_name
  automation_account_name = azurerm_automation_account.aa.name
  module_link { uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Applications/2.18.0" }
}
