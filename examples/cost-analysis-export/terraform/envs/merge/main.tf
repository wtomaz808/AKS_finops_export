data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = var.tfstate_shared_key
  }
}

module "merge" {
  source = "../../modules/workload"

  cluster_name       = var.hub_cluster_name
  oidc_issuer_url    = var.oidc_issuer_url
  identity_id        = data.terraform_remote_state.shared.outputs.identity_ids[var.identity_shard_index]
  identity_client_id = data.terraform_remote_state.shared.outputs.identity_client_ids[var.identity_shard_index]
  identity_tenant_id = data.terraform_remote_state.shared.outputs.tenant_id

  image          = var.image
  operation_mode = "merge"
  schedule       = var.schedule

  storage_account_name   = data.terraform_remote_state.shared.outputs.storage_account_name
  storage_suffix         = data.terraform_remote_state.shared.outputs.storage_suffix
  storage_container_name = data.terraform_remote_state.shared.outputs.storage_container_name

  # Merge reads every cluster's prefix under cost-analysis/ - keep the default
  # AZURE_STORAGE_AKS_DATA_PREFIX ("cost-analysis/") rather than a single-cluster one.
  aks_data_prefix = "cost-analysis/"
}
