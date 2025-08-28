variable "rg_name"   { type = string }
variable "location"  { type = string }

variable "automation_account_name" {
  type    = string
  default = "ish-dev-aa"
}

# Optional: default email domain for user creation
variable "default_domain" {
  type    = string
  default = "oguntiloye101gmail.onmicrosoft.com"
}

# A license SKU to assign (you can pass the real GUID from envs/dev)
# e.g. Microsoft 365 E5: 06ebc4ee-1bb5-47dd-8120-11324bc54e06
variable "default_license_sku_id" {
  type    = string
  default = "" # set in envs/dev for real use
}
