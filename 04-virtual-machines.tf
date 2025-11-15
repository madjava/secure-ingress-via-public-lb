
# Create network interfaces for all VMs across all spoke networks
resource "azurerm_network_interface" "vm_nics" {
  for_each = {
    for item in flatten([
      for spoke in var.spoke_network : [
        for subnet in spoke.subnets : [
          for vm in subnet.vms : [
            for nic_idx, nic in vm.network_interfaces : {
              key         = "${spoke.name}-${subnet.name}-${vm.name}-${nic_idx}"
              spoke_name  = spoke.name
              subnet_name = subnet.name
              vm_name     = vm.name
              nic_index   = nic_idx
              nic_config  = nic
              subnet_key  = "${spoke.name}-${subnet.name}"
            }
          ]
          if length(subnet.vms) > 0
        ]
      ]
    ]) : item.key => item
  }

  name                = each.value.nic_config.name == null ? "nic_${each.value.vm_name}-${each.value.nic_index}" : each.value.nic_config.name
  location            = var.location == null ? azurerm_resource_group.this.location : var.location
  resource_group_name = azurerm_resource_group.this.name

  dynamic "ip_configuration" {
    for_each = each.value.nic_config.ip_configurations
    content {
      name                          = ip_configuration.value.name == null ? "ipconfig-${each.value.vm_name}-${each.value.nic_index}" : ip_configuration.value.name
      subnet_id                     = ip_configuration.value.subnet_id == null ? azurerm_subnet.spoke[each.value.subnet_key].id : ip_configuration.value.subnet_id
      private_ip_address_allocation = ip_configuration.value.private_ip_address_allocation
      primary                       = ip_configuration.value.primary
    }
  }
  tags = {
    Environment = var.environment
    Purpose     = "vm-networking"
    Spoke       = each.value.spoke_name
    VM          = each.value.vm_name
  }
}

# Create Linux virtual machines
resource "azurerm_linux_virtual_machine" "linux_vms" {
  for_each = {
    for item in flatten([
      for spoke in var.spoke_network : [
        for subnet in spoke.subnets : [
          for idx, vm in subnet.vms : {
            key         = "${spoke.name}-${subnet.name}-${vm.name}"
            spoke_name  = spoke.name
            subnet_name = subnet.name
            vm_config   = vm
            subnet_key  = "${spoke.name}-${subnet.name}"
            vm_idx      = idx
          }
          if length(subnet.vms) > 0 && vm.type == "linux"
        ]
      ]
    ]) : item.key => item
  }

  name                = "vm_${each.value.vm_config.name}-${each.value.vm_idx}"
  location            = var.location == null ? azurerm_resource_group.this.location : var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = each.value.vm_config.size
  zone                = each.value.vm_config.zone

  # Get network interface IDs for this VM
  network_interface_ids = [
    for nic_idx in range(length(each.value.vm_config.network_interfaces)) :
    azurerm_network_interface.vm_nics["${each.key}-${nic_idx}"].id
  ]

  disable_password_authentication = each.value.vm_config.disable_password_authentication
  admin_username                  = each.value.vm_config.admin_username
  computer_name                   = each.value.vm_config.computer_name

  # Conditional authentication: Use password only if SSH authentication is disabled
  admin_password = each.value.vm_config.disable_password_authentication == false ? each.value.vm_config.admin_password : null

  # SSH key configuration for Linux VMs (only when password authentication is disabled)
  dynamic "admin_ssh_key" {
    for_each = each.value.vm_config.disable_password_authentication ? [1] : []
    content {
      username   = each.value.vm_config.admin_username
      public_key = tls_private_key.this.public_key_openssh
    }
  }

  os_disk {
    name                 = each.value.vm_config.os_disk.name
    caching              = each.value.vm_config.os_disk.caching
    storage_account_type = each.value.vm_config.os_disk.storage_account_type
  }

  source_image_reference {
    publisher = each.value.vm_config.source_image_reference.publisher
    offer     = each.value.vm_config.source_image_reference.offer
    sku       = each.value.vm_config.source_image_reference.sku
    version   = each.value.vm_config.source_image_reference.version
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "compute"
    Spoke       = each.value.spoke_name
    Type        = "linux"
  }
}


# Create Windows virtual machines
resource "azurerm_windows_virtual_machine" "windows_vms" {
  for_each = {
    for item in flatten([
      for spoke in var.spoke_network : [
        for subnet in spoke.subnets : [
          for idx, vm in subnet.vms : {
            key         = "${spoke.name}-${subnet.name}-${vm.name}"
            spoke_name  = spoke.name
            subnet_name = subnet.name
            vm_config   = vm
            subnet_key  = "${spoke.name}-${subnet.name}"
            vm_idx      = idx
          }
          if length(subnet.vms) > 0 && vm.type == "windows"
        ]
      ]
    ]) : item.key => item
  }

  name                = "vm_${each.value.vm_config.name}-${each.value.vm_idx}"
  location            = var.location == null ? azurerm_resource_group.this.location : var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = each.value.vm_config.size
  zone                = each.value.vm_config.zone

  # Get network interface IDs for this VM
  network_interface_ids = [
    for nic_idx in range(length(each.value.vm_config.network_interfaces)) :
    azurerm_network_interface.vm_nics["${each.key}-${nic_idx}"].id
  ]

  admin_username = each.value.vm_config.admin_username
  # Use Key Vault password if admin_password is null, otherwise use the provided password
  admin_password = each.value.vm_config.admin_password != null ? each.value.vm_config.admin_password : azurerm_key_vault_secret.windows_admin_password.value
  computer_name  = each.value.vm_config.computer_name

  os_disk {
    name                 = each.value.vm_config.os_disk.name
    caching              = each.value.vm_config.os_disk.caching
    storage_account_type = each.value.vm_config.os_disk.storage_account_type
  }

  source_image_reference {
    publisher = each.value.vm_config.source_image_reference.publisher
    offer     = each.value.vm_config.source_image_reference.offer
    sku       = each.value.vm_config.source_image_reference.sku
    version   = each.value.vm_config.source_image_reference.version
  }

  tags = {
    Environment = var.environment
    Purpose     = "compute"
    Spoke       = each.value.spoke_name
    Type        = "windows"
  }
}
