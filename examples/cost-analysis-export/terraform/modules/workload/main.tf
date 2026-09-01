terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

locals {
  aks_data_prefix = coalesce(var.aks_data_prefix, "cost-analysis/${var.cluster_name}/")
  blob_endpoint   = "https://${var.storage_account_name}.blob.${var.storage_suffix}/"
  common_labels = {
    "app.kubernetes.io/name"      = "aks-cost-analysis"
    "app.kubernetes.io/component" = var.operation_mode == "merge" ? "cost-merge" : "cost-export"
  }
  # "merge"-only jobs never call the in-cluster agent, so they don't need this Service.
  # Guard against creating it twice if export and merge both target the same hub cluster.
  manage_agent_service = var.operation_mode != "merge"
  # Distinct per operation_mode so export/merge on the same hub cluster get separate
  # ServiceAccounts and federated credentials instead of colliding on the same name.
  service_account_name = coalesce(var.service_account_name, "cost-analysis-${var.operation_mode}-sa")
}

# One federated credential per cluster's OIDC issuer, bound to the shared identity.
# Default per-identity quota is 20 credentials - shard clusters across identities in the
# root config if you approach that limit while a quota increase request is pending.
resource "azurerm_federated_identity_credential" "this" {
  name                = "cost-analysis-${var.cluster_name}-${var.operation_mode}"
  resource_group_name = split("/", var.identity_id)[4]
  parent_id           = var.identity_id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${local.service_account_name}"
}

# The AKS Cost Analysis add-on only deploys the cost-analysis-agent pod - it does not
# create a stable Service, so export/both jobs need this to reach it via COST_ANALYSIS_URL.
resource "kubernetes_service" "cost_analysis_agent" {
  count = local.manage_agent_service ? 1 : 0

  metadata {
    name      = "cost-analysis-agent-svc"
    namespace = "kube-system"
  }

  spec {
    selector = {
      "app"                            = "cost-analysis-agent"
      "kubernetes.azure.com/managedby" = "aks"
    }
    port {
      protocol    = "TCP"
      port        = 9094
      target_port = 9094
    }
  }
}

resource "kubernetes_namespace" "this" {
  # Skip if another workload instance on the same physical cluster (e.g. the export job,
  # when the merge hub is also an export cluster) already manages this namespace.
  count = var.manage_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = merge(local.common_labels, {
      "azure.workload.identity/use" = "true"
    })
  }
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = local.service_account_name
    namespace = var.namespace
    labels = merge(local.common_labels, {
      "azure.workload.identity/use" = "true"
    })
    annotations = {
      "azure.workload.identity/client-id" = var.identity_client_id
      "azure.workload.identity/tenant-id" = var.identity_tenant_id
    }
  }

  depends_on = [kubernetes_namespace.this]
}

resource "kubernetes_cron_job_v1" "this" {
  metadata {
    name      = "aks-cost-analysis-${var.operation_mode}"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    failed_jobs_history_limit     = 3
    successful_jobs_history_limit = 3

    job_template {
      metadata {}
      spec {
        template {
          metadata {
            labels = { "azure.workload.identity/use" = "true" }
          }
          spec {
            restart_policy       = "OnFailure"
            service_account_name = kubernetes_service_account.this.metadata[0].name

            security_context {
              run_as_non_root = true
              run_as_user     = 65534
              run_as_group    = 65534
              fs_group        = 65534
              seccomp_profile {
                type = "RuntimeDefault"
              }
            }

            container {
              name  = "cost-analysis-export"
              image = var.image
              args  = [var.operation_mode]

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                run_as_non_root            = true
                run_as_user                = 65534
                run_as_group               = 65534
                capabilities {
                  drop = ["ALL"]
                }
              }

              env {
                name  = "COST_ANALYSIS_URL"
                value = var.cost_analysis_url
              }
              env {
                name  = "AZURE_CLOUD"
                value = var.azure_cloud
              }
              env {
                name  = "CLUSTER_NAME"
                value = var.cluster_name
              }
              env {
                name  = "AZURE_STORAGE_BLOB_NAME"
                value = local.blob_endpoint
              }
              env {
                name  = "AZURE_STORAGE_CONTAINER_NAME"
                value = var.storage_container_name
              }
              env {
                name  = "AZURE_STORAGE_AKS_DATA_PREFIX"
                value = local.aks_data_prefix
              }
              env {
                name  = "AZURE_STORAGE_COST_EXPORT_PREFIX"
                value = var.cost_export_prefix
              }
              env {
                name  = "AZURE_STORAGE_RESULT_FILE"
                value = var.result_file
              }

              volume_mount {
                name       = "tmp"
                mount_path = "/tmp"
              }

              resources {
                requests = {
                  memory = "512Mi"
                  cpu    = "500m"
                }
                limits = {
                  memory = "512Mi"
                  cpu    = "500m"
                }
              }
            }

            volume {
              name = "tmp"
              empty_dir {
                size_limit = "2Gi"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [azurerm_federated_identity_credential.this]
}
