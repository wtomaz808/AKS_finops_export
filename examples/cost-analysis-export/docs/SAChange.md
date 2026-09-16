# Changing the storage account (manual)

Steps to switch the AKS Cost Analysis export/merge pipeline to a different storage
account and container, when both already exist and no historical blob data needs to be
migrated (e.g., moving off a POC storage account to the customer's actual one).

Replace anything in `customer_info_here` with the actual values before running.

This is a manual process — no Terraform or repo changes are required.

## 1. Grant the managed identity access to the new storage account

**Portal:** New storage account → **Access control (IAM)** → **+ Add** → **Add role
assignment** → Role: `Storage Blob Data Contributor` → Assign access to: **Managed
identity** → select `customer_info_here` (the existing identity, e.g.
`cost-analysis-identity-0`).

**CLI equivalent:**

```powershell
$PRINCIPAL_ID = az identity show -n customer_info_here_IDENTITY_NAME -g customer_info_here_RESOURCE_GROUP --query principalId -o tsv
$NEW_SA_ID    = az storage account show -n customer_info_here_NEW_STORAGE_ACCOUNT -g customer_info_here_NEW_SA_RESOURCE_GROUP --query id -o tsv

az role assignment create --assignee-object-id $PRINCIPAL_ID `
  --assignee-principal-type ServicePrincipal `
  --role "Storage Blob Data Contributor" --scope $NEW_SA_ID
```

## 2. Repoint the Cost Management export to the new storage account

**Portal:** Cost Management → **Exports** → select `customer_info_here_EXPORT_NAME` →
**Edit** → change **Storage account** to the new account and **Container** to the
existing container name → **Save**.

If the portal won't let you change the destination account in place, delete and
recreate the export pointing at the new account/container (same schedule/settings as
before).

**CLI equivalent** (re-PUT with new destination):

```powershell
az rest --method PUT `
  --uri "$ARM/subscriptions/customer_info_here_SUBSCRIPTION_ID/providers/Microsoft.CostManagement/exports/customer_info_here_EXPORT_NAME?api-version=2023-07-01-preview" `
  --body '@export.json'
```

Where `export.json`'s `deliveryInfo.destination.resourceId` is the new storage
account's resource ID and `container` is the existing container name.

## 3. Point the running CronJob(s) at the new storage account

For each cluster's CronJob (per cluster, in namespace `cost-analysis`):

```powershell
kubectl set env cronjob/customer_info_here_CRONJOB_NAME -n cost-analysis `
  AZURE_STORAGE_BLOB_NAME="https://customer_info_here_NEW_STORAGE_ACCOUNT.blob.customer_info_here_STORAGE_SUFFIX/"
```

- `customer_info_here_STORAGE_SUFFIX` is the cloud's blob suffix (e.g.
  `core.usgovcloudapi.net` for Gov, `core.windows.net` for public).
- If the container name is also different from `cost-exports`, also update:

```powershell
kubectl set env cronjob/customer_info_here_CRONJOB_NAME -n cost-analysis `
  AZURE_STORAGE_CONTAINER_NAME="customer_info_here_NEW_CONTAINER_NAME"
```

## 4. Verify

```powershell
kubectl create job --from=cronjob/customer_info_here_CRONJOB_NAME test-sa-switch -n cost-analysis
kubectl logs -n cost-analysis job/test-sa-switch -f
az storage blob list --account-name customer_info_here_NEW_STORAGE_ACCOUNT --auth-mode login -c customer_info_here_NEW_CONTAINER_NAME --output table
```

Confirm the export/merge output lands in the new account, then repeat step 3 for every
remaining cluster's CronJob.
