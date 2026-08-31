variable "azure_environment" {
  description = "Azure cloud environment for the azurerm/azuread providers (public, usgovernment, china)."
  type        = string
  default     = "usgovernment"
}

variable "location" {
  description = "Azure region for the shared resource group and storage account."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the shared resource group hosting storage + identity resources."
  type        = string
}

variable "storage_account_name" {
  description = "Globally-unique storage account name for cost export data (lowercase, no dashes)."
  type        = string
}

variable "storage_container_name" {
  description = "Blob container name for cost exports."
  type        = string
  default     = "cost-exports"
}

variable "raw_export_retention_days" {
  description = "Days to retain raw per-cluster export-*.csv blobs before lifecycle deletion. result.csv is never expired."
  type        = number
  default     = 30
}

variable "cost_management_export_scope" {
  description = <<-EOT
    Full resource ID of the scope for the Cost Management export.
    Use a management group scope for multi-subscription rollouts, e.g.
    /providers/Microsoft.Management/managementGroups/<mg-name>
    or a subscription scope: /subscriptions/<sub-id>
  EOT
  type        = string
}

variable "identity_count" {
  description = <<-EOT
    Number of user-assigned managed identities to create for workload identity federation.
    A single identity has a default federated-credential quota of 20 (one per cluster OIDC
    issuer). Shard clusters across multiple identities until a quota increase is approved,
    e.g. identity_count = 3 for ~17 clusters each.
  EOT
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags applied to all shared resources."
  type        = map(string)
  default     = {}
}
