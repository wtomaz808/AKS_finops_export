# Permissions, managed identity, and AKS RBAC

## Authentication model

The solution uses **Microsoft Entra Workload Identity** exclusively — no connection
strings, storage account keys, or client secrets are used at runtime. The flow:

1. A Kubernetes ServiceAccount is annotated with `azure.workload.identity/client-id`
   and `azure.workload.identity/tenant-id`.
2. A Pod using that ServiceAccount (and labeled `azure.workload.identity/use: "true"`)
   gets a projected, short-lived, auto-rotated Kubernetes service account token mounted
   into it by the AKS workload identity webhook.
3. At runtime, the app's `DefaultAzureCredential` (or any Azure SDK credential chain)
   exchanges that projected token for an Entra access token via a **federated identity
   credential** — a trust relationship configured on the managed identity that says
   "trust OIDC tokens issued by cluster X's issuer, for subject
   `system:serviceaccount:<namespace>:<serviceaccount>`."
4. The resulting Entra token is scoped to whatever the managed identity is authorized
   to do — in this solution, that's exactly one thing: read/write blobs in the shared
   storage account.

## Managed identity: role assignment and its limitations

| Aspect | Detail |
|---|---|
| **Role granted** | `Storage Blob Data Contributor`, scoped to the shared storage account only. |
| **What it allows** | Read/write/list blobs in that storage account (both export and merge jobs need read+write: export only writes, merge reads everything and writes the result). |
| **What it explicitly does NOT allow** | Any control-plane operations (can't create/delete the storage account, can't modify its network rules or lifecycle policy), any access to other storage accounts, any Azure Resource Manager operations, any Kubernetes API access. |
| **Federated credential quota** | **Default limit: 20 federated identity credentials per managed identity.** Since each participating cluster (and each operation mode on that cluster) needs its own federated credential, this becomes a real constraint above ~20 clusters. Options: request a quota increase from Azure support (do this early — it isn't instant), or shard clusters across multiple managed identities (`identity_count` in `modules/shared`, `identity_shard_index` per cluster in `modules/workload`). |
| **Subject specificity** | Each federated credential's `subject` is exact-match on `namespace:serviceaccount` — it is **not** a wildcard. A compromised pod in a different namespace/ServiceAccount on the same cluster cannot obtain a token for this identity, even with the cluster's correct OIDC issuer. |
| **No secrets to rotate** | Because there's no static credential, there's nothing to rotate, leak, or accidentally commit. The only "credential" is the federated trust relationship itself, which is scoped and auditable in Entra ID. |
| **Blast radius if compromised** | A compromised export/merge pod can read and write blobs in the shared storage account only — it cannot read Cost Management data via the ARM API (that export already lands in blob storage, so no separate ARM permission is needed at runtime), cannot escalate to other Azure resources, and cannot access other clusters' Kubernetes API. |

## AKS RBAC requirements

The solution needs **no Azure RBAC on the AKS cluster resource itself** — it only
needs standard **Kubernetes RBAC** within the cluster, which the manifests/Terraform
already handle:

| Kubernetes RBAC need | Why |
|---|---|
| Create/manage objects in one namespace (`cost-analysis` by default) | Namespace, ServiceAccount, CronJob, and the Jobs/Pods it spawns all live here. No cluster-wide RBAC is required for the *workload itself* at runtime — the container process has no Kubernetes API access at all (it never calls `kubectl` or the K8s API; it only calls the Cost Analysis agent over HTTP and Azure Blob Storage). |
| Create a Service in `kube-system` | Only required once per cluster, to expose the Cost Analysis add-on's agent pod (see [Azure resources](02-azure-resources.md)). This is a deploy-time/Terraform-apply-time RBAC need for whoever/whatever runs `terraform apply` — not a runtime need for the running Pod. |
| No ClusterRole/ClusterRoleBinding needed | The Pod itself doesn't call the Kubernetes API server — it's a pure HTTP client (to the agent) and Azure SDK client (to Blob Storage). No `ServiceAccount` token for the K8s API is used beyond what's needed for the workload identity webhook to project the Azure AD token. |

### Who needs cluster-admin-level access (deploy-time only)

Whoever runs `terraform apply` for `envs/cluster`/`envs/merge` (a human via `az aks
get-credentials`, or a CI/CD pipeline's service principal/managed identity) needs:
- `az aks get-credentials` — needs `Azure Kubernetes Service Cluster User Role` (or
  equivalent) at the cluster's ARM scope, or local admin credentials if
  `--admin` / local accounts are used.
- Enough in-cluster Kubernetes RBAC to create Namespaces, ServiceAccounts, and CronJobs
  in the target namespace, and a Service in `kube-system` (this typically means
  cluster-admin for a CI identity, or a scoped ClusterRole if you want to avoid full
  admin — see best practice below).

**Best practice**: for a CI/CD-driven rollout across many clusters, create a dedicated,
narrowly-scoped ClusterRole/ClusterRoleBinding for the deployment identity instead of
using full cluster-admin — it only needs permissions on `namespaces`,
`serviceaccounts`, `cronjobs.batch`, and `services` (the last only in `kube-system`,
and only `create`/`get` on the specific `cost-analysis-agent-svc` name if you want to
scope it that tightly).

## Storage account: who else needs access

Data engineers/analysts who need to *read* `result.csv` (but aren't running the
workload) should be granted **`Storage Blob Data Reader`** at the storage account or
container scope — not more. Don't grant `Storage Blob Data Contributor`/`Owner` to
human users unless they specifically need to write/delete blobs.

Note from testing this solution: your own Azure AD user is very likely **not**
automatically granted any data-plane role on the storage account just because you
created it via Terraform/CLI — `az storage blob list --auth-mode login` will fail with
a permissions error unless you explicitly grant yourself a Storage Blob Data role (or
fall back to `--auth-mode key` with the account key for one-off diagnostics).
