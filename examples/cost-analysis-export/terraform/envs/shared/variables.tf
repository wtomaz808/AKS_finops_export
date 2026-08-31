variable "azure_environment" {
  type    = string
  default = "usgovernment"
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
