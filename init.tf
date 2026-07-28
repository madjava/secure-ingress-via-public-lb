provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

terraform {
  # In CI/CD, use remote backends e.g Azure Storage, HashiCorp Cloud etc.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    tls = {
      source = "hashicorp/tls"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

# # Accept marketplace terms for Palo Alto VM-Series images. Comment out if already accepted.
# az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan byol --subscription MySubscription
resource "azurerm_marketplace_agreement" "vm-series" {
  publisher = "paloaltonetworks"
  offer     = "vmseries-flex"
  plan      = "byol"
}

# az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan bundle1 --subscription MySubscription
resource "azurerm_marketplace_agreement" "vm-series-bundle2" {
  publisher = "paloaltonetworks"
  offer     = "vmseries-flex"
  plan      = "bundle2"
}

# az vm image terms accept --publisher paloaltonetworks --offer vmseries-flex --plan bundle2 --subscription MySubscription
resource "azurerm_marketplace_agreement" "vm-series-bundle3" {
  publisher = "paloaltonetworks"
  offer     = "vmseries-flex"
  plan      = "bundle3"
}

# Create a random password
resource "random_password" "password" {
  length           = 8
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create a random string suffix for DNS names
resource "random_string" "suffix" {
  length  = 7
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# Create a random string suffix for storage account names
resource "random_string" "storage_suffix" {
  length  = 5
  upper   = false
  lower   = true
  numeric = true
  special = false
}