# Terraform layout for scaling cost-analysis-export to many clusters

This structure supports rolling the CSV cost export out to 50+ AKS clusters spread
across multiple subscriptions under one management group, without every cluster
redundantly re-running the merge step.

## Layout

```
terraform/
├── modules/
│   ├── shared/     # Applied ONCE: resource group, storage account (+ lifecycle policy),
│   │                 sharded user-assigned identities, MG/subscription-scope Cost
│   │                 Management export
│   └── workload/    # Reusable per-cluster unit: federated identity credential + namespace
│                     + service account + CronJob. Parameterized by operation_mode
│                     (export | merge | both) so it's used for both per-cluster export
│                     jobs and the single centralized merge job.
├── envs/
│   ├── shared/     # Root module wrapping modules/shared. Apply once.
│   ├── cluster/     # Root module wrapping modules/workload (operation_mode=export).
│   │                 Applied once PER CLUSTER (see "Running at scale" below).
│   └── merge/        # Root module wrapping modules/workload (operation_mode=merge).
│                     Applied once, on a hub cluster (any existing cluster, or a small
│                     dedicated one).
└── clusters.example.json   # Example cluster inventory that drives the per-cluster CI matrix.
```

## Why not a single root module with `for_each` over clusters?

Terraform doesn't support `for_each`/`count` on provider blocks, and each cluster needs
its own `kubernetes` provider (different API server/kubeconfig context). The supported
pattern is: one Terraform state per cluster, applied via a CI pipeline matrix that loops
over the cluster inventory (`clusters.example.json`) and passes per-cluster
`-var-file`/`-backend-config` (state key) values into `envs/cluster`.

## Run order

1. **`envs/shared`** — once. Provisions the shared storage account, identities, and the
   Cost Management export at management-group scope. Requires Cost Management Contributor
   (or similar) at the MG scope to create the export via the `azapi` provider.
2. **`envs/cluster`** — once per cluster, via CI matrix. Each cluster must already have
   OIDC issuer + workload identity enabled, and be on Standard/Premium AKS tier (Cost
   Analysis add-on requirement). Requires:
   - `az aks get-credentials` already run for `kube_context`/`kubeconfig_path` to resolve.
   - `oidc_issuer_url` from `az aks show --query oidcIssuerProfile.issuerUrl`.
   - `identity_shard_index` picking which shared identity this cluster's federated
     credential is registered against (see quota note below).
3. **`envs/merge`** — once, on the hub cluster. Reads every cluster's
   `cost-analysis/<cluster>/export-*.csv` plus `cost-management/*.csv` and writes the
   single shared `cost-analysis/result.csv`.

## Federated identity credential quota

A single user-assigned managed identity has a **default quota of 20 federated
credentials** (one per cluster's OIDC issuer). Request a quota increase early — it can
take time to be approved. Until then, shard clusters across multiple identities using
`identity_count` (in `envs/shared`) and `identity_shard_index` (in `envs/cluster`),
e.g. `identity_count = 3` for ~17 clusters per identity.

## State backend

All three envs use an `azurerm` backend with an empty `backend "azurerm" {}` block —
supply the actual storage account/container/key via `-backend-config` (see
`envs/shared/backend.hcl.example`). Give each cluster its own state key
(`cost-analysis-export/clusters/<cluster_name>.tfstate`) so the CI matrix can apply
clusters in parallel without state lock contention.

## Gov Cloud

Set `azure_environment = "usgovernment"` (default) on the `azurerm`/`azapi` providers,
and `azure_cloud = "AzureGovernment"` on the `workload` module — this must match the
`AZURE_CLOUD` value the Go app understands (see `../main.go`).

## Tenant and subscription targeting

Every root module requires `tenant_id` and `subscription_id`, so applies don't depend on
the active `az account`. Use the subscription that hosts the shared resources (the same
value in all three envs). Each env ships a `terraform.tfvars.example` to copy to
`terraform.tfvars` (gitignored).
