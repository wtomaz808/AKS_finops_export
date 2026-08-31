# Terraform configuration and modules

## Layout

```
terraform/
├── modules/
│   ├── shared/     # Applied ONCE: resource group, storage account (+ lifecycle policy),
│   │                 sharded user-assigned identities, MG/subscription-scope Cost
│   │                 Management export
│   └── workload/    # Reusable per-cluster unit: federated identity credential + namespace
│                     + service account + agent Service + CronJob. Parameterized by
│                     operation_mode (export | merge | both) so the same module is used
│                     for both per-cluster export jobs and the centralized merge job.
├── envs/
│   ├── shared/     # Root module wrapping modules/shared. Apply once.
│   ├── cluster/     # Root module wrapping modules/workload (operation_mode=export).
│   │                 Applied once PER CLUSTER.
│   └── merge/        # Root module wrapping modules/workload (operation_mode=merge).
│                     Applied once, on a hub cluster.
└── clusters.example.json   # Example cluster inventory to drive a per-cluster CI matrix.
```

## Why two module layers (`modules/` vs `envs/`)?

`modules/` contains the reusable building blocks. `envs/` contains the actual root
configurations that get applied — each with its own state, its own provider
configuration, and its own variables file. This separation is what makes the
per-cluster fan-out possible (see below) without duplicating the resource logic itself.

## Why not a single root module with `for_each` over clusters?

Terraform doesn't support `for_each`/`count` on **provider blocks**, and each AKS
cluster needs its own `kubernetes` provider instance (different API server endpoint,
different kubeconfig context). There's no way to parameterize a provider block per
loop iteration within one root module.

The supported pattern instead: **one Terraform state per cluster**, applied via a
CI/CD pipeline matrix that loops over a cluster inventory (`clusters.example.json`) and
passes per-cluster `-var-file`/backend state key values into `envs/cluster`. This is
also why `envs/cluster` and `envs/merge` are separate root configs from `envs/shared` —
they need independent state and independent provider configuration per invocation.

## `modules/shared`

Creates everything that exists exactly once, regardless of fleet size:
- Resource group, storage account, blob container, lifecycle management policy.
- One or more (`identity_count`) user-assigned managed identities — plan for sharding
  early if the fleet may exceed ~20 clusters (federated credential quota).
- The Cost Management export itself, via the `azapi` provider (the `azurerm` provider's
  native `azurerm_cost_management_export` resource only supports subscription/resource-
  group scope — `azapi` is required for management-group scope).

**Design notes worth knowing before extending this module:**
- The Cost Management export body must include `definition.timeframe` (e.g.
  `"MonthToDate"`) and must **not** include a `displayName` property — `azapi`'s
  schema validation is stricter than the raw ARM REST API (which silently accepts and
  ignores extra fields).
- The `lifecycle { ignore_changes = [...recurrencePeriod.from] }` block on the export
  resource is required — without it, every `terraform plan` would show a spurious diff
  because the original config used `timestamp()` as the recurrence start.
- In Azure Government specifically, `azapi`'s post-create polling can 401 against a
  different host (`consumption.azure.us`) even though the resource was created
  successfully — see [Operations & troubleshooting](07-operations-and-troubleshooting.md).

## `modules/workload`

The reusable per-cluster/per-role unit. Key design decisions:

- **`operation_mode` variable** (`export` | `merge` | `both`) drives: the container's
  `args`, whether the `cost-analysis-agent-svc` Service is created
  (`manage_agent_service = var.operation_mode != "merge"` — a merge-only job never
  calls the agent), and the default naming for the ServiceAccount and federated
  credential.
- **Mode-aware naming**: the federated identity credential name is
  `cost-analysis-<cluster_name>-<operation_mode>`, and the ServiceAccount name defaults
  to `cost-analysis-<operation_mode>-sa`. This matters because a single cluster can
  legitimately run **both** an export job and the centralized merge job (e.g. a small
  POC, or a fleet where the hub is just one of the regular clusters) — without the mode
  in the name, two module instances targeting the same cluster would collide trying to
  create identically-named Azure/Kubernetes resources.
- **`manage_namespace` variable** (default `true`): gates whether this module instance
  creates the Kubernetes namespace. When a merge job's hub cluster is also one of the
  export clusters, the namespace already exists (owned by that cluster's `envs/cluster`
  state) — a second, independent Terraform state trying to create the same namespace
  fails with "already exists" (Terraform's plan can't see it, since it lives in a
  different state). Set `manage_namespace = false` (surfaced in `envs/merge` as
  `hub_shares_cluster_with_export`) in that case.
- **All Kubernetes object names are read from variables directly**
  (`var.namespace`, not `kubernetes_namespace.this.metadata[0].name`) rather than
  from resource attributes — this removes an artificial dependency on the namespace
  resource existing in *this* state, which is what makes the `manage_namespace = false`
  path work cleanly.

## `envs/shared`, `envs/cluster`, `envs/merge`

Thin root modules wrapping the above, each with their own `providers.tf` and
`variables.tf`. `envs/cluster` and `envs/merge` read `envs/shared`'s outputs via a
`terraform_remote_state` data source — pointed at a local state file path for a
single-operator POC, or an `azurerm` backend (recommended for the real rollout) so the
values are available to CI matrix jobs running independently per cluster.

**Recommended state layout for the real multi-cluster rollout:**
- `envs/shared`: one state, e.g. `cost-analysis-export/shared.tfstate`.
- `envs/cluster`: one state **per cluster**, e.g.
  `cost-analysis-export/clusters/<cluster_name>.tfstate` — this is what allows a CI
  matrix to apply many clusters in parallel without state lock contention.
- `envs/merge`: one state, e.g. `cost-analysis-export/merge.tfstate`.

## Provider and cloud configuration

`azurerm`/`azapi` providers take an `environment` argument
(`public` | `usgovernment` | `china`) — set this once via the `azure_environment`
variable. This must be kept in sync with the `azure_cloud` value passed to the
`workload` module (`AzurePublic` | `AzureGovernment` | `AzureChina`), which is what the
Go application itself reads via the `AZURE_CLOUD` environment variable to select the
correct Entra/Storage endpoints at runtime — these are two independent settings (one
for Terraform's own Azure calls, one for the running container) and both need to match
the actual target cloud.

## Best practices for the Terraform layer

- Run `terraform fmt -recursive` and `terraform validate` (with `-backend=false` if you
  haven't configured a real backend yet) before every apply.
- Always `terraform plan -out=tfplan` and review before `terraform apply "tfplan"` —
  especially important here because seemingly small module changes (like the naming
  fix described above) can force replacement of federated credentials and
  ServiceAccounts on already-deployed clusters.
- Commit `.terraform.lock.hcl` files (provider version pins) — don't commit
  `.terraform/` cache directories, `.tfstate` files, `*.tfvars` (cluster-specific
  values), or `tfplan` binary plan files.
- Prefer management-group-scope Cost Management exports over per-subscription exports
  whenever the fleet spans multiple subscriptions under a common management group.
