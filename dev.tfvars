
subscription_id = "your-subscription-id"

# Resource group 
resource_group_name = "rg-fd-mvp-demo"
location            = "UK South"

# Network Configuration variable values
hub_network_name  = "vnet-hub-network"
hub_address_space = ["10.0.1.0/24"]

hub_subnets = [
  {
    name                   = "AzureBastionSubnet",
    address_prefixes       = ["10.0.1.0/26"]
    security_group_enabled = false
    rules                  = []
  },
  {
    name                   = "management",
    address_prefixes       = ["10.0.1.64/26"]
    security_group_enabled = true
    rules = [
      # Allow inbound from internet from your ip for all traffic - adjust as needed
      # In production this should be removed after initial setup, best to put in controls
      # like App Proxy or VPN to reach management subnet
      {
        name                       = "allow-internet-inbound-your-ip"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = [80, 443]
        source_address_prefix      = "0.0.0.0/0" # ‼️ Update with your real IP in the Azure portal
        destination_address_prefix = "*"
      }
    ]
  },
  {
    name                    = "public",
    address_prefixes        = ["10.0.1.128/26"]
    security_group_enabled  = true
    nat_gateway_association = true
    rules = [
      # Add rule called allow-http-inbound to allow inbound HTTP traffic from internet on port 80 and 443 
      {
        name                       = "allow-http-inbound"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = [80, 443]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    ]
  },
  {
    name                   = "private",
    address_prefixes       = ["10.0.1.192/26"]
    security_group_enabled = true
    rules = [
      # # Allow inbound from any private network on any port
      # {
      #   name                       = "allow-private-inbound"
      #   priority                   = 100
      #   direction                  = "Inbound"
      #   access                     = "Allow"
      #   protocol                   = "*"
      #   source_port_range          = "*"
      #   destination_port_range     = "*"
      #   source_address_prefix      = "*"
      #   destination_address_prefix = "*"
      # }
    ]
  }
]

nat_gateway_name = "nat-gateway-hub"

# List of spoke networks in reusable fashion
# Each spoke network is defined with its name, address space, and peering status
spoke_network = [
  {
    name          = "spoke-network-1"
    address_space = ["10.0.2.0/24"]
    subnets = [
      {
        name                   = "spoke-network-1-subnet",
        address_prefixes       = ["10.0.2.0/26"]
        security_group_enabled = true
        rules                  = []
        route_table_enabled    = true
        routes = [
          {
            name                   = "Default"
            address_prefix         = "0.0.0.0/0"
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = null
          }
        ]
        vms = [
          {
            type                            = "linux"
            name                            = "linuxwebserver"
            computer_name                   = "linuxwebserver"
            admin_username                  = "spoke1-azureuser"
            admin_password                  = null
            disable_password_authentication = true
            size                            = "Standard_D2ds_v5"
            storage_account_type            = "Standard_LRS"
            os_disk = {
              caching              = "ReadWrite"
              storage_account_type = "Standard_LRS"
            }
            # Might want to run some of these commands to find suitable images. Skip offer and or sku if you want to see all options
            # az vm image list --publisher Canonical --offer 0001-com-ubuntu-server-jammy --sku 22_04-lts --all --output table
            source_image_reference = {
              publisher = "Canonical"
              offer     = "0001-com-ubuntu-server-jammy"
              sku       = "22_04-lts"
              version   = "latest"
            }
            network_interfaces = [
              {
                name = null
                ip_configurations = [
                  {
                    name                          = null
                    private_ip_address_allocation = "Dynamic"
                    subnet_id                     = null # To be set in the VM resource
                    private_ip_address_allocation = "Dynamic"
                    primary                       = true
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
    peering_enabled = true
  },
  {
    name          = "spoke-network-2"
    address_space = ["10.0.3.0/24"]
    subnets = [
      {
        name                   = "default",
        address_prefixes       = ["10.0.3.0/26"]
        security_group_enabled = true
        rules = [
          # # Allow inbound from any private network on any port
          # {
          #   name                       = "allow-private-inbound"
          #   priority                   = 100
          #   direction                  = "Inbound"
          #   access                     = "Allow"
          #   protocol                   = "*"
          #   source_port_range          = "*"
          #   destination_port_range     = "*"
          #   source_address_prefix      = "*"
          #   destination_address_prefix = "*"
          # }
        ]
        route_table_enabled = true
        routes = [
          {
            name                   = "Default"
            address_prefix         = "0.0.0.0/0"
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = null
          }
        ]
        vms = [
          {
            type                            = "windows"
            name                            = "winserver1"
            computer_name                   = "winserver1"
            admin_username                  = "spoke1-winadmin"
            admin_password                  = null # "P@ssw0rd123!"
            disable_password_authentication = false
            size                            = "Standard_D2ds_v5"
            storage_account_type            = "Standard_LRS"
            os_disk = {
              caching              = "ReadWrite"
              storage_account_type = "Standard_LRS"
            }
            source_image_reference = {
              publisher = "MicrosoftWindowsServer"
              offer     = "WindowsServer"
              sku       = "2022-Datacenter"
              version   = "latest"
            }
            network_interfaces = [
              {
                name = null
                ip_configurations = [
                  {
                    name                          = null
                    private_ip_address_allocation = "Dynamic"
                    subnet_id                     = null # To be set in the VM resource
                    primary                       = true
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
    peering_enabled = true

  }
]

firewall_vm_series = [
  {
    name                            = "fw-palo"
    computer_name                   = "fw-palo"
    admin_username                  = "fwadmin"
    admin_password                  = null
    disable_password_authentication = true
    size                            = "Standard_D8ds_v5"
    storage_account_type            = "Standard_LRS"
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
    # Palo Alto VM-Series BYOL image
    plan = {
      name      = "byol"
      publisher = "paloaltonetworks"
      product   = "vmseries-flex"
    }
    source_image_reference = {
      publisher = "paloaltonetworks"
      offer     = "vmseries-flex"
      sku       = "byol"
      version   = "latest"
    }
    disk_size_gb = 60
    network_interfaces = [
      {
        name = "management"
        ip_configurations = [
          {
            name                          = null
            private_ip_address_allocation = "Dynamic"
            subnet_name                   = "management" # To be set in the VM resource
            primary                       = true
            public_ip_address_allocation  = "Dynamic"
          }
        ]
      },
      {
        name = "public"
        ip_configurations = [
          {
            name                          = null
            private_ip_address_allocation = "Dynamic"
            subnet_name                   = "public" # To be set in the VM resource
            primary                       = true
          }
        ]
      },
      {
        name = "private"
        ip_configurations = [
          {
            name                          = null
            private_ip_address_allocation = "Dynamic"
            subnet_name                   = "private" # To be set in the VM resource
            primary                       = true
          }
        ]
      }
    ]
  }
]

# Load Balancer configuration
loadbalancers = [
  {
    name     = "public"
    location = null
    sku      = "Standard"
  }
]

# Load Balancer backend pool configuration
public_lb_config = [
  {
    name  = "primary"
    ports = [80]
  },
  {
    name  = "webserver1"
    ports = [80]
}]
