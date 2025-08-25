terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"
    }
  }
}

variable "rg_name" { type = string }
variable "scope_id" { type = string } # data.azurerm_resource_group.core.id

# Provide these from your environment (built-in definition IDs)
variable "def_appsvc_https_tls12_id" {
  type    = string
  default = ""
}
variable "def_acr_https_only_id" {
  type    = string
  default = ""
}
variable "def_require_tag_id" {
  type    = string
  default = ""
}
variable "require_tag_name" {
  type    = string
  default = "environment"
}

# App Service HTTPS/TLS policy (assign only if provided)
resource "azurerm_resource_group_policy_assignment" "appsvc_https" {
  count                = var.def_appsvc_https_tls12_id == "" ? 0 : 1
  name                 = "enforce-appservice-https-tls12"
  resource_group_id    = var.scope_id
  policy_definition_id = var.def_appsvc_https_tls12_id
  display_name         = "Enforce HTTPS/TLS1.2 on App Service"
  location             = "australiaeast"
}

# ACR HTTPS-only policy (assign only if provided)
resource "azurerm_resource_group_policy_assignment" "acr_https" {
  count                = var.def_acr_https_only_id == "" ? 0 : 1
  name                 = "enforce-acr-https"
  resource_group_id    = var.scope_id
  policy_definition_id = var.def_acr_https_only_id
  display_name         = "ACR HTTPS enforced"
  location             = "australiaeast"
}

# Require Tag policy (assign only if provided)
resource "azurerm_resource_group_policy_assignment" "require_tag" {
  count                = var.def_require_tag_id == "" ? 0 : 1
  name                 = "require-tag-${var.require_tag_name}"
  resource_group_id    = var.scope_id
  policy_definition_id = var.def_require_tag_id
  display_name         = "Require tag: ${var.require_tag_name}"
  location             = "australiaeast"

  parameters = jsonencode({
    tagName = { value = var.require_tag_name }
  })
}
