variable "rg_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure location (e.g. australiaeast)"
  type        = string
}

variable "app_name" {
  description = "Web App name"
  type        = string
}

variable "plan_sku" {
  description = "App Service Plan SKU (e.g. S1, P1v3)"
  type        = string
  default     = "S1"
}

# --- Container image & registry ---

variable "acr_login" {
  description = "ACR login server hostname (e.g. ishdevacr01.azurecr.io)"
  type        = string
}

variable "container_repository" {
  description = "Repository name in ACR (e.g. ish-api)"
  type        = string
}

variable "container_tag" {
  description = "Image tag to set at provision time (pipeline may override via slot/container config)"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Container listening port"
  type        = number
  default     = 8080
}

# --- Integrations ---

variable "ai_connection_string" {
  description = "Application Insights connection string (optional)"
  type        = string
  default     = ""
}

variable "acr_id" {
  description = "ACR resource ID (for AcrPull role assignment)"
  type        = string
}

