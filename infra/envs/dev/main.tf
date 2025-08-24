terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-ish-bootstrap"
    storage_account_name = "ishbootstrapstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

locals {
  env      = "dev"
  location = "australiaeast"
  prefix   = "ish-${local.env}"
}

resource "azurerm_resource_group" "core" {
  name     = "${local.prefix}-rg"
  location = local.location
  tags     = { environment = local.env, owner = "MSS" }
}

module "network" {
  source   = "../../modules/network"
  rg_name  = azurerm_resource_group.core.name
  location = local.location
  # vnet_name = "vnet-${local.prefix}"  # optional override if you like
}

module "container_registry" {
  source              = "../../modules/container_registry"
  acr_name            = "${replace(local.prefix, "-", "")}acr01" # e.g. "ishdevacr01" must be lowercase
  resource_group_name = azurerm_resource_group.core.name
  location            = local.location
}

module "appservice" {
  source                = "../../modules/appservice"
  rg_name               = azurerm_resource_group.core.name
  location              = local.location
  app_name              = "${local.prefix}-api"
  acr_login             = module.container_registry.acr_login_server
  acr_id                = module.container_registry.acr_id
  container_repository  = "ish-api"
  container_tag         = "latest"
  container_port        = 8080
  plan_sku              = "B1" # cheaper for dev; bump to P1v3 for prod-like perf
}

output "api_hostname" {
  value = module.appservice.default_hostname
}
output "acr_login_server" {
  value = module.container_registry.acr_login_server
}




# terraform {
#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~>3.70"
#     }
#   }
#   backend "azurerm" {
#     resource_group_name  = "rg-ish-bootstrap"
#     storage_account_name = "ishbootstrapstate"
#     container_name       = "tfstate"
#     key                  = "dev.terraform.tfstate"
#   }
# }

# provider "azurerm" {
#   features {}
# }

# locals {
#   location = "Australia East"
# }

# resource "azurerm_resource_group" "core" {
#   name     = "ish-dev-rg"
#   location = local.location
# }

# module "network" {
#   source   = "../../modules/network"
#   rg_name  = azurerm_resource_group.core.name
#   location = local.location
# }

# module "container_registry" {
#   source              = "../../modules/container_registry"
#   name                = "ishdevacr"
#   resource_group_name = azurerm_resource_group.core.name
#   location            = azurerm_resource_group.core.location
#   sku                 = "Basic"
# }

# module "appservice" {
#   source   = "../../modules/appservice"
#   rg_name  = azurerm_resource_group.core.name
#   location = local.location
#   acr_login = module.container_registry.acr_login_server
#   acr_id    = module.container_registry.acr_id
# }
