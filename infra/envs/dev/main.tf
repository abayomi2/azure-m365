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
  source               = "../../modules/appservice"
  rg_name              = azurerm_resource_group.core.name
  location             = local.location
  app_name             = "${local.prefix}-api"
  acr_login            = module.container_registry.acr_login_server
  acr_id               = module.container_registry.acr_id
  container_repository = "ish-api"
  container_tag        = "latest"
  container_port       = 8080
  plan_sku             = "S1" # cheaper for dev; bump to P1v3 for prod-like perf
  ai_connection_string = module.observability.app_insights_connection_string
}

module "observability" {
  source             = "../../modules/observability"
  rg_name            = azurerm_resource_group.core.name
  location           = local.location
  app_insights_name  = "ish-dev-ai"
  workspace_name     = "ish-dev-law"

  # ⬇️ use the appservice outputs you defined
  app_service_id     = module.appservice.web_app_id
  app_service_name   = "${local.prefix}-api"

  acr_id             = module.container_registry.acr_id
  action_email       = "oguntiloye101@gmail.com"

  # optional toggle (leave default false unless you have AI 'requests' data)
  # enable_kql_alert = true
}

module "m365_automation" {
  source                   = "../../modules/m365_automation"
  rg_name                  = azurerm_resource_group.core.name
  location                 = local.location
  automation_account_name  = "ish-dev-aa"
  default_domain           = "oguntiloye101gmail.onmicrosoft.com"
  default_license_sku_id   = "" # set to your real SubscribedSku GUID when ready
}



data "azurerm_resource_group" "core" { name = azurerm_resource_group.core.name }

module "policy" {
  source   = "../../modules/policy"
  rg_name  = azurerm_resource_group.core.name
  scope_id = data.azurerm_resource_group.core.id
}

output "acr_login_server" {
  value = module.container_registry.acr_login_server
}

output "api_hostname" {
  # ⬇️ use the module output name
  value = module.appservice.app_hostname
}

