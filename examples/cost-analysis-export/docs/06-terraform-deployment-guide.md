# Deployment guide

This is a step-by-step guide to deploy the solution using the Terraform scaffold in
`terraform/`. It assumes a single cluster to start (extend to a fleet by repeating the
"per cluster" steps via a CI matrix — see [Terraform modules](05-terraform-modules.md)).

## Prerequisites

### Tools
- Azure CLI (`az`), logged in (`az login`) and pointed at the correct cloud
  (`az cloud set --name AzureUSGovernment` for Gov, otherwise the default `AzureCloud`).
- `kubectl`.
- Terraform >= 1.7.
- Docker (optional — only needed if you want to build images locally via `build.sh`;
  `az acr build` works with zero local Docker daemon and is the recommended fallback).

### Azure prerequisites
- An Azure subscription (or, for multi-subscription fleets, a management group) where
  you have permission to create resource groups, storage accounts, managed identities,
  role assignments, and Cost Management exports.
- The **`Microsoft.CostManagementExports`** resource provider registered on the target
  subscription:
  ```powershell
  az provider register --namespace Microsoft.CostManagementExports
  az provider show --namespace Microsoft.CostManagementExports --query registrationState
  ```
  Wait for `Registered` before proceeding — this can take a few minutes.
- An Azure Container Registry to host the application image (create one if you don't
  have one: `az acr create --name <name> --resource-group <rg> --sku Basic`).

### Per-cluster prerequisites
For every AKS cluster that will participate:
- **Pricing tier**: Standard or Premium (`az aks show --query sku.tier`). Upgrade if
  currently Free — this is a billing/change-management conversation with the customer.
- **OIDC issuer + Workload Identity enabled**:
  ```powershell
  az aks update --name <cluster> --resource-group <rg> `
    --enable-oidc-issuer --enable-workload-identity
  ```
- **Cost Analysis add-on enabled**:
  ```powershell
  az aks update --name <cluster> --resource-group <rg> --enable-cost-analysis
  ```
- **ACR attached** so kubelet can pull the image without imagePullSecrets:
  ```powershell
  az aks update --name <cluster> --resource-group <rg> --attach-acr <acr-name>
  ```

## Step 1 — Build and push the image

```powershell
az acr build --registry <acr-name> --image aks-cost-export:latest .
```
(run from the `examples/cost-analysis-export` directory). This builds in ACR Tasks
(cloud-side) — no local Docker daemon required.

## Step 2 — Deploy shared infrastructure (`envs/shared`)

1. Copy `envs/shared/terraform.tfvars` (create it) with at minimum:
   ```hcl
   azure_environment            = "usgovernment"   # or "public"
   location                     = "<region>"
   resource_group_name          = "<shared-rg-name>"
   storage_account_name         = "<globally-unique-name>"
   cost_management_export_scope = "/subscriptions/<sub-id>"
   # or, for multi-subscription fleets:
   # cost_management_export_scope = "/providers/Microsoft.Management/managementGroups/<mg-name>"
   identity_count                = 1   # increase if fleet size approaches the 20-per-identity quota
   ```
2. For a real (non-POC) rollout, configure a remote backend
   (`envs/shared/backend.hcl.example` → your own `backend.hcl`) so state is shared with
   CI. For a single-operator POC, the default local backend is fine.
3. ```powershell
   cd terraform/envs/shared
   terraform init                      # add -backend-config=backend.hcl if using a remote backend
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```
4. **If the Cost Management export creation reports success on the underlying API call
   but Terraform errors on a subsequent status check** (seen in Azure Government —
   see [Troubleshooting](07-operations-and-troubleshooting.md)), verify the resource
   actually exists via `az rest`, then `terraform import` and `terraform untaint` it
   rather than retrying the apply.

## Step 3 — Deploy the per-cluster export job (`envs/cluster`)

For each participating cluster:
1. Get its OIDC issuer URL:
   ```powershell
   az aks show --name <cluster> --resource-group <rg> --query oidcIssuerProfile.issuerUrl -o tsv
   ```
2. `az aks get-credentials --name <cluster> --resource-group <rg>` (so the `kubernetes`
   provider's `kube_context` resolves).
3. Create `terraform.tfvars` for this cluster:
   ```hcl
   azure_environment    = "usgovernment"
   cluster_name         = "<cluster>"
   oidc_issuer_url      = "<from step 1>"
   kube_context         = "<cluster>"
   image                = "<acr-login-server>/aks-cost-export:latest"
   identity_shard_index = 0   # which shared identity this cluster's federated credential registers against
   shared_state_path    = "../shared/terraform.tfstate"   # or configure the azurerm remote-state block for CI
   ```
4. ```powershell
   cd terraform/envs/cluster
   terraform init
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```
5. **Validate immediately** — don't wait for the daily schedule:
   ```powershell
   kubectl create job --from=cronjob/aks-cost-analysis-export test-export -n cost-analysis
   kubectl wait --for=condition=complete --timeout=120s job/test-export -n cost-analysis
   kubectl logs -n cost-analysis job/test-export
   kubectl delete job test-export -n cost-analysis
   ```
   A successful run logs `data processing completed successfully` and uploads
   `cost-analysis/<cluster>/export-<date>.csv`.

## Step 4 — Deploy the centralized merge job (`envs/merge`)

Pick a hub location — any cluster, or a dedicated lightweight one.
1. `terraform.tfvars`:
   ```hcl
   azure_environment    = "usgovernment"
   hub_cluster_name     = "<hub-cluster>"
   oidc_issuer_url      = "<hub cluster's OIDC issuer>"
   kube_context         = "<hub-cluster>"
   image                = "<acr-login-server>/aks-cost-export:latest"
   identity_shard_index = 0
   shared_state_path    = "../shared/terraform.tfstate"
   # Only if the hub cluster is ALSO one of the export clusters from Step 3:
   hub_shares_cluster_with_export = true
   ```
2. ```powershell
   cd terraform/envs/merge
   terraform init
   terraform plan -out=tfplan
   terraform apply "tfplan"
   ```
3. **The Cost Management export needs at least one completed run before merge has
   anything to join against.** A brand-new export's first scheduled run can be a day or
   more away. Force it now instead of waiting:
   ```powershell
   az rest --method POST --uri "https://<arm-endpoint>/subscriptions/<sub-id>/providers/Microsoft.CostManagement/exports/<export-name>/run?api-version=2023-07-01-preview"
   ```
   Poll until ready:
   ```powershell
   az rest --method GET --uri "https://<arm-endpoint>/subscriptions/<sub-id>/providers/Microsoft.CostManagement/exports/<export-name>/runHistory?api-version=2023-07-01-preview" --query "value[0].properties.status"
   ```
   Wait for `Completed` (goes `InProgress` → `DataReady` → `Completed`, typically 1-2
   minutes).
4. Validate the same way as Step 3, but check for `cost-analysis/result.csv`:
   ```powershell
   kubectl create job --from=cronjob/aks-cost-analysis-merge test-merge -n cost-analysis
   kubectl wait --for=condition=complete --timeout=120s job/test-merge -n cost-analysis
   kubectl logs -n cost-analysis job/test-merge
   kubectl delete job test-merge -n cost-analysis
   ```
   A successful run logs `wrote result rows count=N` and
   `joined data uploaded successfully blob_name=cost-analysis/result.csv`.

## Step 5 — Repeat Step 3 for every additional cluster

Nothing about Step 4 needs to be repeated — the merge job already reads from every
cluster's prefix under the shared root. Just repeat Step 3 (with a unique
`terraform.tfvars`, ideally driven by a CI matrix over `clusters.example.json`) for
each new cluster onboarded.

## Post-deployment checklist

- [ ] `kubectl get cronjobs -n cost-analysis` on every participating cluster shows the
      expected schedule and no `SUSPEND=True`.
- [ ] A manual test run succeeded on every cluster (Step 3.5) and on the merge job
      (Step 4.4).
- [ ] `cost-analysis/result.csv` exists in blob storage and its `Last Modified`
      timestamp is recent.
- [ ] The Cost Management export's `nextRunTimeEstimate` is in the future and its most
      recent `runHistory` entry shows `Completed`.
- [ ] Federated credential count on each shared identity is tracked against the
      20-per-identity default quota, with a plan for sharding/quota increase before
      it's reached.
