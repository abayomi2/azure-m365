variable "rg_name"   { type = string }
variable "location"  { type = string }
variable "vnet_name" {
  type    = string
  default = "ish-vnet"
}
variable "address_space" {
  type    = list(string)
  default = ["10.40.0.0/16"]
}
variable "subnets" {
  type = map(string)
  default = {
    app  = "10.40.10.0/24"
    data = "10.40.20.0/24"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.rg_name
  address_space       = var.address_space
}

resource "azurerm_subnet" "subnet" {
  for_each            = var.subnets
  name                = each.key
  resource_group_name = var.rg_name
  virtual_network_name= azurerm_virtual_network.vnet.name
  address_prefixes    = [each.value]
}

output "vnet_id"  { value = azurerm_virtual_network.vnet.id }
output "subnet_ids" {
  value = { for k, s in azurerm_subnet.subnet : k => s.id }
}



