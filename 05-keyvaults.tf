data "azurerm_client_config" "current" {}

# Create an SSH key
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an SSH key for firewall VM-Series
resource "tls_private_key" "firewall" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name == null ? "kv-${azurerm_resource_group.this.name}" : var.key_vault_name
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  location            = azurerm_resource_group.this.location
  sku_name            = "standard"

  purge_protection_enabled    = false
  enabled_for_disk_encryption = true

  # Enable RBAC for Key Vault
  rbac_authorization_enabled = true

  tags = {
    Environment = var.environment
    Purpose     = "key-vault"
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }

  depends_on = [
    tls_private_key.this
  ]
}

# Assign Key Vault Secrets Officer role to the current user/service principal
resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id

  # Add a delay to ensure the role assignment is propagated
  depends_on = [azurerm_key_vault.kv]
}

# Add a time delay to ensure RBAC propagation
resource "time_sleep" "rbac_propagation" {
  depends_on      = [azurerm_role_assignment.kv_secrets_officer]
  create_duration = "30s"
}

# Store the SSH private key in Key Vault as a secret
resource "azurerm_key_vault_secret" "ssh-key" {
  name         = "vm-ssh-key"
  value        = tls_private_key.this.private_key_pem
  key_vault_id = azurerm_key_vault.kv.id

  tags = {
    Environment = var.environment
    Purpose     = "vm-ssh-key"
  }

  depends_on = [
    time_sleep.rbac_propagation,
    tls_private_key.this
  ]
}

# Store the SSH private key in Key Vault as a secret
resource "azurerm_key_vault_secret" "windows_admin_password" {
  name         = var.windows_admin_password_secret_name
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.kv.id

  tags = {
    Environment = var.environment
    Purpose     = "vm-windows-admin-password"
  }

  depends_on = [
    time_sleep.rbac_propagation
  ]
}

# Store the SSH private key in Key Vault as a secret
resource "azurerm_key_vault_secret" "vm-series-key" {
  name         = "vm-series-key"
  value        = tls_private_key.firewall.private_key_pem
  key_vault_id = azurerm_key_vault.kv.id

  tags = {
    Environment = var.environment
    Purpose     = "vm-series-key"
  }

  depends_on = [
    time_sleep.rbac_propagation,
    tls_private_key.firewall
  ]
}
