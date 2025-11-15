
# Route Tables for Spoke Subnets
resource "azurerm_route_table" "spoke_subnet_rt" {
  for_each = {
    for subnet in flatten([for nw in var.spoke_network : nw.subnets]) : subnet.name => subnet
    if subnet.route_table_enabled == true
  }

  name                          = "rt_${each.value.name}"
  location                      = var.location == null ? azurerm_resource_group.this.location : var.location
  resource_group_name           = var.resource_group_name == null ? azurerm_resource_group.this.name : var.resource_group_name
  bgp_route_propagation_enabled = true
  tags = {
    Environment = var.environment
    Purpose     = "spoke-subnet-route-table"
  }
}

# Routes for Spoke Subnet Route Tables
resource "azurerm_route" "spoke_subnet_routes" {
  for_each = {
    for item in flatten([
      for subnet in flatten([for nw in var.spoke_network : nw.subnets]) : [
        for route in subnet.routes : {
          key         = "${subnet.name}-${route.name}"
          subnet_name = subnet.name
          route       = route
        }
      ]
      if subnet.route_table_enabled == true
    ]) : item.key => item
  }

  name                   = each.value.route.name
  route_table_name       = azurerm_route_table.spoke_subnet_rt[each.value.subnet_name].name
  resource_group_name    = azurerm_resource_group.this.name
  address_prefix         = each.value.route.address_prefix
  next_hop_type          = each.value.route.next_hop_type
  next_hop_in_ip_address = each.value.route.next_hop_in_ip_address == null ? azurerm_lb.lb_private.frontend_ip_configuration[0].private_ip_address : each.value.route.next_hop_in_ip_address

  # get the azurerm_network_interface.firewall_nics private_ip_address for the firewall nic where the subnet_name matches
  # next_hop_in_ip_address = azurerm_network_interface.firewall_nics[ "${var.firewall_vm_series[0].name}-nic-2" ].ip_configuration[0].private_ip_address


  lifecycle {
    create_before_destroy = true
  }


  depends_on = [azurerm_route_table.spoke_subnet_rt]
}

# Route Table Associations for Spoke Subnets
resource "azurerm_subnet_route_table_association" "spoke_subnet_rt_assoc" {
  for_each = {
    for subnet in flatten([for nw in var.spoke_network : nw.subnets]) : subnet.name => subnet
    if subnet.route_table_enabled == true
  }
  subnet_id      = [for s in azurerm_subnet.spoke : s if s.name == each.value.name][0].id
  route_table_id = azurerm_route_table.spoke_subnet_rt[each.value.name].id

  lifecycle {
    create_before_destroy = true
  }
}
