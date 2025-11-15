
resource "azurerm_public_ip" "natgw_ip" {
  name                = "natgw_public-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "this" {
  name                    = var.nat_gateway_name
  location                = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = {
    for subnet in var.hub_subnets : subnet.name => subnet
    if subnet.nat_gateway_association == true
  }
  nat_gateway_id = azurerm_nat_gateway.this.id
  subnet_id      = azurerm_subnet.hub[each.value.name].id
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.natgw_ip.id
}
