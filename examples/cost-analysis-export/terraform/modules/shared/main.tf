terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.15"
    }
  }
}

resource "azurerm_resource_group" "shared" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "cost_exports" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.shared.name
  location                 = azurerm_resource_group.shared.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "cost_exports" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.cost_exports.name
  container_access_type = "private"
}

# Expire raw per-cluster daily exports; result.csv (merged output) is left alone.
resource "azurerm_storage_management_policy" "cost_exports" {
  storage_account_id = azurerm_storage_account.cost_exports.id

  rule {
    name    = "expire-raw-aks-exports"
    enabled = true
    filters {
      prefix_match = ["cost-analysis/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.raw_export_retention_days
      }
    }
  }

  rule {
    name    = "expire-raw-cost-management-exports"
    enabled = true
    filters {
      prefix_match = ["cost-management/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.raw_export_retention_days
      }
    }
  }
}

# One user-assigned identity per shard (see identity_count description).
resource "azurerm_user_assigned_identity" "cost_analysis" {
  count               = var.identity_count
  name                = "cost-analysis-identity-${count.index}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  count                = var.identity_count
  scope                = azurerm_storage_account.cost_exports.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.cost_analysis[count.index].principal_id
}

# Cost Management export API isn't fully modeled by azurerm, so use azapi for MG or
# subscription scope support (azurerm_cost_management_export only supports subscription/RG scope).
resource "azapi_resource" "cost_export" {
  type      = "Microsoft.CostManagement/exports@2023-07-01-preview"
  name      = "aks-cost-export"
  parent_id = var.cost_management_export_scope

  body = {
    properties = {
      displayName = "aks-cost-export"
      definition = {
        type = "Usage"
        dataSet = {
          granularity = "Daily"
        }
      }
      deliveryInfo = {
        destination = {
          resourceId     = azurerm_storage_account.cost_exports.id
          container      = azurerm_storage_container.cost_exports.name
          rootFolderPath = "cost-management"
        }
      }
      schedule = {
        status     = "Active"
        recurrence = "Daily"
        recurrencePeriod = {
          from = timestamp()
          to   = "2030-12-31T00:00:00Z"
        }
      }
      format                = "Csv"
      compressionMode       = "gzip"
      dataOverwriteBehavior = "OverwritePreviousReport"
    }
  }

  lifecycle {
    ignore_changes = [body.properties.schedule.recurrencePeriod.from]
  }
}
