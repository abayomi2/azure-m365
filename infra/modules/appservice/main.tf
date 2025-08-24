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
      # Full image is <acr_login>/<repo>:<tag>, but the schema here splits image/tag
      docker_image     = "${var.acr_login}/${var.container_repository}"
      docker_image_tag = var.container_tag
    }

    # Expose container port to App Service
    app_command_line = ""
  }

  app_settings = {
    WEBSITES_PORT                       = tostring(var.container_port)
    DOCKER_REGISTRY_SERVER_URL          = "https://${var.acr_login}"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
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



# resource "azurerm_app_service_plan" "this" {
#   name                = "${var.rg_name}-asp"
#   location            = var.location
#   resource_group_name = var.rg_name
#   kind                = "Linux"
#   reserved            = true

#   sku {
#     tier = "Basic"
#     size = "B1"
#   }
# }

# resource "azurerm_app_service" "app" {
#   name                = "${var.rg_name}-app"
#   location            = var.location
#   resource_group_name = var.rg_name
#   app_service_plan_id = azurerm_app_service_plan.this.id

#   # Enable system-assigned identity
#   identity {
#     type = "SystemAssigned"
#   }

#   site_config {
#     linux_fx_version = "DOCKER|${var.acr_login}/myapp:latest"
#   }

#   app_settings = {
#     WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
#     WEBSITES_PORT                       = "3000"
#     DOCKER_REGISTRY_SERVER_URL          = "https://${var.acr_login}"
#   }
# }

# # Allow App Service to pull images from ACR
# resource "azurerm_role_assignment" "acr_pull" {
#   principal_id         = azurerm_app_service.app.identity.principal_id
#   role_definition_name = "AcrPull"
#   scope                = var.acr_id
# }

# output "app_hostname" {
#   value = azurerm_app_service.app.default_site_hostname
# }
