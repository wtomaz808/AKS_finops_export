# Exported data next steps

This guide describes how to hand `cost-analysis/result.csv` to a FinOps operator,
prepare it for Power BI, validate the reported costs, and decide what must change before
using the solution as a production reporting source.

For the Blob folder structure and source-file schemas, see
[Blob storage and reporting](08-blob-storage-and-reporting.md). For routine operations
and download commands, see
[Operations and troubleshooting](07-operations-and-troubleshooting.md).

## Handoff artifact

The primary reporting artifact is:

```text
<storage-account>/cost-exports/cost-analysis/result.csv
```

The centralized merge CronJob rewrites this file after it imports:

- Every `cost-analysis/<cluster>/export-<date>.csv` allocation file
- Every `.csv` or `.csv.gz` billing file below `cost-management/`

`result.csv` is a row-level dataset. Cluster totals and row counts aren't stored as
separate summary records. Reporting tools calculate them by filtering and aggregating
the rows.

## Validated two-cluster baseline

A validation run in the previous (proof-of-concept) environment generated data for
September 29, 2026:

| Cluster | Raw allocation rows | Merged billing rows | Sum of `costInUsd` |
|---|---:|---:|---:|
| `<cluster-a>` | 99 | 123 | USD 135.17 |
| `<cluster-b>` | 2 | 11 | USD 179.89 |

The raw row counts come from the cluster-specific `export-2026-09-29.csv` files. The
merged row counts and costs come from this equivalent query over `result.csv`:

```powershell
$rows = Import-Csv .\result.csv
$rows |
  Where-Object date -eq "2026-09-29" |
  Group-Object ClusterName |
  ForEach-Object {
    [pscustomobject]@{
      ClusterName = $_.Name
      Rows        = $_.Count
      CostInUSD   = ($_.Group | Measure-Object costInUsd -Sum).Sum
    }
  }
```

`<cluster-b>` had 2 `idle` rows and 9 `__unallocated__` rows. Confirm that result
matches the cluster's workload activity. A busy cluster with almost no workload
allocation needs investigation before its data is used for chargeback.

## Power BI connection

Grant the Power BI identity **Storage Blob Data Reader** on the storage account or
container. Prefer a managed identity or service principal. Don't distribute storage
account keys or embed them in a Power BI file.

Connect Power BI to Azure Blob Storage and select
`cost-analysis/result.csv`. Configure the refresh to run after the merge CronJob and
after the Cost Management export reports `Completed`.

Set these important column types explicitly:

| Column | Power BI type |
|---|---|
| `date` | Date |
| `Fraction` | Decimal number |
| `quantity` | Decimal number |
| `costInUsd` | Fixed decimal number |
| `costInBillingCurrency` | Fixed decimal number |
| `ClusterName` | Text |
| `SplitBucket` | Text |
| `SplitKey` | Text or parsed JSON record |

Parse `SplitKey` as JSON to expose Kubernetes dimensions such as namespace, object
kind, and object name. Keep `ResourceId`, `resourceGroupName`, subscription, meter,
pricing, currency, and tags as Azure billing dimensions.

## Suggested Power BI model

Create dimensions for:

- Date
- Cluster
- Subscription and resource group
- Namespace and workload from `SplitKey`
- Meter category and subcategory
- Allocation bucket
- Azure tags

Start with these measures:

```dax
Total Cost USD = SUM('AKS Cost'[costInUsd])

Idle Cost USD =
CALCULATE([Total Cost USD], 'AKS Cost'[SplitBucket] = "idle")

Unallocated Cost USD =
CALCULATE([Total Cost USD], 'AKS Cost'[SplitBucket] = "__unallocated__")

Idle Percentage = DIVIDE([Idle Cost USD], [Total Cost USD])

Unallocated Percentage = DIVIDE([Unallocated Cost USD], [Total Cost USD])
```

Useful first reports include cost by cluster and day, namespace and workload cost,
idle and unallocated trends, meter-category breakdown, month-over-month growth, and
missing cluster exports.

## Understand allocation values

| Value | Meaning |
|---|---|
| `usage` | Cost attributed to workload consumption |
| `system` | Cost attributed to Kubernetes or cluster system workloads |
| `idle` | Provisioned capacity the agent didn't attribute to active usage |
| `__unallocated__` | A billed resource in the cluster resource group had no exact split match |
| `__unknown__` | The source allocation file didn't identify a cluster, usually because it predates the `ClusterName` column |

Don't discard `idle` or `__unallocated__` rows. Doing so understates the cluster's
actual Azure cost. FinOps must instead define how those costs are allocated: retain
them at cluster level, distribute them proportionally, or assign them to a shared-cost
center.

## Data quality checks

Run these checks before each reporting refresh:

1. Confirm one current raw export exists for every expected cluster.
2. Confirm the Cost Management export completed for the same date.
3. Confirm `result.csv` has a recent last-modified timestamp.
4. Group by `ClusterName` and verify that no expected cluster is missing.
5. Alert on new `__unknown__` rows.
6. Track idle and unallocated percentages against agreed thresholds.
7. Reconcile daily `costInUsd` totals with Azure Cost Management for each AKS node
   resource group.
8. Confirm split fractions total approximately `1` per resource and date.
9. Detect duplicate billing records from overlapping Cost Management export runs.

A cluster export can fail without causing the centralized merge to fail. Monitor
per-cluster file freshness, not only the merge Job status.

## Production decisions

### Historical retention

The merge reconstructs and overwrites `result.csv` from the raw files currently in
Blob Storage. If raw files expire after 30 days, older rows disappear from the next
`result.csv`.

Choose one retention strategy before production:

- Retain raw files for the required reporting period
- Store dated snapshots of each merged result
- Configure Power BI incremental refresh to preserve imported history
- Move historical data into a lakehouse or warehouse

### Duplicate Cost Management data

The merge imports every `.csv` and `.csv.gz` file below `cost-management/`. A manually
rerun export can create another run folder containing an overlapping billing period.
Without deduplication, both files contribute rows and overstate cost. Remove superseded
runs or add a deterministic deduplication step before production chargeback.

### Refresh coordination

A fixed merge schedule doesn't guarantee that every cluster export and Cost Management
export finished first. Production orchestration should check source freshness before
starting the merge and should withhold publication when required sources are missing.

### Scale beyond a single CSV

A single CSV is appropriate for a proof of concept and small deployments. At 50 or
more clusters, full-file refreshes become slower and more expensive. Plan to move to
date- and cluster-partitioned Parquet in Azure Data Lake Storage, Microsoft Fabric, or
another analytics store when refresh time or file size becomes a concern.

### Fleet configuration

Use a shared Helm chart, Kustomize base, or GitOps policy for per-cluster exporters.
Pin every export and merge CronJob to the same tested image digest. Track federated
credential quotas, ABAC assignments, CronJob health, and configuration drift in the
cluster inventory.

## FinOps acceptance checklist

- [ ] Power BI uses Microsoft Entra authentication and read-only Blob access.
- [ ] The billing scope covers every subscription containing an onboarded cluster.
- [ ] All expected clusters appear in `result.csv` each day.
- [ ] Daily cluster totals reconcile with Azure Cost Management.
- [ ] Idle, system, usage, and unallocated cost policies are documented.
- [ ] Duplicate Cost Management runs can't double-count charges.
- [ ] Historical retention meets finance and audit requirements.
- [ ] Refresh failures and stale cluster exports generate alerts.
- [ ] The Power BI semantic model documents every calculated measure.
- [ ] A migration threshold from CSV to partitioned analytics storage is defined.