# Azure resources

This solution creates two categories of resources: **shared** (created once, regardless
of cluster count) and **per-cluster** (created once per AKS cluster that participates).

## Shared resources (created once)

| Resource | Type | Purpose | Best practice |
|---|---|---|---|
| Resource group | `Microsoft.Resources/resourceGroups` | Container for all shared FinOps-export infrastructure. | Keep separate from application/workload resource groups; tag clearly (e.g. `purpose=finops-export`) since it's infrastructure, not a customer workload. |
| Storage account | `Microsoft.Storage/storageAccounts` | Destination for all raw per-cluster exports, the Cost Management export, and the final `result.csv`. | Standard LRS is sufficient (this is reporting data, not a production workload) — GRS only if cross-region DR of cost history matters. `min_tls_version = TLS1_2`. Keep `shared_access_key_enabled` on only if something still needs key auth (the app itself uses Workload Identity, not keys). |
| Blob container | `Microsoft.Storage/storageAccounts/blobServices/containers` | Holds all export data under `cost-analysis/` and `cost-management/` prefixes. | Private access only (no anonymous/public blob access). |
| Storage lifecycle management policy | `Microsoft.Storage/storageAccounts/managementPolicies` | Automatically expires raw per-cluster `export-*.csv` files and raw Cost Management export files after a retention window (default 30 days). | Never apply a delete rule to `result.csv` itself — only to the `cost-analysis/` and `cost-management/` raw-file prefixes, and exclude `result.csv` by prefix matching (already handled by the module's rule `prefix_match`). |
| User-assigned managed identity | `Microsoft.ManagedIdentity/userAssignedIdentities` | The identity every cluster's export/merge job authenticates as via Workload Identity federation. One or more (sharded) depending on cluster count. | See [Permissions & RBAC](03-permissions-and-rbac.md) for the exact role and its limitations. |
| Storage Blob Data Contributor role assignment | `Microsoft.Authorization/roleAssignments` | Grants the managed identity read/write access to the storage account's blob data plane. | Scope to the storage account only — never subscription or resource-group scope. |
| Cost Management export | `Microsoft.CostManagement/exports` | Standard daily Azure Cost Management usage export, delivered as CSV(.gz) to the shared storage account. Created at **subscription** or **management group** scope. | Prefer management-group scope for multi-subscription fleets — one export instead of N. Requires the `Microsoft.CostManagementExports` resource provider registered on the subscription (see [Troubleshooting](07-operations-and-troubleshooting.md)). |

## Per-cluster resources (created once per participating cluster)

| Resource | Type | Purpose | Best practice |
|---|---|---|---|
| Federated identity credential | `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials` | Binds a specific cluster's OIDC issuer + a specific Kubernetes ServiceAccount (namespace + name) to the shared managed identity, enabling passwordless token exchange. | One per cluster **per operation mode** (export vs. merge) if a cluster ever hosts both roles — name/subject must be unique per federated credential. Watch the 20-per-identity default quota. |
| Kubernetes Namespace | n/a (Kubernetes object, not ARM) | Isolates the workload's ServiceAccount, CronJob, and Jobs. | One namespace (`cost-analysis` by default) is enough per cluster even if it runs both export and merge roles — just don't let two independent Terraform states both try to own/create it (see [Terraform modules](05-terraform-modules.md)). |
| Kubernetes ServiceAccount | n/a (Kubernetes object) | The identity a Pod runs as; annotated with the managed identity's client ID/tenant ID to trigger Workload Identity token projection. | Distinct ServiceAccount per operation mode on a given cluster (`cost-analysis-export-sa` vs. `cost-analysis-merge-sa`) to keep federated credential subjects unique. |
| Kubernetes Service (`cost-analysis-agent-svc`, in `kube-system`) | n/a (Kubernetes object) | Exposes the AKS Cost Analysis add-on's agent pod (which the add-on deploys **without** a stable Service) on a predictable ClusterIP:port for the export job to call. | Only needed on clusters actually running the `export` (or `both`) role — a `merge`-only job never calls the agent. |
| Kubernetes CronJob | `batch/v1` CronJob | Schedules the periodic export or merge run. | See [AKS configuration](04-aks-configuration.md) for schedule, resource limits, and security context recommendations. |

## Non-Azure-resource dependencies

| Component | Purpose |
|---|---|
| Azure Container Registry | Hosts the `aks-cost-export` container image. Attach to each participating AKS cluster (`az aks update --attach-acr`) so kubelet can pull without imagePullSecrets. Not created by the Terraform modules in this repo — provision separately. |
| AKS Cost Analysis add-on | Must be enabled on every participating cluster (`az aks update --enable-cost-analysis`) — deploys the `cost-analysis-agent` pod the export job talks to. Requires Standard or Premium AKS pricing tier. |
