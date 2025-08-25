output "app_hostname" {
  description = "Default hostname of the production slot"
  value       = azurerm_linux_web_app.app.default_hostname
}

output "web_app_id" {
  description = "Resource ID of the Web App"
  value       = azurerm_linux_web_app.app.id
}

output "principal_id" {
  description = "System-assigned Managed Identity objectId for the Web App"
  value       = azurerm_linux_web_app.app.identity[0].principal_id
}

