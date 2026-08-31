variable "azure_environment" {
  type    = string
  default = "usgovernment"
}

variable "hub_cluster_name" {
  description = "Name of the cluster hosting the centralized merge CronJob (any cluster, or a small dedicated one)."
  type        = string
}

variable "oidc_issuer_url" {
  type = string
}

variable "kube_context" {
  type = string
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "image" {
  type = string
}

variable "identity_shard_index" {
  type    = number
  default = 0
}

variable "schedule" {
  description = "Merge should run after all per-cluster export jobs complete."
  type        = string
  default     = "30 0 * * *"
}

variable "tfstate_resource_group_name" {
  type = string
}

variable "tfstate_storage_account_name" {
  type = string
}

variable "tfstate_container_name" {
  type    = string
  default = "tfstate"
}

variable "tfstate_shared_key" {
  type    = string
  default = "cost-analysis-export/shared.tfstate"
}
