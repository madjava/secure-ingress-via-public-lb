
# Output SSH private key for accessing VMs
output "ssh_private_key" {
  description = "Private SSH key for accessing Linux VMs"
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

# Output VM information
output "linux_vm_details" {
  description = "Details of created Linux VMs"
  value = {
    for k, v in azurerm_linux_virtual_machine.linux_vms : k => {
      name               = v.name
      private_ip_address = v.private_ip_address
      public_ip_address  = v.public_ip_address
    }
  }
}

# Output Windows VM information
output "windows_vm_details" {
  description = "Details of created Windows VMs"
  value = {
    for k, v in azurerm_windows_virtual_machine.windows_vms : k => {
      name               = v.name
      private_ip_address = v.private_ip_address
      public_ip_address  = v.public_ip_address
    }
  }
}
