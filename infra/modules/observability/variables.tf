variable "rg_name"            { type = string }
variable "location"           { type = string }
variable "app_insights_name"  { type = string }
variable "workspace_name"     { type = string }
variable "app_service_id"     { type = string }
variable "app_service_name"   { type = string }
variable "acr_id"             { type = string }
variable "action_email"       { type = string }
variable "enable_kql_alert" {
  type    = bool
  default = false
}
