terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"
    }
  }
  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}

  client_id       = var.client_id       # SPN appId
  client_secret   = var.client_secret   # SPN password
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
