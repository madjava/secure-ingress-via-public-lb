# Storage Account for VM Diagnostics and other uses
resource "azurerm_storage_account" "storage" {
  name                     = "sa${random_string.storage_suffix.result}${var.environment}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = var.location == null ? azurerm_resource_group.this.location : var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Purpose     = "storage account"
  }
}