module "shared" {
  source = "../../modules/shared"

  azure_environment    = var.azure_environment
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_name = var.storage_account_name

  existing_storage_account_resource_group_name = var.existing_storage_account_resource_group_name
  manage_lifecycle_policy                      = var.manage_lifecycle_policy
  network_default_action                       = var.network_default_action
  network_allowed_ip_ranges                    = var.network_allowed_ip_ranges
  network_allowed_subnet_ids                   = var.network_allowed_subnet_ids
  private_endpoint_subnet_id                   = var.private_endpoint_subnet_id
  private_dns_zone_ids                         = var.private_dns_zone_ids
  storage_container_name                       = var.storage_container_name
  raw_export_retention_days                    = var.raw_export_retention_days
  cost_management_export_scope                 = var.cost_management_export_scope
  identity_count                               = var.identity_count
  tags                                         = var.tags
}
