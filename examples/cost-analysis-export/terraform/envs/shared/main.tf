module "shared" {
  source = "../../modules/shared"

  azure_environment    = var.azure_environment
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_name = var.storage_account_name

  existing_storage_account_resource_group_name = var.existing_storage_account_resource_group_name
  manage_lifecycle_policy                      = var.manage_lifecycle_policy
  storage_container_name                       = var.storage_container_name
  raw_export_retention_days                    = var.raw_export_retention_days
  cost_management_export_scope                 = var.cost_management_export_scope
  identity_count                               = var.identity_count
  tags                                         = var.tags
}
