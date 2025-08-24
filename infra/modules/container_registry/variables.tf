variable "acr_name" {
  type        = string
  description = "The name of the ACR"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where ACR will be deployed"
}

variable "location" {
  type        = string
  description = "Azure region for ACR"
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = "SKU of the Azure Container Registry"
}
