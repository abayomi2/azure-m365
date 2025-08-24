locals {
  env      = "dev"
  location = "australiaeast"
  prefix   = "ish-${local.env}"
}

resource "azurerm_resource_group" "core" {
  name     = "${local.prefix}-rg"
  location = local.location
  tags     = {
    environment = local.env
    owner       = "MSS"
  }
}

# Create ACR
resource "azurerm_container_registry" "acr" {
  name                = "${local.prefix}acr01"
  resource_group_name = azurerm_resource_group.core.name
  location            = local.location
  sku                 = "Basic"
  admin_enabled       = false # important for SPN auth
}

# Network module
module "network" {
  source   = "../../modules/network"
  rg_name  = azurerm_resource_group.core.name
  location = local.location
}

# AppService module
module "appservice" {
  source      = "../../modules/appservice"
  rg_name     = azurerm_resource_group.core.name
  location    = local.location
  app_name    = "${local.prefix}-api"
  acr_server  = azurerm_container_registry.acr.login_server
}

output "app_hostname" {
  value = module.appservice.app_hostname
}
