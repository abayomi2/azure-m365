output "app_insights_connection_string" {
  value = azurerm_application_insights.ai.connection_string
}
output "workspace_id" {
  value = azurerm_log_analytics_workspace.law.workspace_id
}
