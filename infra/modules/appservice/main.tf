# App Service Plan (new resource: azurerm_service_plan) 
resource "azurerm_service_plan" "plan" {
  name                = "${var.app_name}-plan"
  location            = var.location
  resource_group_name = var.rg_name
  os_type             = "Linux"
  sku_name            = var.plan_sku
}

# Linux Web App running a container from ACR (no creds; MI will have AcrPull)
resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  location            = var.location
  resource_group_name = var.rg_name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  # System-assigned Managed Identity
  identity { type = "SystemAssigned" }

  site_config {
    always_on = true

    application_stack {
      # new style: single property with repo:tag
      docker_image_name = "${var.acr_login}/${var.container_repository}:${var.container_tag}"
    }

  }

  app_settings = {
    WEBSITES_PORT                         = tostring(var.container_port)
    DOCKER_REGISTRY_SERVER_URL            = "https://${var.acr_login}"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE   = "false"
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.ai_connection_string
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 100
      }
    }
  }
}

# Let the Web App's Managed Identity pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}
