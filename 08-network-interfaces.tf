# Create Public IPs for Firewall Management Interfaces  
resource "azurerm_public_ip" "firewall_pip" {
  # for_each = {
  #   for fw in var.firewall_vm_series :
  #   "${fw.name}-${fw.network_interfaces[0].name}" => fw.network_interfaces[0]
  #   if length([for ni in fw.network_interfaces : ni if ni.ip_configurations[0].subnet_name != "private"]) > 1
  # }

  for_each = {
    for item in flatten([
      for fw in var.firewall_vm_series : [
        for nic in fw.network_interfaces :
        {
          key = "${fw.name}-${nic.ip_configurations[0].subnet_name}"
          nic = nic
        } if nic.name == "management" # if nic.name != "private"
      ]
      # if fw.network_interfaces[0].ip_configurations[0].subnet_name != "private"
    ]) : item.key => item.nic
  }

  name                = "ip_${each.key}-public"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${each.key}-dns-${random_string.suffix.result}"

  lifecycle {
    create_before_destroy = true
  }

  # Add tags, DNS, etc. as needed
  tags = {
    Environment = var.environment
    Purpose     = "firewall ip"
    Role        = "firewall"
  }

}

# Create Network Interfaces for Firewall VM Series
resource "azurerm_network_interface" "firewall_nics" {
  for_each = {
    for item in flatten([
      for fw_idx, fw in var.firewall_vm_series : [
        for nic_idx, nic in fw.network_interfaces : {
          key        = "${fw.name}-nic-${nic_idx}"
          fw_name    = fw.name
          fw_idx     = fw_idx
          nic_idx    = nic_idx
          nic_config = nic
        }
      ]
    ]) : item.key => item
  }

  name                           = each.value.nic_config.name != null ? "nic_${each.value.fw_name}-${each.value.nic_config.name}-${each.value.fw_idx}" : "nic_${each.value.fw_name}-${each.value.nic_idx}"
  location                       = var.location == null ? azurerm_resource_group.this.location : var.location
  resource_group_name            = azurerm_resource_group.this.name
  accelerated_networking_enabled = true
  ip_forwarding_enabled          = each.value.nic_config.name == "management" ? null : true

  dynamic "ip_configuration" {
    for_each = each.value.nic_config.ip_configurations
    content {
      name                          = "ipconfig-${each.value.key}"
      subnet_id                     = azurerm_subnet.hub[ip_configuration.value.subnet_name].id
      private_ip_address_allocation = ip_configuration.value.private_ip_address_allocation
      private_ip_address            = ip_configuration.value.private_ip_address != null ? ip_configuration.value.private_ip_address : null
      primary                       = ip_configuration.value.primary

      # Conditionally assign public IP for specific interfaces
      # public_ip_address_id = ip_configuration.value.subnet_name != "private" ? azurerm_public_ip.firewall_pip["${each.value.fw_name}-${ip_configuration.value.subnet_name}"].id : null
      public_ip_address_id = ip_configuration.value.subnet_name == "management" ? azurerm_public_ip.firewall_pip["${each.value.fw_name}-${ip_configuration.value.subnet_name}"].id : null
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "firewall-networking"
    Firewall    = each.value.fw_name
    Role        = "firewall"
  }
}
