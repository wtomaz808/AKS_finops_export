# Day-2 operations and troubleshooting

## How it runs, day to day

Once deployed, the solution is entirely schedule-driven — there's no long-running
service, no ingress, nothing to keep "up." Each day:

1. Every participating cluster's `export` CronJob fires (default `10 0 * * *`, i.e.
   00:10 UTC), runs for well under a minute, uploads that cluster's CSV, and exits.
2. Azure Cost Management's own daily export runs on its own schedule (configured at
   export-creation time), landing a fresh CSV(.gz) under `cost-management/` in blob
   storage — this is entirely managed by Azure, not by this solution.
3. The centralized `merge` CronJob fires after the exports (default `30 0 * * *`),
   reads everything, joins it, and overwrites `cost-analysis/result.csv`.
4. Downstream consumers (Power BI, a scheduled data pipeline, manual download) pick up
   the refreshed `result.csv` on whatever cadence they need.

There is no persistent compute cost between runs — CronJobs only consume cluster
resources while a Job is actually executing.

## Monitoring what matters

| What to watch | How |
|---|---|
| CronJob run history | `kubectl get jobs -n cost-analysis` on each cluster — look for `Complete` vs. accumulating `Failed` Jobs. |
| Job logs | `kubectl logs -n cost-analysis -l job-name=<job-name>` — the app logs structured `slog` output; a healthy run always ends with `data processing completed successfully`. |
| `result.csv` freshness | Check the blob's `Last Modified` timestamp — if it's stale by more than one day, something in the merge chain broke silently. |
| Cost Management export health | `az rest --method GET .../providers/Microsoft.CostManagement/exports/<name>/runHistory?api-version=...` — confirm the most recent run's `status` is `Completed`, not stuck in `InProgress` or showing `Failed`. |
| Federated credential count | `az identity federated-credential list --identity-name <identity> --resource-group <rg>` per shared identity — track against the 20-per-identity default quota as you onboard more clusters. |

**Recommended for a real fleet**: forward CronJob/Job failure events to Log
Analytics/Container Insights (if enabled on the clusters) and alert on: any `Failed`
Job, or an absence of a `Complete` Job within the expected daily window. This solution
doesn't include built-in alerting — it's intentionally self-hosted/self-supported, so
wire this into whatever the customer already uses for cluster observability.

## Routine (day-2) maintenance tasks

- **Image updates**: rebuild (`az acr build`) and update the `image` variable in
  each cluster's `terraform.tfvars`, then `terraform apply`. The CronJob spec updates
  in place — no need to delete/recreate anything. Validate with a manual test Job
  (see [Deployment guide](06-deployment-guide.md)) after every image change.
- **Onboarding a new cluster**: repeat the per-cluster deployment steps. Nothing on the
  merge side or shared infrastructure needs to change — the merge job already scans
  the shared root prefix and will pick up the new cluster's data automatically once its
  export job runs.
- **Decommissioning a cluster**: `terraform destroy` that cluster's `envs/cluster`
  state (removes its federated credential, ServiceAccount, namespace resources, and
  CronJob), and separately delete its old data under `cost-analysis/<cluster>/` in
  blob storage if it should no longer appear in `result.csv` (the merge job has no
  automatic pruning — stale clusters' last-known data will keep appearing in the join
  until their raw files are removed or age out via the storage lifecycle policy).
- **Storage lifecycle policy**: default retention for raw per-cluster exports and raw
  Cost Management files is 30 days — adjust `raw_export_retention_days` in
  `modules/shared` if the customer needs longer raw-data retention for audit purposes.
  `result.csv` itself is never auto-expired.
- **Federated credential quota approaching**: if nearing 20 credentials on a shared
  identity, either request an Azure support quota increase (start this well before
  it's actually needed) or provision an additional shared identity
  (`identity_count` in `modules/shared`) and start pointing new clusters at the new
  shard via `identity_shard_index`.

## Troubleshooting playbook

### Export job fails, log shows an HTTP error calling the agent
- **Symptom**: `failed to reach cost analysis service` or a non-200 status in the logs.
- **Check**: does `kube-system/cost-analysis-agent-svc` exist and does its selector
  match a running `cost-analysis-agent` pod?
  ```powershell
  kubectl get svc -n kube-system cost-analysis-agent-svc
  kubectl get pods -n kube-system -l app=cost-analysis-agent
  ```
  If the Service is missing, the Cost Analysis add-on's agent pod exists but nothing
  exposes it — this Service is created by this solution's own manifests/Terraform, not
  by the add-on itself (a known gap in the add-on). Re-apply `envs/cluster` (or
  `kube.yaml`) for that cluster.
- If the add-on itself isn't enabled or the pod isn't running at all: confirm
  `az aks show --query metricsProfile.costAnalysis.enabled` is `true`, and check the
  cluster's pricing tier is Standard/Premium.

### Export/merge job fails to authenticate to storage
- **Symptom**: an `azidentity`/credential error, or a 403 from Blob Storage.
- **Check**: does the Pod's ServiceAccount have the correct
  `azure.workload.identity/client-id`/`tenant-id` annotations, and is the Pod labeled
  `azure.workload.identity/use: "true"`? Does the federated identity credential's
  `subject` exactly match `system:serviceaccount:<namespace>:<serviceaccount>` for that
  Pod? Federated credential propagation in Entra ID can take a couple of minutes after
  creation — if you just applied Terraform, wait briefly and retry before assuming
  something is misconfigured.
- **Check**: has the role assignment (`Storage Blob Data Contributor`) actually
  propagated? RBAC propagation in Azure can lag by up to a few minutes after creation.

### Merge job finds zero AKS export files
- **Symptom**: `no AKS export files found` in the logs.
- **Check**: is `AZURE_STORAGE_AKS_DATA_PREFIX` on the merge job set to the shared
  root (`cost-analysis/`), not a single cluster's subfolder? Confirm at least one
  export job has actually run and successfully uploaded a file
  (`az storage blob list --prefix cost-analysis/`).

### Merge job finds zero Cost Management files
- **Symptom**: `no cost management files found to process`.
- **Most common cause**: the Cost Management export hasn't executed yet — a brand-new
  export's first scheduled run can be a day or more away. Force an on-demand run (see
  [Deployment guide](06-deployment-guide.md) Step 4.3) rather than waiting.
- **Other cause**: `Microsoft.CostManagementExports` resource provider not registered
  on the subscription — the export itself would have failed to create in the first
  place (`RP Not Registered` error), so check that the export resource exists at all.

### Merge job's join query fails with "no resource ID column found"
- **Cause**: the `cost_management` table has no rows — direct symptom of the above
  (no Cost Management data has landed yet). Resolve the underlying cause first; this
  error is downstream of an empty import, not a bug in the join itself.

### `terraform apply` fails creating the Cost Management export (`azapi_resource`)
- **`RP Not Registered` (400)**: register `Microsoft.CostManagementExports` (see
  Deployment guide prerequisites) and retry.
- **Schema validation error mentioning `displayName` or missing `timeframe`**: the
  `azapi` provider validates the request body strictly — `definition.timeframe` is
  required (e.g. `"MonthToDate"`) and `displayName` is not a valid property at all for
  this resource type (unlike the raw ARM REST call in the original `deploy.sh`, which
  isn't schema-validated and silently ignores extra fields).
- **A 401 from `consumption.azure.us` immediately after a successful create, in Azure
  Government specifically**: this is a known quirk — the `azapi` provider's post-create
  polling call goes to a different host than the create call, and that host rejects the
  token audience in Gov cloud. The resource was very likely created successfully
  despite the error. Verify directly:
  ```powershell
  az rest --method GET --uri "https://management.usgovcloudapi.net/subscriptions/<sub-id>/providers/Microsoft.CostManagement/exports/<name>?api-version=2023-07-01-preview"
  ```
  If it exists, reconcile Terraform state rather than retrying the apply:
  ```powershell
  terraform import module.shared.azapi_resource.cost_export "<resource-id>?api-version=2023-07-01-preview"
  terraform untaint module.shared.azapi_resource.cost_export
  ```

### `terraform apply` fails on `envs/cluster` or `envs/merge` with a Kubernetes "already exists" error
- **Cause**: two independent Terraform states (e.g. an export job's `envs/cluster` and
  the merge job's `envs/merge`) are targeting the **same physical cluster**, and both
  are trying to manage the same namespace or a same-named resource. Set
  `manage_namespace = false` (`hub_shares_cluster_with_export = true` in `envs/merge`)
  when the merge hub is also an export cluster, and confirm the federated
  credential/ServiceAccount naming is mode-aware (it is by default in this module —
  see [Terraform modules](05-terraform-modules.md)).

### Nothing obviously wrong, but `result.csv` looks incomplete or stale
- Confirm every expected cluster actually has a recent file under
  `cost-analysis/<cluster>/export-<date>.csv` — a cluster whose export job has been
  silently failing (e.g. tier downgraded, add-on disabled, image pull failure) won't
  raise an error in the merge job; it just won't contribute data, and the merge job
  has no way to know a cluster is "missing."
- Check the merge job's own last run status and logs — a failed merge run simply
  leaves the previous `result.csv` in place (there's no partial/corrupt overwrite,
  since the upload only happens after a successful in-memory join), which can look
  like "stale but not obviously broken" data if not checked directly.
