# Cluster deployments

Each folder contains the export-only Kubernetes manifest for one AKS cluster.
`example-cluster/kube.yaml` is a template: copy the folder, rename it to the cluster
name, and replace every `<placeholder>` (identity client ID, tenant ID, image, cluster
name, and storage account name). The shared storage account, managed identity, Cost
Management export, and centralized merge job are not recreated when another cluster is
added. The container registry is provided by the AKS environment build.

Before applying a cluster manifest:

1. Enable the AKS Cost Analysis add-on, OIDC issuer, and Workload Identity.
2. Grant the cluster kubelet identity `Container Registry Repository Reader` on the
   ABAC-enabled registry, conditioned to the `aks-cost-export` repository.
3. Add one federated credential to the shared user-assigned managed identity. Its
   subject must be
   `system:serviceaccount:cost-analysis:cost-analysis-export-sa` and its issuer must
   be the target cluster's OIDC issuer.
4. Get credentials for the target cluster and verify the current kubectl context.
5. Apply `<cluster-name>/kube.yaml` and run a one-time Job from the CronJob.

Each cluster writes to its own prefix:

```text
cost-analysis/<cluster-name>/export-YYYY-MM-DD.csv
```

The one centralized merge CronJob reads the shared `cost-analysis/` prefix and picks
up new clusters automatically.