# Subscription ID and Resource Group Variables
# Best not to check in information like subscription IDs in public repos
# Can be supplied environment variables at runtime
variable "subscription_id" {
  description = "The subscription ID for the Azure resources."
  type        = string
}

variable "expiresAfter" {
  description = "Tag to indicate when resource expires, e.g., '30d' for 30 days."
  type        = string
  default     = "2025-11-30"
}
variable "builtFrom" {
  description = "Tag to indicate where the resource was built from."
  type        = string
  default     = "localdev"
}

variable "product" {
  description = "Tag to indicate the product for the resource."
  type        = string
  default     = "hub"
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
  default     = null
}

variable "environment" {
  description = "The environment for the Azure resources."
  type        = string
  default     = "sbox"
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault containing secrets"
  type        = string
  default     = null
}

variable "key_vault_resource_group_name" {
  description = "Resource group name where Key Vault is located. If null, uses the same resource group as other resources."
  type        = string
  default     = null
}

variable "windows_admin_password_secret_name" {
  description = "Name of the Key Vault secret containing Windows admin password"
  type        = string
  default     = "windows-admin-password"
}

# Network Configuration Variables
variable "hub_network_name" {
  description = "The name of the hub virtual network."
  type        = string
}

variable "hub_address_space" {
  description = "The address space of the hub virtual network."
  type        = list(string)
}

variable "hub_subnets" {
  description = "A list of subnets for the hub virtual network."
  type = list(object({
    name                    = string
    address_prefixes        = list(string)
    security_group_enabled  = optional(bool, true)
    nat_gateway_association = optional(bool, false)
    rules = optional(list(object({
      name                         = string
      priority                     = number
      direction                    = string
      access                       = string
      protocol                     = string
      source_port_range            = optional(string)
      source_port_ranges           = optional(list(number))
      destination_port_range       = optional(string)
      destination_port_ranges      = optional(list(number))
      source_address_prefix        = optional(string)
      source_address_prefixes      = optional(list(string))
      destination_address_prefix   = optional(string)
      destination_address_prefixes = optional(list(string))
    })), [])
  }))
}

variable "public_subnet_name" {
  description = "The name of the public subnet. Must be same defined in the .tfvars"
  type        = string
  default     = "public"
}

variable "private_subnet_name" {
  description = "The name of the private subnet. Must be same defined in the .tfvars"
  type        = string
  default     = "private"
}

variable "nat_gateway_name" {
  description = "The name of the NAT Gateway."
  type        = string
}

variable "spoke_network" {
  description = "List of spoke networks with their configuration including subnets and VMs"
  type = list(object({
    name          = string
    address_space = list(string)
    subnets = list(object({
      name                   = string
      address_prefixes       = list(string)
      security_group_enabled = optional(bool, true)
      rules = list(object({
        name                         = string
        priority                     = number
        direction                    = string
        access                       = string
        protocol                     = string
        source_port_range            = optional(string)
        source_port_ranges           = optional(list(string))
        destination_port_range       = optional(string)
        destination_port_ranges      = optional(list(string))
        source_address_prefix        = optional(string)
        source_address_prefixes      = optional(list(string))
        destination_address_prefix   = optional(string)
        destination_address_prefixes = optional(list(string))
      }))
      route_table_enabled = optional(bool, true)
      routes = optional(list(object({
        name                   = string
        address_prefix         = string
        next_hop_type          = string
        next_hop_in_ip_address = optional(string)
      })), [])
      vms = optional(list(object({
        type                            = string
        name                            = string
        computer_name                   = string
        admin_username                  = string
        admin_password                  = optional(string)
        disable_password_authentication = bool
        size                            = string
        storage_account_type            = string
        zone                            = optional(string)
        os_disk = object({
          name                 = optional(string)
          caching              = string
          storage_account_type = string
        })
        source_image_reference = object({
          publisher = string
          offer     = string
          sku       = string
          version   = string
        })
        network_interfaces = list(object({
          name = optional(string)
          ip_configurations = list(object({
            name                          = optional(string)
            private_ip_address_allocation = optional(string, "Dynamic")
            subnet_id                     = optional(string)
            primary                       = optional(bool, false)
          }))
        }))
      })), [])
    }))
    peering_enabled = bool
  }))
  default = []
}

variable "firewall_vm_series" {
  description = "Configuration for VM-Series firewall virtual machine"
  type = list(object({
    name                            = optional(string)
    computer_name                   = optional(string)
    admin_username                  = string
    admin_password                  = optional(string)
    disable_password_authentication = optional(bool, true)
    size                            = string
    zone                            = optional(string)
    os_disk = object({
      name                 = optional(string)
      caching              = string
      storage_account_type = string
    })
    plan = optional(object({
      name      = string
      publisher = string
      product   = string
    }))
    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })
    disk_size_gb = optional(number)
    network_interfaces = list(object({
      name = optional(string)
      ip_configurations = list(object({
        name                          = optional(string)
        private_ip_address_allocation = optional(string, "Dynamic")
        private_ip_address            = optional(string)
        subnet_name                   = optional(string)
        primary                       = optional(bool, false)
        public_ip_address_allocation  = optional(string, "Dynamic")
        public_ip_address_id          = optional(string)
      }))
    }))
  }))
  default = []
}

variable "public_lb_config" {
  description = "Configuration for public load balancer"
  type = list(object({
    name         = string
    ports        = list(number)
    backend_port = optional(number)
  }))
  default = []
}
