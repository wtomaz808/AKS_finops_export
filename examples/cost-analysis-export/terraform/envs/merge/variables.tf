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

variable "hub_shares_cluster_with_export" {
  description = "Set true when hub_cluster_name is also one of envs/cluster's export clusters (that state already owns the cost-analysis namespace there)."
  type        = bool
  default     = false
}

variable "shared_state_path" {
  description = "Path to envs/shared's local terraform.tfstate file."
  type        = string
  default     = "../shared/terraform.tfstate"
}
