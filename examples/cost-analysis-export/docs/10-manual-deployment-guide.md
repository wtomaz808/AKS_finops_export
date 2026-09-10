# Manual deployment guide (portal and CLI, no Terraform)

This guide deploys the same solution as the
[Terraform deployment guide](06-terraform-deployment-guide.md) using only the Azure
portal, Azure CLI, and `kubectl`. Use it when Terraform isn't available or approved in
the target environment, when you want to understand exactly what the Terraform modules
create, or for a quick single-cluster proof of concept.

Every step lists the portal path and the CLI equivalent. They're interchangeable — pick
one per step, not both.

> **Trade-off:** there's no state file, so onboarding cluster 2 through 50 means
> repeating part 3 by hand each time, and decommissioning is manual cleanup. That's fine
> for a POC or a handful of clusters. Use Terraform for a fleet.

## What you'll build

| Part | Scope | Creates |
|---|---|---|
| [Part 1](#part-1--shared-infrastructure) | Once per tenant | Resource group, storage account, container, lifecycle policy, managed identity, role assignment |
| [Part 2](#part-2--cost-management-export) | Once per billing scope | Resource provider registration, daily Cost Management export |
| [Part 3](#part-3--per-cluster-setup) | Once per cluster | Container image access, cluster features, federated credential, CronJob |
| [Part 4](#part-4--validate) | Once per cluster | Manual test run and data validation |

## Prerequisites

- Azure CLI, signed in and pointed at the right cloud:
  ```powershell
  az cloud set --name AzureUSGovernment   # omit for public cloud
  az login
  az account set --subscription <subscription-id>
  ```
- `kubectl`.
- An Azure Container Registry, or another registry the cluster can pull from.
- Permission to create resource groups, storage accounts, managed identities, **role
  assignments**, and Cost Management exports. Role assignments specifically require
  **Owner** or **User Access Administrator** — Contributor is not enough.
- Each participating AKS cluster on the **Standard** or **Premium** pricing tier. The
  Cost Analysis add-on isn't available on Free tier.

### Collect your cloud-specific values first

Several steps need endpoints that differ between clouds. Resolve them once:

```powershell
$SUB      = az account show --query id -o tsv
$TENANT   = az account show --query tenantId -o tsv
$ARM      = (az cloud show --query endpoints.resourceManager -o tsv).TrimEnd('/')
$SUFFIX   = az cloud show --query suffixes.storageEndpoint -o tsv    # core.usgovcloudapi.net in Gov
$CLOUDNM  = az cloud show --query name -o tsv
$SDKCLOUD = switch ($CLOUDNM) {
  "AzureUSGovernment" { "AzureGovernment" }
  "AzureChinaCloud"   { "AzureChina" }
  default             { "AzurePublic" }
}
```

`$SDKCLOUD` becomes the `AZURE_CLOUD` environment variable on the container, and
`$SUFFIX` builds the blob endpoint. Getting either wrong causes authentication failures
that look like permission problems.

---

## Part 1 — Shared infrastructure

### Step 1.1 — Create the resource group

**Portal:** Resource groups → **+ Create** → subscription, name, region.

```powershell
$RG  = "rg-aks-costanalysis-export"
$LOC = "usgovvirginia"
az group create -n $RG -l $LOC
```

### Step 1.2 — Create the storage account

**Portal:** Storage accounts → **+ Create**

| Field | Value |
|---|---|
| Resource group | your shared resource group |
| Name | globally unique, 3–24 lowercase alphanumeric characters |
| Region | same as the resource group |
| Performance | Standard |
| Redundancy | LRS (sufficient — the data is reproducible) |
| Security → Minimum TLS version | 1.2 |

```powershell
$SA = "stcostexportspoc"
az storage account create -n $SA -g $RG -l $LOC --sku Standard_LRS --min-tls-version TLS1_2
```

### Step 1.3 — Create the blob container

**Portal:** the storage account → **Data storage → Containers → + Container** → name
`cost-exports`, anonymous access **Private**.

```powershell
az storage container create -n cost-exports --account-name $SA --auth-mode login
```

Create this before part 2 — the Cost Management export validates that the container
exists.

### Step 1.4 — Add the lifecycle policy

Raw daily exports accumulate indefinitely otherwise. This matches the Terraform default
of 30 days.

**Portal:** the storage account → **Data management → Lifecycle management → + Add a
rule**. Create two rules:

| Field | Rule 1 | Rule 2 |
|---|---|---|
| Rule name | `expire-raw-aks-exports` | `expire-raw-cost-management-exports` |
| Rule scope | Limit blobs with filters | Limit blobs with filters |
| Blob type | Block blobs | Block blobs |
| Blob subtype | Base blobs | Base blobs |
| Delete the blob | 30 days after last modification | 30 days after last modification |
| Blob prefix | `cost-exports/cost-analysis/` | `cost-exports/cost-management/` |

The portal's prefix filter includes the container name.

`result.csv` also lives under `cost-analysis/`, but the daily merge rewrites it, so its
last-modified date keeps advancing and it never expires.

### Step 1.5 — Create the managed identity

**Portal:** Managed Identities → **+ Create**

| Field | Value |
|---|---|
| Resource group | your shared resource group |
| Region | same as the resource group |
| Name | `cost-analysis-identity-0` |
| Isolation scope | **None** (the default) |

This must be a **user-assigned** identity. A system-assigned identity can't be federated
to a Kubernetes service account.

The `-0` suffix is deliberate: each identity supports 20 federated credentials by
default, so a fleet larger than 20 clusters needs `cost-analysis-identity-1`, `-2`, and
so on. Leave isolation scope at **None** — **Regional** restricts the identity to
resources in its own region, which breaks a shared identity federated to clusters in
other regions.

```powershell
$IDENTITY = "cost-analysis-identity-0"
az identity create -n $IDENTITY -g $RG -l $LOC
```

Record two values from the identity's **Overview** blade — you'll need them for the
Kubernetes ServiceAccount annotations:

```powershell
$CLIENT_ID    = az identity show -n $IDENTITY -g $RG --query clientId -o tsv
$PRINCIPAL_ID = az identity show -n $IDENTITY -g $RG --query principalId -o tsv
```

### Step 1.6 — Grant the identity access to the storage account

**Portal:** the storage account → **Access control (IAM) → + Add → Add role assignment**

| Tab | Value |
|---|---|
| Role | `Storage Blob Data Contributor` |
| Assign access to | Managed identity |
| Members | User-assigned managed identity → `cost-analysis-identity-0` |
| Conditions | None |

```powershell
$SA_ID = az storage account show -n $SA -g $RG --query id -o tsv
az role assignment create --assignee-object-id $PRINCIPAL_ID `
  --assignee-principal-type ServicePrincipal `
  --role "Storage Blob Data Contributor" --scope $SA_ID
```

Two things matter here. The role must be `Storage Blob Data Contributor`, not
`Contributor` — the latter is control plane only and grants no data access. And the
scope must be the storage account; assigning from the storage account's own IAM blade
sets that correctly by default.

---

## Part 2 — Cost Management export

### Step 2.1 — Register the resource provider

**Portal:** Subscriptions → your subscription → **Settings → Resource providers** →
search `Microsoft.CostManagementExports` → **Register**.

```powershell
az provider register --namespace Microsoft.CostManagementExports
az provider show --namespace Microsoft.CostManagementExports --query registrationState -o tsv
```

Wait for `Registered` before continuing. Without it, export creation fails with
`RP Not Registered`.

### Step 2.2 — Create the export

**Portal:** search **Cost Management** (not "Cost Management + Billing") → set the
**Scope** selector at the top → **Reporting + analytics → Exports → + Create**.

| Field | Value |
|---|---|
| Scope | The subscription, or a **management group** if clusters span subscriptions |
| Template / type | Cost and usage (actual) |
| Export name | `aks-cost-export` |
| Frequency | Daily export of month-to-date costs |
| Granularity | Daily |
| Storage account | your shared storage account |
| Container | `cost-exports` |
| Directory | `cost-management` |
| Format | CSV |
| Compression | Gzip |
| Overwrite data | On |

The **Directory** value must be exactly `cost-management` — it has to match the
container's `AZURE_STORAGE_COST_EXPORT_PREFIX`.

CLI equivalent, using a body file `export.json`:

```json
{"properties":{
 "definition":{"type":"Usage","timeframe":"MonthToDate","dataSet":{"granularity":"Daily"}},
 "deliveryInfo":{"destination":{"resourceId":"<STORAGE_ACCOUNT_RESOURCE_ID>","container":"cost-exports","rootFolderPath":"cost-management"}},
 "schedule":{"status":"Active","recurrence":"Daily","recurrencePeriod":{"from":"2026-09-09T00:00:00Z","to":"2030-12-31T00:00:00Z"}},
 "format":"Csv","compressionMode":"gzip","dataOverwriteBehavior":"OverwritePreviousReport"}}
```

```powershell
az rest --method PUT `
  --uri "$ARM/subscriptions/$SUB/providers/Microsoft.CostManagement/exports/aks-cost-export?api-version=2023-07-01-preview" `
  --body '@export.json'
```

For management group scope, replace `subscriptions/$SUB` with
`providers/Microsoft.Management/managementGroups/<mg-id>`.

### Step 2.3 — Force the first run

A newly created daily export won't produce data for a day or more. The merge job has
nothing to join against until it does, so trigger it now.

**Portal:** select the export → **Run now**, then watch **Run history** until the status
is `Completed`.

```powershell
az rest --method POST `
  --uri "$ARM/subscriptions/$SUB/providers/Microsoft.CostManagement/exports/aks-cost-export/run?api-version=2023-07-01-preview"

az rest --method GET `
  --uri "$ARM/subscriptions/$SUB/providers/Microsoft.CostManagement/exports/aks-cost-export/runHistory?api-version=2023-07-01-preview" `
  --query "value[0].properties.status" -o tsv
```

Status progresses `InProgress` → `DataReady` → `Completed`, usually within a couple of
minutes.

---

## Part 3 — Per-cluster setup

Repeat this part for every participating cluster.

### Step 3.1 — Build and push the image

```powershell
cd examples/cost-analysis-export
az acr build --registry <acr-name> --image aks-cost-export:latest .
```

`az acr build` builds server-side in ACR Tasks, so no local Docker daemon is needed.
`build.sh` is the local-Docker alternative.

### Step 3.2 — Let the cluster pull from the registry

The cluster's **kubelet** identity needs `AcrPull` on the registry. The convenience
command is:

```powershell
az aks update -n <cluster> -g <cluster-rg> --attach-acr <acr-name>
```

If that fails to resolve the registry by name — commonly because the registry is in a
different subscription — pass the full resource ID instead. Find it in the portal at
**Container registries → your registry → Overview → JSON View**, top-level `id` field:

```powershell
$ACR_ID = az acr show -n <acr-name> -g <acr-rg> --query id -o tsv
az aks update -n <cluster> -g <cluster-rg> --attach-acr $ACR_ID
```

If it still fails, do the underlying role assignment yourself. First find the kubelet
identity. Don't go hunting for the node resource group — it may be custom-named or
hidden by RBAC. Read it from **your cluster → Overview → JSON View**, under
`identityProfile.kubeletidentity`:

```powershell
$KUBELET_ID = az aks show -n <cluster> -g <cluster-rg> `
  --query identityProfile.kubeletidentity.objectId -o tsv

az role assignment create --assignee-object-id $KUBELET_ID `
  --assignee-principal-type ServicePrincipal `
  --role AcrPull --scope $ACR_ID
```

**Portal equivalent:** the registry → **Access control (IAM) → + Add → Add role
assignment** → role `AcrPull` → Managed identity → the cluster's `<cluster>-agentpool`
identity. That's the kubelet identity, not `cost-analysis-identity-0`.

Variations to watch for:

| Cluster configuration | What you'll see in JSON View | What to assign `AcrPull` to |
|---|---|---|
| Managed identity (default) | `identityProfile.kubeletidentity` | That identity |
| Bring-your-own kubelet identity | `kubeletidentity.resourceId` outside the node resource group | That identity |
| Service principal | No `identityProfile`; `servicePrincipalProfile.clientId` is a GUID | That service principal, via **User, group, or service principal** |

For a **private registry** (public network access disabled), `AcrPull` alone isn't
enough — the nodes also need a network path via a private endpoint in or peered to the
cluster VNet, plus the matching `privatelink.azurecr.*` private DNS zone. Private
endpoints require the Premium ACR SKU.

### Step 3.3 — Enable the required cluster features

```powershell
az aks update -n <cluster> -g <cluster-rg> --enable-oidc-issuer --enable-workload-identity
az aks update -n <cluster> -g <cluster-rg> --enable-cost-analysis
```

Cost Analysis is also available in the portal at **your cluster → Monitoring → Cost
analysis → Enable cost analysis**. It requires Standard or Premium tier.

Confirm the add-on's agent is actually running before going further:

```powershell
kubectl get pods -n kube-system -l app=cost-analysis-agent
```

No pods means the add-on isn't enabled yet, and the export job will fail to reach it.

### Step 3.4 — Get the cluster's OIDC issuer URL

**Portal:** your cluster → **Overview → JSON View** → `oidcIssuerProfile.issuerURL`.

```powershell
az aks show -n <cluster> -g <cluster-rg> --query oidcIssuerProfile.issuerUrl -o tsv
```

The value looks like
`https://usgovvirginia.oic.prod-aks.azure.us/<tenant-guid>/<cluster-guid>/`. Use exactly
what the cluster reports, trailing slash included — never construct it by hand. If
`enabled` is `false` there's no URL yet; finish step 3.3 first.

This value is unique per cluster and changes if the cluster is rebuilt.

### Step 3.5 — Create the federated credential

**Portal:** Managed Identities → `cost-analysis-identity-0` → **Settings → Federated
credentials → + Add Credential**

| Field | Value |
|---|---|
| Federated credential scenario | Kubernetes accessing Azure resources |
| Cluster Issuer URL | from step 3.4 |
| Namespace | `cost-analysis` |
| Service Account | `cost-analysis-export-sa` |
| Name | `cost-analysis-<cluster>-export` |
| Subject identifier (read-only) | `system:serviceaccount:cost-analysis:cost-analysis-export-sa` |
| Audience | `api://AzureADTokenExchange` |

```powershell
az identity federated-credential create `
  --name "cost-analysis-<cluster>-export" `
  --identity-name $IDENTITY -g $RG `
  --issuer "<oidc-issuer-url>" `
  --subject "system:serviceaccount:cost-analysis:cost-analysis-export-sa" `
  --audience "api://AzureADTokenExchange"
```

The namespace and service account must match your applied manifest character for
character. A mismatch produces no error here — the pod just fails at runtime with
`AADSTS70021: No matching federated identity record found`.

If a cluster runs both an export job and the merge job, create **two** credentials with
distinct names and service accounts (`cost-analysis-export-sa` and
`cost-analysis-merge-sa`).

### Step 3.6 — Apply the workload manifest

```powershell
az aks get-credentials -n <cluster> -g <cluster-rg> --overwrite-existing
```

Substitute the placeholders in [`kube.yaml`](../kube.yaml):

```powershell
(Get-Content kube.yaml) `
  -replace 'image: .*', "image: <acr-login-server>/aks-cost-export:latest" `
  -replace 'PLACEHOLDER_CLIENT_ID', $CLIENT_ID `
  -replace 'PLACEHOLDER_TENANT_ID', $TENANT `
  -replace 'PLACEHOLDER_STORAGE_ACCOUNT', $SA `
  -replace 'PLACEHOLDER_STORAGE_SUFFIX', $SUFFIX `
  -replace 'PLACEHOLDER_AZURE_CLOUD', $SDKCLOUD `
  -replace 'PLACEHOLDER_CLUSTER_NAME', '<cluster>' `
  | Set-Content kube-deploy.yaml
```

Then review `kube-deploy.yaml` before applying. As shipped it's a single-cluster `both`
mode job using ServiceAccount `cost-analysis-sa`. For the separated pattern, align it
with the federated credential you created:

| Setting | Export job | Merge job (hub cluster) |
|---|---|---|
| Container `args` | `["export"]` | `["merge"]` |
| CronJob name | `aks-cost-analysis-export` | `aks-cost-analysis-merge` |
| ServiceAccount name | `cost-analysis-export-sa` | `cost-analysis-merge-sa` |
| `AZURE_STORAGE_AKS_DATA_PREFIX` | `cost-analysis/<cluster>/` | `cost-analysis/` |
| `schedule` | `10 0 * * *` | `30 0 * * *` |
| `cost-analysis-agent-svc` Service | keep | delete — merge never calls the agent |

Leave the `cost-analysis-agent-svc` Service in `kube-system`. The add-on deploys its
agent pod there and a Service can only select pods in its own namespace, so moving it
would leave it with zero endpoints. It also has to stay consistent with
`COST_ANALYSIS_URL`.

If export and merge both run on the same cluster, apply the `Namespace` and the
`kube-system` Service only once.

```powershell
kubectl apply -f kube-deploy.yaml
```

**Private clusters** have no public API server endpoint, so `kubectl` from a workstation
won't connect. Either work from a jump box in the VNet, or run commands through the
cluster:

```powershell
az aks command invoke -n <cluster> -g <cluster-rg> `
  --command "kubectl apply -f kube-deploy.yaml" --file kube-deploy.yaml
```

---

## Part 4 — Validate

Don't wait for the daily schedule.

```powershell
kubectl create job --from=cronjob/aks-cost-analysis-export manual-1 -n cost-analysis
kubectl get jobs,pods -n cost-analysis
kubectl logs -n cost-analysis -l job-name=manual-1 --tail=200
```

A healthy run ends with `data processing completed successfully`. A merge run also logs
`joined data uploaded successfully`.

If the pod is stuck in `Pending` or `ImagePullBackOff`, `kubectl describe pod -n
cost-analysis -l job-name=manual-1` shows why — that's where registry permission and
network path problems surface.

Then confirm the data landed:

```powershell
$KEY = az storage account keys list -n $SA -g $RG --query "[0].value" -o tsv
az storage blob list --account-name $SA --account-key $KEY -c cost-exports `
  --query "[].{name:name, size:properties.contentLength, modified:properties.lastModified}" -o table
```

Use `--auth-mode key`. Only the workload identity holds a data-plane role on the storage
account, so listing blobs as yourself returns 403 unless you also grant your own account
a Storage Blob Data role.

For the full validation ladder — file structure checks, fraction sanity, and reconciling
totals against the portal — see
[Operations and troubleshooting](07-operations-and-troubleshooting.md).

## Onboarding additional clusters

Repeat part 3 only. Parts 1 and 2 are shared and unchanged, and the merge job picks up
new clusters automatically once their export files appear. Track two things as the fleet
grows:

- Federated credentials per identity, against the default quota of 20.
- Whether the Cost Management export's scope still covers every subscription that hosts
  a cluster. Move to management group scope before it doesn't.

See [How data is collected across clusters](09-multi-cluster-data-collection.md) for why
no cross-cluster configuration is needed.
