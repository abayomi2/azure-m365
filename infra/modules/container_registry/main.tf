resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"   # or Standard/Premium depending on your needs
  admin_enabled       = true
}

