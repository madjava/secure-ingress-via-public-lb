# Create Linux Virtual Machines for Firewall VM Series
resource "azurerm_linux_virtual_machine" "firewall_vms" {
  for_each = {
    for idx, fw in var.firewall_vm_series : "${fw.name}-${idx}" => {
      idx = idx
      fw  = fw
    }
  }

  name                = "vm_${each.value.fw.name}-${each.value.idx}"
  location            = var.location == null ? azurerm_resource_group.this.location : var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = each.value.fw.size
  zone                = each.value.fw.zone

  # Collect all network interface IDs for this specific firewall
  network_interface_ids = [
    for nic_key, nic in azurerm_network_interface.firewall_nics :
    nic.id if startswith(nic_key, "${each.value.fw.name}-nic-")
  ]

  disable_password_authentication = each.value.fw.disable_password_authentication
  admin_username                  = each.value.fw.admin_username
  computer_name                   = each.value.fw.computer_name

  # SSH key configuration for firewall VMs
  dynamic "admin_ssh_key" {
    for_each = each.value.fw.disable_password_authentication ? [1] : []
    content {
      username   = each.value.fw.admin_username
      public_key = tls_private_key.firewall.public_key_openssh
    }
  }

  os_disk {
    name                 = each.value.fw.os_disk.name
    caching              = each.value.fw.os_disk.caching
    storage_account_type = each.value.fw.os_disk.storage_account_type
    disk_size_gb         = each.value.fw.disk_size_gb
  }

  plan {
    name      = each.value.fw.plan.name
    publisher = each.value.fw.plan.publisher
    product   = each.value.fw.plan.product
  }

  source_image_reference {
    publisher = each.value.fw.source_image_reference.publisher
    offer     = each.value.fw.source_image_reference.offer
    sku       = each.value.fw.source_image_reference.sku
    version   = each.value.fw.source_image_reference.version
  }

  # Boot diagnostics for troubleshooting
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage.primary_blob_endpoint
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "firewall"
    Role        = "security-appliance"
    Vendor      = "paloalto"
    Type        = "vm-series"
  }

  depends_on = [
    azurerm_virtual_network.hub,
    azurerm_subnet.hub,
    azurerm_network_interface.firewall_nics
  ]
}
