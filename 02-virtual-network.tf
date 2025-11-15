
resource "azurerm_virtual_network" "hub" {
  name                = var.hub_network_name
  address_space       = var.hub_address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  tags = {
    Environment = var.environment
    Purpose     = "hub-network"
  }
}

resource "azurerm_subnet" "hub" {
  for_each             = { for subnet in var.hub_subnets : subnet.name => subnet }
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = each.value.address_prefixes
}

# Associate NSGs to hub subnets
resource "azurerm_network_security_group" "hub" {
  for_each = {
    for subnet in var.hub_subnets : subnet.name => subnet
    if subnet.security_group_enabled
  }

  name                = lower("nsg_${each.value.name}")
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  # Loop through each rule defined in the subnet
  dynamic "security_rule" {
    for_each = each.value.rules
    content {
      name                         = security_rule.value.name
      priority                     = security_rule.value.priority
      direction                    = security_rule.value.direction
      access                       = security_rule.value.access
      protocol                     = security_rule.value.protocol
      source_port_range            = security_rule.value.source_port_range
      destination_port_range       = security_rule.value.destination_port_range != null ? security_rule.value.destination_port_range : null
      destination_port_ranges      = security_rule.value.destination_port_ranges != null ? security_rule.value.destination_port_ranges : null
      source_address_prefix        = security_rule.value.source_address_prefix != null ? security_rule.value.source_address_prefix : null
      source_address_prefixes      = security_rule.value.source_address_prefixes != null ? security_rule.value.source_address_prefixes : null
      destination_address_prefix   = security_rule.value.destination_address_prefix != null ? security_rule.value.destination_address_prefix : null
      destination_address_prefixes = security_rule.value.destination_address_prefixes != null ? security_rule.value.destination_address_prefixes : null
    }
  }
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "${lower("${each.value.name}")} subnet security group"
  }
}

# Associate NSGs to hub subnets
resource "azurerm_subnet_network_security_group_association" "hub" {
  for_each = {
    for subnet in var.hub_subnets : subnet.name => subnet
    if subnet.security_group_enabled
  }

  subnet_id                 = azurerm_subnet.hub[each.value.name].id
  network_security_group_id = azurerm_network_security_group.hub[each.value.name].id
}

# Loop through each spoke network defined in the variable
resource "azurerm_virtual_network" "spoke" {
  for_each = { for spoke in var.spoke_network : spoke.name => spoke }

  name                = each.value.name
  address_space       = each.value.address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    Environment = var.environment
    Purpose     = "spoke-network"
  }
}

# Create spoke subnets as separate resources
resource "azurerm_subnet" "spoke" {
  for_each = {
    for pair in flatten([
      for spoke in var.spoke_network : [
        for subnet in spoke.subnets : {
          key              = "${spoke.name}-${subnet.name}"
          spoke_name       = spoke.name
          subnet_name      = subnet.name
          address_prefixes = subnet.address_prefixes
        }
      ]
    ]) : pair.key => pair
  }

  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke[each.value.spoke_name].name
  address_prefixes     = each.value.address_prefixes
}

# Associate NSGs to spoke subnets
resource "azurerm_network_security_group" "spoke" {
  for_each = {
    for pair in flatten([
      for spoke in var.spoke_network : [
        for subnet in spoke.subnets : {
          key    = "${spoke.name}-${subnet.name}"
          spoke  = spoke
          subnet = subnet
        }
        if subnet.security_group_enabled
      ]
    ]) : pair.key => pair
  }

  name                = lower("nsg_${each.value.subnet.name}")
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  # Loop through each rule defined in the subnet
  dynamic "security_rule" {
    for_each = each.value.subnet.rules
    content {
      name                         = security_rule.value.name
      priority                     = security_rule.value.priority
      direction                    = security_rule.value.direction
      access                       = security_rule.value.access
      protocol                     = security_rule.value.protocol
      source_port_range            = security_rule.value.source_port_range
      destination_port_range       = security_rule.value.destination_port_range
      source_address_prefix        = security_rule.value.source_address_prefix != null ? security_rule.value.source_address_prefix : null
      source_address_prefixes      = security_rule.value.source_address_prefixes != null ? security_rule.value.source_address_prefixes : null
      destination_address_prefix   = security_rule.value.destination_address_prefix != null ? security_rule.value.destination_address_prefix : null
      destination_address_prefixes = security_rule.value.destination_address_prefixes != null ? security_rule.value.destination_address_prefixes : null
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Environment = var.environment
    Purpose     = "${lower("${each.value.subnet.name}")} subnet security group"
  }
}

# Associate spoke NSGs to spoke subnets
resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = {
    for pair in flatten([
      for spoke in var.spoke_network : [
        for subnet in spoke.subnets : {
          key    = "${spoke.name}-${subnet.name}"
          spoke  = spoke
          subnet = subnet
        }
        if subnet.security_group_enabled
      ]
    ]) : pair.key => pair
  }

  subnet_id                 = azurerm_subnet.spoke[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

# Virtual network peering - hub to spokes
resource "azurerm_virtual_network_peering" "hub-to-spoke" {
  # for_each spoke vnets with peering enabled
  for_each = { for spoke in azurerm_virtual_network.spoke : spoke.name => spoke
  if lookup(var.spoke_network[index(var.spoke_network[*].name, spoke.name)], "peering_enabled", false) }

  name                         = "${azurerm_virtual_network.hub.name}-to-${each.value.name}"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = each.value.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  allow_virtual_network_access = true
}

# Virtual network peering - spoke to hub
resource "azurerm_virtual_network_peering" "spoke-to-hub" {
  # for_each spoke vnets with peering enabled
  for_each = { for spoke in azurerm_virtual_network.spoke : spoke.name => spoke
  if lookup(var.spoke_network[index(var.spoke_network[*].name, spoke.name)], "peering_enabled", false) }

  name                         = "${each.value.name}-to-${azurerm_virtual_network.hub.name}"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = each.value.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
