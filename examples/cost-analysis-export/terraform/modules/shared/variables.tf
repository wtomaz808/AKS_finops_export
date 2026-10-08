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
  description = "Storage account name for cost export data (lowercase, no dashes). Created unless existing_storage_account_resource_group_name is set."
  type        = string
}

variable "existing_storage_account_resource_group_name" {
  description = "Resource group of an existing storage account named storage_account_name. When set, Terraform reuses it instead of creating one."
  type        = string
  default     = null
}

variable "manage_lifecycle_policy" {
  description = "Create the lifecycle rules that expire raw exports. Set false on a shared existing account, because the policy resource replaces any rules already on the account."
  type        = bool
  default     = true
}

variable "network_default_action" {
  description = "Firewall default action for a storage account Terraform creates (Allow or Deny). Ignored for an existing account. The AzureServices bypass is always on so the Cost Management export can write."
  type        = string
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "network_default_action must be Allow or Deny."
  }
}

variable "network_allowed_ip_ranges" {
  description = "Public IPs or CIDR ranges allowed through the firewall of a created account (for example, the Terraform runner). Ignored for an existing account."
  type        = list(string)
  default     = []
}

variable "network_allowed_subnet_ids" {
  description = "Subnet IDs allowed through the firewall of a created account. The subnets need the Microsoft.Storage service endpoint. Ignored for an existing account."
  type        = list(string)
  default     = []
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID in which to create a blob private endpoint. Leave null to skip. Must be in the same region as the endpoint's resource group location."
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs for the endpoint (privatelink.blob.core.usgovcloudapi.net in Azure Government). Leave empty if DNS registration is handled elsewhere."
  type        = list(string)
  default     = []
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
