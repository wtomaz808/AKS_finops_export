variable "cluster_name" {
  description = "Friendly name of the target AKS cluster (used for storage path prefixing)."
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the target AKS cluster (az aks show --query oidcIssuerProfile.issuerUrl)."
  type        = string
}

variable "identity_id" {
  description = "Resource ID of the user-assigned managed identity (from the shared module, sharded across clusters)."
  type        = string
}

variable "identity_client_id" {
  description = "Client ID of the user-assigned managed identity."
  type        = string
}

variable "identity_tenant_id" {
  description = "Tenant ID for the workload identity federation."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the export/merge workload."
  type        = string
  default     = "cost-analysis"
}

variable "manage_namespace" {
  description = "Whether this module instance creates the namespace. Set false when another instance (e.g. an export job) on the same physical cluster already manages it."
  type        = bool
  default     = true
}

variable "service_account_name" {
  description = "Defaults to cost-analysis-<operation_mode>-sa if unset, so export/merge jobs on the same cluster get distinct ServiceAccounts and federated credentials."
  type        = string
  default     = null
}

variable "image" {
  description = "Container image reference for the aks-cost-export binary."
  type        = string
}

variable "operation_mode" {
  description = "Operation mode passed as the container arg: export, merge, or both."
  type        = string
  default     = "export"
  validation {
    condition     = contains(["export", "merge", "both"], var.operation_mode)
    error_message = "operation_mode must be one of: export, merge, both."
  }
}

variable "schedule" {
  description = "Cron schedule for the CronJob."
  type        = string
  default     = "10 0 * * *"
}

variable "azure_cloud" {
  description = "AZURE_CLOUD value understood by the app: AzurePublic, AzureGovernment, AzureChina."
  type        = string
  default     = "AzureGovernment"
}

variable "storage_account_name" {
  type = string
}

variable "storage_suffix" {
  description = "Blob DNS suffix for the active cloud, from the shared module output."
  type        = string
}

variable "storage_container_name" {
  type    = string
  default = "cost-exports"
}

variable "aks_data_prefix" {
  description = "Per-cluster storage prefix for raw exports. Defaults to cost-analysis/<cluster_name>/."
  type        = string
  default     = null
}

variable "cost_export_prefix" {
  type    = string
  default = "cost-management/"
}

variable "result_file" {
  description = "Shared merged result path. Only meaningful for merge/both jobs."
  type        = string
  default     = "cost-analysis/result.csv"
}

variable "cost_analysis_url" {
  type    = string
  default = "http://cost-analysis-agent-svc.kube-system:9094"
}
