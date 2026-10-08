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
