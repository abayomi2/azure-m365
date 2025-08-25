terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.70"
    }
  }
}

# --- resources only below ---

resource "azurerm_log_analytics_workspace" "law" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "ai" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.rg_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}

# App Service → LAW (logs + metrics)
resource "azurerm_monitor_diagnostic_setting" "appsvc_diag" {
  name                       = "${var.app_service_name}-diag"
  target_resource_id         = var.app_service_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ACR → LAW (logs + metrics)
resource "azurerm_monitor_diagnostic_setting" "acr_diag" {
  name                       = "acr-diag"
  target_resource_id         = var.acr_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log { category = "ContainerRegistryRepositoryEvents" }
  enabled_log { category = "ContainerRegistryLoginEvents" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Action Group (email)
resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-ops"
  resource_group_name = var.rg_name
  short_name          = "ops"

  email_receiver {
    name          = "ops-mail"
    email_address = var.action_email
  }
}

# Metric alert (allowed window_size values)
resource "azurerm_monitor_metric_alert" "five_xx_high" {
  name                 = "app-http5xx-high"
  resource_group_name  = var.rg_name
  scopes               = [var.app_service_id]
  description          = "HTTP 5xx spikes"
  severity             = 2
  frequency            = "PT1M"
  window_size          = "PT15M"
  target_resource_type = "microsoft.web/sites"

  criteria {
    metric_namespace = "microsoft.web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# KQL alert (LAW)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "error_rate" {
  count               = var.enable_kql_alert ? 1 : 0
  name                = "apm-5xx-error-rate"
  resource_group_name = var.rg_name
  location            = var.location
  description         = "5xx error rate > 5% in last 15m"
  severity            = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  scopes               = [azurerm_log_analytics_workspace.law.id]
  enabled              = true
  display_name         = "APP 5xx error rate"

  criteria {
    query = <<-KQL
      requests
      | where timestamp > ago(15m)
      | summarize errors = countif(tostring(resultCode) startswith "5"), total = count()
      | extend errorRate = iff(total == 0, 0.0, todouble(errors) / todouble(total) * 100.0)
      | project _ResourceId, errorRate
    KQL
    resource_id_column    = "_ResourceId"
    metric_measure_column = "errorRate"
    time_aggregation_method = "Average"
    operator                = "GreaterThan"
    threshold               = 5.0
  }

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }
}
