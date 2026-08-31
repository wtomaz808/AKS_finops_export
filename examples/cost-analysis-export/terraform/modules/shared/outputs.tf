output "storage_account_name" {
  value = azurerm_storage_account.cost_exports.name
}

output "storage_account_id" {
  value = azurerm_storage_account.cost_exports.id
}

output "storage_container_name" {
  value = azurerm_storage_container.cost_exports.name
}

output "storage_suffix" {
  description = "Blob DNS suffix for the active azurerm environment (e.g. core.usgovcloudapi.net)."
  value       = trimsuffix(split(".blob.", azurerm_storage_account.cost_exports.primary_blob_endpoint)[1], "/")
}

output "identity_client_ids" {
  value = azurerm_user_assigned_identity.cost_analysis[*].client_id
}

output "identity_principal_ids" {
  value = azurerm_user_assigned_identity.cost_analysis[*].principal_id
}

output "identity_ids" {
  value = azurerm_user_assigned_identity.cost_analysis[*].id
}

output "identity_names" {
  value = azurerm_user_assigned_identity.cost_analysis[*].name
}

output "tenant_id" {
  value = azurerm_user_assigned_identity.cost_analysis[0].tenant_id
}

output "resource_group_name" {
  value = azurerm_resource_group.shared.name
}
