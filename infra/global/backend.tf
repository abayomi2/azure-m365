terraform {
  required_version = ">= 1.7.0"

  backend "azurerm" {
    resource_group_name  = "rg-ish-bootstrap"        # bootstrap RG name
    storage_account_name = "stishstatef3c341"       # replace with TF_STORAGE from bootstrap
    container_name       = "tfstate"
    key                  = "ish-global.tfstate"
  }

  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.113" }
    azuread = { source = "hashicorp/azuread", version = "~> 2.51" }
  }
}
