# AKS commands per cluster

Run these on the VDI that has kubectl access to the private clusters. Each block is
self-contained: connect, confirm the context, apply the cluster's own manifest, run a
one-time export, and read the logs.

Before you start:

```powershell
cd C:\dsop\aks_export\AKS_finops_export
git pull origin cx_usecase
az login --scope https://management.core.usgovcloudapi.net//.default
```

Every block sets `$cluster` and stops if the kubectl context doesn't match it. This
prevents applying one cluster's manifest to another cluster. The context name that
`az aks get-credentials` creates is the cluster name.

Use a new job name each run (`export-2`, `export-3`, and so on), because job names can't
be reused. Delete the old job first if you want to reuse a name:
`kubectl delete job export-1 -n cost-analysis --ignore-not-found`.

If a pod stays `Pending`, run `kubectl describe pod -n cost-analysis <pod>` and check the
events. If `az aks get-credentials` fails, see
[Troubleshooting](#troubleshooting).

## Atlas clusters: re-run the export now

Copy and paste one block at a time on the kubectl VDI, from the repo root
(`C:\dsop\aks_export\AKS_finops_export`) after `git pull origin cx_usecase`. Each block
re-applies the cluster's own manifest (lower CPU request), deletes the earlier test jobs,
runs a new job, and prints the log. A good log ends with `data processing completed
successfully` and a `path=cost-analysis/<cluster>/export-<date>.csv` line that names the
same cluster you are working on.

### aks-atlas-dev-usgovva-analysis

```powershell
$cluster = "aks-atlas-dev-usgovva-analysis"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-analysis -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 export-2 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl wait --for=condition=complete job/export-2 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-2
```

### aks-atlas-dev-usgovva-devops

```powershell
$cluster = "aks-atlas-dev-usgovva-devops"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-devops -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 export-2 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl wait --for=condition=complete job/export-2 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-2
```

### aks-atlas-dev-usgovva-devtest

```powershell
$cluster = "aks-atlas-dev-usgovva-devtest"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-devtest -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 export-2 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl wait --for=condition=complete job/export-2 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-2
```

### aks-atlas-dev-usgovva-ida

```powershell
$cluster = "aks-atlas-dev-usgovva-ida"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-ida -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 export-2 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl wait --for=condition=complete job/export-2 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-2
```

If `kubectl wait` times out, run `kubectl get pods -n cost-analysis` and
`kubectl describe pod -n cost-analysis <pod>`, then send me the events.

## Atlas clusters: first export (batch 2)

These six clusters are new to the export. Run one block at a time, from the repo root
after `git pull origin cx_usecase`. Each block checks the Cost Analysis agent pod, applies
the cluster's manifest, runs the first job (`export-1`), and prints the log.

Before the log, confirm the agent pod is `Running`. If it's missing, stop and tell me.

### aks-atlas-dev-usgovva-ingest

```powershell
$cluster = "aks-atlas-dev-usgovva-ingest"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-ingest -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

### aks-atlas-dev-usgovva-integration

```powershell
$cluster = "aks-atlas-dev-usgovva-integration"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-integration -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

### aks-atlas-dev-usgovva-play

```powershell
$cluster = "aks-atlas-dev-usgovva-play"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-play -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

### aks-atlas-dev-usgovva-play-unstable

```powershell
$cluster = "aks-atlas-dev-usgovva-play-unstable"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-play-unstable -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

### aks-atlas-dev-usgovva-test

```powershell
$cluster = "aks-atlas-dev-usgovva-test"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-test -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

### aks-atlas-dev-usgovva-vtest

```powershell
$cluster = "aks-atlas-dev-usgovva-vtest"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-vtest -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

A good log ends with `data processing completed successfully` and a
`path=cost-analysis/<cluster>/export-<date>.csv` line that names the same cluster.

## Data Services clusters: first export (batch 3)

This batch contains five export-only clusters in the `km-platform-dataservices`
subscription. The manifests use the existing shared UAMI
`cost-analysis-export-aks-paas-dev-usgovva-kites` UAMI and the existing storage account; do not create another
storage account, identity, or merge job.

### Process: one cluster at a time

Do not run a loop or paste the whole batch. Complete the Azure-side block for one
cluster, then move to that cluster's kube VDI block. Confirm the export succeeds before
starting the next cluster. The resource group is discovered by Azure CLI so it is not
assumed from the cluster name.

Run once on the Azure-capable environment before the first block:

```powershell
az cloud set --name AzureUSGovernment
az login --scope https://management.core.usgovcloudapi.net//.default
```

#### 1. aks-datasvc-dev-usgovva-argo — Azure side

```powershell
$cluster = "aks-datasvc-dev-usgovva-argo"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks show --subscription $subscription -g $rg -n $cluster --query "{tier:sku.tier,oidc:oidcIssuerProfile.enabled,oidcUrl:oidcIssuerProfile.issuerUrl,workloadIdentity:securityProfile.workloadIdentity.enabled,costAnalysis:metricsProfile.costAnalysis.enabled}" -o json
$issuer = az aks show --subscription $subscription -g $rg -n $cluster --query oidcIssuerProfile.issuerUrl -o tsv
az identity federated-credential create --subscription 7707fc25-6678-4ed5-81f4-2f17eae1f636 -g rg-kites-test-usgovva-001 --identity-name cost-analysis-export-aks-paas-dev-usgovva-kites --name "cost-analysis-$cluster-export" --issuer $issuer --subject system:serviceaccount:cost-analysis:cost-analysis-export-sa --audiences api://AzureADTokenExchange
```

#### 2. aks-datasvc-dev-usgovva-cyber — Azure side

```powershell
$cluster = "aks-datasvc-dev-usgovva-cyber"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks show --subscription $subscription -g $rg -n $cluster --query "{tier:sku.tier,oidc:oidcIssuerProfile.enabled,oidcUrl:oidcIssuerProfile.issuerUrl,workloadIdentity:securityProfile.workloadIdentity.enabled,costAnalysis:metricsProfile.costAnalysis.enabled}" -o json
$issuer = az aks show --subscription $subscription -g $rg -n $cluster --query oidcIssuerProfile.issuerUrl -o tsv
az identity federated-credential create --subscription 7707fc25-6678-4ed5-81f4-2f17eae1f636 -g rg-kites-test-usgovva-001 --identity-name cost-analysis-export-aks-paas-dev-usgovva-kites --name "cost-analysis-$cluster-export" --issuer $issuer --subject system:serviceaccount:cost-analysis:cost-analysis-export-sa --audiences api://AzureADTokenExchange
```

#### 3. aks-datasvc-dev-usgovva-observability — Azure side

```powershell
$cluster = "aks-datasvc-dev-usgovva-observability"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks show --subscription $subscription -g $rg -n $cluster --query "{tier:sku.tier,oidc:oidcIssuerProfile.enabled,oidcUrl:oidcIssuerProfile.issuerUrl,workloadIdentity:securityProfile.workloadIdentity.enabled,costAnalysis:metricsProfile.costAnalysis.enabled}" -o json
$issuer = az aks show --subscription $subscription -g $rg -n $cluster --query oidcIssuerProfile.issuerUrl -o tsv
az identity federated-credential create --subscription 7707fc25-6678-4ed5-81f4-2f17eae1f636 -g rg-kites-test-usgovva-001 --identity-name cost-analysis-export-aks-paas-dev-usgovva-kites --name "cost-analysis-$cluster-export" --issuer $issuer --subject system:serviceaccount:cost-analysis:cost-analysis-export-sa --audiences api://AzureADTokenExchange
```

#### 4. aks-datasvc-dev-usgovva-shared — Azure side

```powershell
$cluster = "aks-datasvc-dev-usgovva-shared"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks show --subscription $subscription -g $rg -n $cluster --query "{tier:sku.tier,oidc:oidcIssuerProfile.enabled,oidcUrl:oidcIssuerProfile.issuerUrl,workloadIdentity:securityProfile.workloadIdentity.enabled,costAnalysis:metricsProfile.costAnalysis.enabled}" -o json
$issuer = az aks show --subscription $subscription -g $rg -n $cluster --query oidcIssuerProfile.issuerUrl -o tsv
az identity federated-credential create --subscription 7707fc25-6678-4ed5-81f4-2f17eae1f636 -g rg-kites-test-usgovva-001 --identity-name cost-analysis-export-aks-paas-dev-usgovva-kites --name "cost-analysis-$cluster-export" --issuer $issuer --subject system:serviceaccount:cost-analysis:cost-analysis-export-sa --audiences api://AzureADTokenExchange
```

#### 5. aks-datasvc-sbx-usgovva-shared — Azure side

```powershell
$cluster = "aks-datasvc-sbx-usgovva-shared"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks show --subscription $subscription -g $rg -n $cluster --query "{tier:sku.tier,oidc:oidcIssuerProfile.enabled,oidcUrl:oidcIssuerProfile.issuerUrl,workloadIdentity:securityProfile.workloadIdentity.enabled,costAnalysis:metricsProfile.costAnalysis.enabled}" -o json
$issuer = az aks show --subscription $subscription -g $rg -n $cluster --query oidcIssuerProfile.issuerUrl -o tsv
az identity federated-credential create --subscription 7707fc25-6678-4ed5-81f4-2f17eae1f636 -g rg-kites-test-usgovva-001 --identity-name cost-analysis-export-aks-paas-dev-usgovva-kites --name "cost-analysis-$cluster-export" --issuer $issuer --subject system:serviceaccount:cost-analysis:cost-analysis-export-sa --audiences api://AzureADTokenExchange
```

If the federated credential already exists, stop that block and list it before
continuing. Do not create a second credential with a different name.

### Kube VDI commands — run one block at a time

On the kube VDI, run the setup once:

```powershell
cd C:\dsop\aks_export\AKS_finops_export
git pull origin cx_usecase
az cloud set --name AzureUSGovernment
az login --scope https://management.core.usgovcloudapi.net//.default
```

Then paste exactly one cluster block, wait for the successful log, and only then use
the next block. Each block has its own context check.

#### aks-datasvc-dev-usgovva-argo

```powershell
$cluster = "aks-datasvc-dev-usgovva-argo"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks get-credentials --subscription $subscription -g $rg -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

#### aks-datasvc-dev-usgovva-cyber

```powershell
$cluster = "aks-datasvc-dev-usgovva-cyber"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks get-credentials --subscription $subscription -g $rg -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

#### aks-datasvc-dev-usgovva-observability

```powershell
$cluster = "aks-datasvc-dev-usgovva-observability"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks get-credentials --subscription $subscription -g $rg -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

#### aks-datasvc-dev-usgovva-shared

```powershell
$cluster = "aks-datasvc-dev-usgovva-shared"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks get-credentials --subscription $subscription -g $rg -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

#### aks-datasvc-sbx-usgovva-shared

```powershell
$cluster = "aks-datasvc-sbx-usgovva-shared"; $subscription = "km-platform-dataservices"
$rg = az aks list --subscription $subscription --query "[?name=='$cluster'].resourceGroup | [0]" -o tsv
az aks get-credentials --subscription $subscription -g $rg -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

Use a new Job name such as `export-2` if `export-1` already exists; do not delete an
existing Job unless you are deliberately rerunning that cluster.

A successful run must end with `data processing completed successfully` and write to
`cost-analysis/<cluster>/export-<date>.csv`. The five manifests are:

- `clusters/aks-datasvc-dev-usgovva-argo/kube.yaml`
- `clusters/aks-datasvc-dev-usgovva-cyber/kube.yaml`
- `clusters/aks-datasvc-dev-usgovva-observability/kube.yaml`
- `clusters/aks-datasvc-dev-usgovva-shared/kube.yaml`
- `clusters/aks-datasvc-sbx-usgovva-shared/kube.yaml`

## IL5 team: development (one cluster at a time)

Only `aks-il5-team-dev-ugva-development` has completed Azure-side preparation in this
batch. Do **not** run a block for the other IL5/IL4 team clusters yet. Its dedicated
UAMI has a federated credential for `cost-analysis-export-sa` and Storage Blob Data
Contributor on the `aksexports` container. Confirm agent health and the target context
before deploying the manifest from the kube VDI.

First, on the kube VDI, update the repository and sign in:

```powershell
cd C:\dsop\aks_export\AKS_finops_export
git pull origin cx_usecase
az cloud set --name AzureUSGovernment
az login --scope https://management.core.usgovcloudapi.net//.default
```

Then copy and paste **this cluster's block only**, one command at a time as with the
earlier clusters. Check that the agent pod says `Running` before the `kubectl apply`
command; if it does not, **stop**. If any command fails, stop rather than continuing.

### aks-il5-team-dev-ugva-development

```powershell
$cluster = "aks-il5-team-dev-ugva-development"
az aks get-credentials --subscription 8f225e15-db94-4fa5-9f29-0669936b7b8a -g rg-il5-team-dev-ugva-aks-development -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }
kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl create job --from=cronjob/aks-cost-analysis-export export-1 -n cost-analysis
kubectl wait --for=condition=complete job/export-1 -n cost-analysis --timeout=300s
kubectl logs -n cost-analysis job/export-1
```

The log must show `data processing completed successfully` and a path under
`cost-analysis/aks-il5-team-dev-ugva-development/`. If the agent is missing, the
cluster cannot pull the image, or the job fails, stop; do not proceed to another
cluster. This workload has **not** been deployed from this workstation; the private
cluster requires the kube VDI.

## Cluster summary

| Cluster | Subscription | Resource group | Role |
|---|---|---|---|
| `aks-paas-dev-usgovva-kites` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-paas-dev-usgovva-aks-kites` | Hub: export and merge |
| `aks-kites-dev-usgovva-staging` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-staging` | Export only |
| `aks-atlas-dev-usgovva-analysis` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-analysis` | Export only |
| `aks-atlas-dev-usgovva-devops` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-devops` | Export only |
| `aks-atlas-dev-usgovva-devtest` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-devtest` | Export only |
| `aks-atlas-dev-usgovva-ida` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-ida` | Export only |
| `aks-atlas-dev-usgovva-ingest` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-ingest` | Export only |
| `aks-atlas-dev-usgovva-integration` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-integration` | Export only |
| `aks-atlas-dev-usgovva-play` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-play` | Export only |
| `aks-atlas-dev-usgovva-play-unstable` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-play-unstable` | Export only |
| `aks-atlas-dev-usgovva-test` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-test` | Export only |
| `aks-atlas-dev-usgovva-vtest` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-vtest` | Export only |
| `aks-datasvc-dev-usgovva-argo` | `km-platform-dataservices` | discovered by Azure CLI | Export only |
| `aks-datasvc-dev-usgovva-cyber` | `km-platform-dataservices` | discovered by Azure CLI | Export only |
| `aks-datasvc-dev-usgovva-observability` | `km-platform-dataservices` | discovered by Azure CLI | Export only |
| `aks-datasvc-dev-usgovva-shared` | `km-platform-dataservices` | discovered by Azure CLI | Export only |
| `aks-datasvc-sbx-usgovva-shared` | `km-platform-dataservices` | discovered by Azure CLI | Export only |

## aks-paas-dev-usgovva-kites (hub)

```powershell
$cluster = "aks-paas-dev-usgovva-kites"
az aks get-credentials --subscription 7707fc25-6678-4ed5-81f4-2f17eae1f636 -g rg-paas-dev-usgovva-aks-kites -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }

kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/merge.yaml

kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl logs -n cost-analysis job/export-2 -f

kubectl create job --from=cronjob/aks-cost-analysis-merge merge-5 -n cost-analysis
kubectl logs -n cost-analysis job/merge-5 -f
```

Notes:

- Merge runs only on the hub. The CronJob runs nightly at 00:30 UTC.
- Look for `keeping latest cost management file per folder` in the merge log.

## aks-kites-dev-usgovva-staging

```powershell
$cluster = "aks-kites-dev-usgovva-staging"
az aks get-credentials --subscription 7707fc25-6678-4ed5-81f4-2f17eae1f636 -g rg-kites-dev-usgovva-aks-staging -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }

kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml

kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl logs -n cost-analysis job/export-2 -f
```

## aks-atlas-dev-usgovva-analysis

```powershell
$cluster = "aks-atlas-dev-usgovva-analysis"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-analysis -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }

kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml

kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl logs -n cost-analysis job/export-2 -f
```

## aks-atlas-dev-usgovva-devops

```powershell
$cluster = "aks-atlas-dev-usgovva-devops"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-devops -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }

kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml

kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl logs -n cost-analysis job/export-2 -f
```

## aks-atlas-dev-usgovva-devtest

```powershell
$cluster = "aks-atlas-dev-usgovva-devtest"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-devtest -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }

kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml

kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl logs -n cost-analysis job/export-2 -f
```

## aks-atlas-dev-usgovva-ida

```powershell
$cluster = "aks-atlas-dev-usgovva-ida"
az aks get-credentials --subscription c98c2229-d604-406d-9746-d163d5d6069a -g rg-atlas-dev-usgovva-aks-ida -n $cluster --overwrite-existing
if ((kubectl config current-context) -ne $cluster) { throw "Wrong kubectl context" }

kubectl get pods -n kube-system -l app=cost-analysis-agent
kubectl apply -f examples/cost-analysis-export/clusters/$cluster/kube.yaml

kubectl delete job export-1 -n cost-analysis --ignore-not-found
kubectl create job --from=cronjob/aks-cost-analysis-export export-2 -n cost-analysis
kubectl logs -n cost-analysis job/export-2 -f
```

## Verify the exports in storage

Run on a machine with Azure access to the storage account (not kubectl). The output
lists each cluster folder and the node resource groups its files contain:

```powershell
.\examples\cost-analysis-export\scripts\inspect-exports.ps1 -Prefix "cost-analysis/aks-atlas-dev-usgovva-devtest/"
```

Each file should reference only its own cluster's node resource group.

## Troubleshooting

- **Pod `Pending`, `Insufficient cpu`:** the manifest requests too much CPU for the
  node pool. The atlas manifests request `50m`. Re-apply the manifest, delete the stuck
  job, and create a new one.
- **`ImagePullBackOff`, 401 `insufficient_scope`:** the cluster's kubelet identity needs
  `Container Registry Repository Reader` on the registry. `AcrPull` alone isn't enough.
- **Pod fails with an authentication error:** check that the cluster's OIDC issuer has a
  federated credential on the shared managed identity, and that the service account is
  `cost-analysis-export-sa`.
- **No `cost-analysis-agent` pod:** the Cost Analysis add-on isn't running on the
  cluster. Stop and report it.
- **`az aks get-credentials` fails:** you need the `Azure Kubernetes Service Cluster
  User Role` on the cluster. As a fallback, run read-only commands through Azure
  without a network path to the cluster:
  `.\examples\cost-analysis-export\scripts\diagnose-cluster.ps1 -Cluster <name> -ResourceGroup <rg>`
