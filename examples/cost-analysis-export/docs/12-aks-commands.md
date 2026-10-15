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

## Cluster summary

| Cluster | Subscription | Resource group | Role |
|---|---|---|---|
| `aks-paas-dev-usgovva-kites` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-paas-dev-usgovva-aks-kites` | Hub: export and merge |
| `aks-kites-dev-usgovva-staging` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-staging` | Export only |
| `aks-atlas-dev-usgovva-analysis` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-analysis` | Export only |
| `aks-atlas-dev-usgovva-devops` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-devops` | Export only |
| `aks-atlas-dev-usgovva-devtest` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-devtest` | Export only |
| `aks-atlas-dev-usgovva-ida` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-ida` | Export only |

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
