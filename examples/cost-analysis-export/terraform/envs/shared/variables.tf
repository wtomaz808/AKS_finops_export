variable "azure_environment" {
  type    = string
  default = "usgovernment"
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID that owns the target subscription."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "subscription_id" {
  description = "Subscription that hosts the shared resources (resource group, storage account, identities). This is where Terraform deploys, regardless of the active az account."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "existing_storage_account_resource_group_name" {
  description = "Resource group of an existing storage account named storage_account_name. Leave null to create a new one."
  type        = string
  default     = null
}

variable "manage_lifecycle_policy" {
  description = "Set false on an existing shared account so its current lifecycle rules aren't replaced."
  type        = bool
  default     = true
}

variable "network_default_action" {
  description = "Firewall default action (Allow or Deny) for a storage account Terraform creates. Ignored for an existing account."
  type        = string
  default     = "Allow"
}

variable "network_allowed_ip_ranges" {
  description = "IPs or CIDR ranges allowed through the firewall of a created account, such as the Terraform runner."
  type        = list(string)
  default     = []
}

variable "network_allowed_subnet_ids" {
  description = "Subnet IDs (with the Microsoft.Storage service endpoint) allowed through the firewall of a created account."
  type        = list(string)
  default     = []
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for a blob private endpoint on the storage account. Leave null to skip."
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs for the blob endpoint, such as privatelink.blob.core.usgovcloudapi.net. Leave empty if DNS is handled elsewhere."
  type        = list(string)
  default     = []
}

variable "storage_use_azuread" {
  description = "Create the blob container with Microsoft Entra authentication instead of account keys. Required when shared key access is disabled on the account. The deployer needs Storage Blob Data Owner or Contributor."
  type        = bool
  default     = false
}

variable "storage_container_name" {
  type    = string
  default = "cost-exports"
}

variable "raw_export_retention_days" {
  type    = number
  default = 30
}

variable "cost_management_export_scope" {
  description = "e.g. /providers/Microsoft.Management/managementGroups/<mg-name> or /subscriptions/<sub-id>"
  type        = string
}

variable "identity_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
