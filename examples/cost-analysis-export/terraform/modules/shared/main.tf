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

locals {
  create_storage_account = var.existing_storage_account_resource_group_name == null

  storage_account_id = local.create_storage_account ? azurerm_storage_account.cost_exports[0].id : data.azurerm_storage_account.existing[0].id
  storage_account_nm = local.create_storage_account ? azurerm_storage_account.cost_exports[0].name : data.azurerm_storage_account.existing[0].name
  blob_endpoint      = local.create_storage_account ? azurerm_storage_account.cost_exports[0].primary_blob_endpoint : data.azurerm_storage_account.existing[0].primary_blob_endpoint
}

resource "azurerm_resource_group" "shared" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "cost_exports" {
  count                    = local.create_storage_account ? 1 : 0
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.shared.name
  location                 = azurerm_resource_group.shared.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

# Reuse a storage account that already exists (for example, one owned by the shared
# services team) instead of creating one.
data "azurerm_storage_account" "existing" {
  count               = local.create_storage_account ? 0 : 1
  name                = var.storage_account_name
  resource_group_name = var.existing_storage_account_resource_group_name
}

resource "azurerm_storage_container" "cost_exports" {
  name                  = var.storage_container_name
  storage_account_name  = local.storage_account_nm
  container_access_type = "private"
}

# Expire raw per-cluster daily exports; result.csv (merged output) is left alone.
# A storage account has one management policy, and this resource replaces all of its rules.
resource "azurerm_storage_management_policy" "cost_exports" {
  count              = var.manage_lifecycle_policy ? 1 : 0
  storage_account_id = local.storage_account_id

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
  scope                = local.storage_account_id
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
      definition = {
        type      = "Usage"
        timeframe = "MonthToDate"
        dataSet = {
          granularity = "Daily"
        }
      }
      deliveryInfo = {
        destination = {
          resourceId     = local.storage_account_id
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
