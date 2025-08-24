resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"   # or Standard/Premium depending on your needs
  admin_enabled       = true
}


# resource "azurerm_container_registry" "this" {
#   name                = var.name
#   resource_group_name = var.resource_group_name
#   location            = var.location
#   sku                 = var.sku
#   admin_enabled       = false
# }

# If you're using Managed Identity to push/pull, you don’t need admin_enabled
