variable "azure_environment" {
  type    = string
  default = "usgovernment"
}

variable "cluster_name" {
  description = "Friendly cluster name, used for the storage prefix and resource naming."
  type        = string
}

variable "oidc_issuer_url" {
  description = "az aks show --name <cluster> --resource-group <rg> --query oidcIssuerProfile.issuerUrl -o tsv"
  type        = string
}

variable "kube_context" {
  description = "kubeconfig context name for this cluster (CI job should have already run `az aks get-credentials`)."
  type        = string
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "image" {
  description = "Container image reference for the aks-cost-export binary."
  type        = string
}

variable "identity_shard_index" {
  description = "Which shared identity (0-based) this cluster's federated credential is registered against. Shard clusters ~1:20 per identity until quota increase is approved."
  type        = number
  default     = 0
}

variable "schedule" {
  type    = string
  default = "10 0 * * *"
}

# --- Shared-state lookup (must match envs/shared/backend.hcl) ---
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
