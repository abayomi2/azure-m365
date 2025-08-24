variable "rg_name"   { type = string }
variable "location"  { type = string }
variable "app_name"  { type = string }

# ACR info so we can form the container image reference and grant AcrPull
variable "acr_login" { type = string } # e.g. myacr.azurecr.io
variable "acr_id"    { type = string }

# Optional image settings (defaults ok for first deploy)
variable "container_repository" {
  type    = string
  default = "ish-api"
}
variable "container_tag" {
  type    = string
  default = "latest"
}
variable "container_port" {
  type    = number
  default = 8080
}
variable "plan_sku" {
  type    = string
  default = "P1v3" # production-ish; use B1 for cheap lab
}



# variable "rg_name" {
#   type = string
# }

# variable "location" {
#   type = string
# }

# variable "acr_login" {
#   type = string
# }

# variable "acr_id" {
#   type = string
# }
