# Public loadbalancer resources
# Public IP's
resource "azurerm_public_ip" "lb_pips" {

  for_each = {
    for pip in var.public_lb_config : pip.name => pip
  }

  name                = lower("ip_${each.value.name}-${var.environment}")
  location            = var.location == null ? azurerm_resource_group.this.location : var.location
  resource_group_name = var.resource_group_name == null ? azurerm_resource_group.this.name : var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "lb-${var.environment}-${each.value.name}"
  #   zones               = ["1", "2", "3"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "public load balancer ip"
  }
}

# Public Load Balancer
resource "azurerm_lb" "lb_public" {
  location            = var.location == null ? azurerm_resource_group.this.location : var.location
  name                = "lb_public-${var.environment}"
  resource_group_name = var.resource_group_name == null ? azurerm_resource_group.this.name : var.resource_group_name
  sku                 = "Standard"


  dynamic "frontend_ip_configuration" {
    for_each = azurerm_public_ip.lb_pips

    content {
      name                 = "fe-${frontend_ip_configuration.value.name}"
      public_ip_address_id = frontend_ip_configuration.value.id
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "public load balancer"
  }

  depends_on = [azurerm_subnet.hub]
}

# Public Load balancer probe
resource "azurerm_lb_probe" "lb_public" {
  loadbalancer_id     = azurerm_lb.lb_public.id
  name                = "public-probe-${var.environment}"
  port                = 443
  protocol            = "Tcp"
  interval_in_seconds = 5
}

# Public LB Backend Pool
resource "azurerm_lb_backend_address_pool" "lb_public" {
  name            = "lb-backend-${var.environment}"
  loadbalancer_id = azurerm_lb.lb_public.id
}

# Public LB Associations
resource "azurerm_network_interface_backend_address_pool_association" "lb_public_public" {
  # Filter firewall NICs that are connected to the public subnet based on configuration
  for_each = {
    for item in flatten([
      for fw_idx, fw in var.firewall_vm_series : [
        for nic_idx, nic in fw.network_interfaces : [
          for ip_idx, ip_config in nic.ip_configurations : {
            key         = "${fw.name}-nic-${nic_idx}"
            fw_name     = fw.name
            nic_idx     = nic_idx
            ip_idx      = ip_idx
            nic_config  = nic
            ip_config   = ip_config
            subnet_name = ip_config.subnet_name
          } if ip_config.subnet_name == var.public_subnet_name
        ]
      ]
    ]) : item.key => item
  }

  network_interface_id    = azurerm_network_interface.firewall_nics[each.key].id
  ip_configuration_name   = "ipconfig-${each.value.key}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_public.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    azurerm_network_interface.firewall_nics,
    azurerm_linux_virtual_machine.firewall_vms
  ]
}

# Each port will have its own rule e.g. ip-primary-80, ip-primary-443.
# Same IP can have multiple rules for different ports.
locals {
  rules_config_list = flatten([
    for config in var.public_lb_config : [
      for idx, port in config.ports : {
        name         = config.name
        port         = port
        backend_port = try(port.backend_port[idx], port)
      }
    ]
  ])
}

# Creates multiple rules for each frontend ip create per port specified in the public_lb_config variable
resource "azurerm_lb_rule" "this" {
  for_each = {
    for idx, config in local.rules_config_list : "${config.name}_${config.port}" => config
  }

  name                           = "lb-rule-${each.value.name}-${each.value.port}"
  frontend_ip_configuration_name = lower("fe-ip_${each.value.name}-${var.environment}")
  loadbalancer_id                = azurerm_lb.lb_public.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_public.id]
  backend_port                   = try(each.value.backend_port, each.value.port)
  frontend_port                  = each.value.port
  protocol                       = "Tcp"
  floating_ip_enabled            = true
  probe_id                       = azurerm_lb_probe.lb_public.id
  disable_outbound_snat          = true
}

# Private loadbalancer resources
resource "azurerm_lb" "lb_private" {
  location            = var.location == null ? azurerm_resource_group.this.location : var.location
  name                = "lb_private-${var.environment}"
  resource_group_name = var.resource_group_name == null ? azurerm_resource_group.this.name : var.resource_group_name
  sku                 = "Standard"


  frontend_ip_configuration {
    name                          = "frontend_private"
    subnet_id                     = azurerm_subnet.hub[var.private_subnet_name].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.hub[var.private_subnet_name].address_prefixes[0], 4)
  }

  frontend_ip_configuration {
    name                          = "frontend_public"
    subnet_id                     = azurerm_subnet.hub[var.public_subnet_name].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.hub[var.public_subnet_name].address_prefixes[0], 4)
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [azurerm_subnet.hub]
}

# Private Load balancer probe
resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id     = azurerm_lb.lb_private.id
  name                = "lb-https-probe"
  port                = 443
  protocol            = "Tcp"
  interval_in_seconds = 5
}

# Private LB Backend Pool
resource "azurerm_lb_backend_address_pool" "lb_private_0" {
  name            = "lb-backend-private-${var.environment}"
  loadbalancer_id = azurerm_lb.lb_private.id
}

resource "azurerm_lb_backend_address_pool" "lb_private_1" {
  name            = "lb-backend-public-${var.environment}"
  loadbalancer_id = azurerm_lb.lb_private.id
}

# Private LB Associations
resource "azurerm_network_interface_backend_address_pool_association" "lb_private_private" {
  # Filter firewall NICs that are connected to the private subnet based on configuration
  for_each = {
    for item in flatten([
      for fw_idx, fw in var.firewall_vm_series : [
        for nic_idx, nic in fw.network_interfaces : [
          for ip_idx, ip_config in nic.ip_configurations : {
            key         = "${fw.name}-nic-${nic_idx}"
            fw_name     = fw.name
            nic_config  = nic
            ip_config   = ip_config
            subnet_name = ip_config.subnet_name
          } if ip_config.subnet_name == var.private_subnet_name
        ]
      ]
    ]) : item.key => item
  }

  network_interface_id    = azurerm_network_interface.firewall_nics[each.key].id
  ip_configuration_name   = "ipconfig-${each.value.key}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_private_0.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "lb_private_public" {
  # Filter firewall NICs that are connected to the public subnet based on configuration
  for_each = {
    for item in flatten([
      for fw_idx, fw in var.firewall_vm_series : [
        for nic_idx, nic in fw.network_interfaces : [
          for ip_idx, ip_config in nic.ip_configurations : {
            key         = "${fw.name}-nic-${nic_idx}"
            fw_name     = fw.name
            nic_idx     = nic_idx
            ip_idx      = ip_idx
            nic_config  = nic
            ip_config   = ip_config
            subnet_name = ip_config.subnet_name
          } if ip_config.subnet_name == var.public_subnet_name
        ]
      ]
    ]) : item.key => item
  }

  network_interface_id    = azurerm_network_interface.firewall_nics[each.key].id
  ip_configuration_name   = "ipconfig-${each.value.key}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_private_1.id

  lifecycle {
    create_before_destroy = true
  }
}

# Private Load balancer rule
resource "azurerm_lb_rule" "lb_rule_private" {
  name                           = "lb-rule-private-${var.environment}"
  loadbalancer_id                = azurerm_lb.lb_private.id
  frontend_port                  = "0"
  frontend_ip_configuration_name = "frontend_private"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_private_0.id]
  backend_port                   = "0"
  protocol                       = "All"
  probe_id                       = azurerm_lb_probe.lb_probe.id
  floating_ip_enabled            = true

  lifecycle {
    create_before_destroy = true
  }

}

resource "azurerm_lb_rule" "lb_rule_public" {
  name                           = "lb-rule-public-${var.environment}"
  loadbalancer_id                = azurerm_lb.lb_private.id
  frontend_port                  = "0"
  frontend_ip_configuration_name = "frontend_public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_private_1.id]
  backend_port                   = "0"
  protocol                       = "All"
  probe_id                       = azurerm_lb_probe.lb_probe.id
  floating_ip_enabled            = true

  lifecycle {
    create_before_destroy = true
  }
}