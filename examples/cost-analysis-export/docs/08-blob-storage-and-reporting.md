# Blob storage layout and reporting granularity

This document confirms the chosen data-flow approach (server-side merge — "Option 1"
from our earlier discussion), details the exact folder structure produced in Blob
Storage, and answers directly: **does this produce one report per cluster, or one
combined report for the whole fleet?**

## Decision: server-side pre-join (merge) is the approach

We're using the **merge** job as designed — the centralized job joins every cluster's
raw Kubernetes cost-attribution export against the Azure Cost Management billing
export and writes one pre-joined, dollar-denominated CSV. Downstream consumers (Power
BI, Excel, a data pipeline) get a single ready-to-use table and don't need to
understand or reimplement the join logic themselves.

## Blob container folder structure

Everything lives in one container (`cost-exports` by default) under two top-level
prefixes — this matches what you're seeing in the portal:

```
cost-exports/                                  (blob container)
├── cost-analysis/                             ← Kubernetes cost-attribution data (this solution's export job)
│   ├── result.csv                              ← THE combined, pre-joined output (see below)
│   ├── <cluster-1-name>/
│   │   ├── export-2026-08-30.csv
│   │   ├── export-2026-08-31.csv
│   │   └── export-<YYYY-MM-DD>.csv             (one file per day, per cluster)
│   ├── <cluster-2-name>/
│   │   └── export-<YYYY-MM-DD>.csv
│   └── <cluster-N-name>/
│       └── export-<YYYY-MM-DD>.csv
│
└── cost-management/                            ← Azure Cost Management's own export (not written by this solution)
    └── <export-name>/                          e.g. "aks-cost-export"
        └── <period-start>-<period-end>/         e.g. "20260801-20260831"
            └── <run-guid>/                      one folder per export execution (scheduled or on-demand)
                ├── manifest.json                metadata about the run (not consumed by this solution)
                └── part_0_0001.csv.gz            the actual billing data (gzip CSV; large exports may have multiple part_*.csv.gz files)
```

### `cost-analysis/<cluster>/export-<date>.csv` — raw per-cluster files

- Written by the **export** CronJob, once per cluster, once per day.
- **Never combined at this stage** — always one file per cluster per day. A 50-cluster
  fleet produces 50 separate files per day here.
- Columns: `Date, ClusterName, ID, Name, Kind, Fraction, SplitBucket, SplitKey`.
  - `ClusterName` — the cluster this file came from, set via the `CLUSTER_NAME` env
    var (from the Terraform `cluster_name` variable). Carried straight through to
    `result.csv` by the merge join — see below.
  - `ID` — the full Azure `ResourceId` of the underlying compute/storage/network
    resource (e.g. a VM, disk, or public IP) that cost is being attributed from.
  - `Name` / `Kind` — describe that underlying Azure resource (e.g. a disk name,
    `Kind: "storage"`), **not** the Kubernetes construct.
  - `Fraction` — the proportion of that resource's cost attributable to this split
    (0.0–1.0). No dollar amount — this is a weight, not a cost.
  - `SplitBucket` — `"idle"` (unused capacity) or `"usage"` (actually consumed).
  - `SplitKey` — a JSON blob carrying the actual **Kubernetes-level attribution**:
    typically `{"namespace": "...", "object_kind": "deployment|daemonset|...",
    "object_name": "..."}`. This is where namespace/workload-level granularity
    actually lives, not in a dedicated column.
- No lifecycle deletion applies to these until the retention window expires (default
  30 days — see [Azure resources](02-azure-resources.md)); they exist independently of
  whether `result.csv` has been (re)generated.

### `cost-management/**` — Azure's own export, not produced by this solution

- Written entirely by the Azure Cost Management export feature itself, on its own
  schedule — this solution only *reads* it.
- Nested by run: `<export-name>/<period-start>-<period-end>/<run-guid>/` — a new
  `<run-guid>` subfolder is created **every time the export runs**, whether scheduled
  or manually forced. Old run folders are not automatically cleaned up by Azure; rely
  on the storage lifecycle policy for retention.
- The actual data file(s) are `part_0_0001.csv.gz` (numbered/paginated for large
  exports) — standard Azure Cost Management usage-export columns (`ResourceId`,
  `meterCategory`, `costInBillingCurrency`, `tags`, etc.), no Kubernetes context at all.
- The merge job finds these purely by file suffix (`.csv`/`.csv.gz`) anywhere under the
  `cost-management/` prefix — the nested run-guid folder structure doesn't need any
  special handling.

### `cost-analysis/result.csv` — the final combined output

- Written by the **merge** job, which runs **once, centrally** — not once per cluster.
- **This is one single monolithic file covering the entire fleet.** Every run
  overwrites it completely (not appended) with the current join across every cluster's
  latest raw export files plus the latest Cost Management data found in storage.
- Columns: the full Cost Management schema (`resourceGroupName`, `meterCategory`,
  `costInUsd`, `tags`, etc. — see [testdata sample](../testdata/cost-management-export.csv)
  for the complete list) plus the Kubernetes-side columns
  (`ClusterName, Name, Kind, SplitBucket, Fraction, SplitKey`), with `quantity`/`cost*`
  columns **already multiplied by `Fraction`** — i.e. real, attributed dollar amounts,
  not raw Azure Cost Management totals.

## Direct answer: per-cluster or one monolithic report?

**Both raw layers are per-cluster; the final merged output is one monolithic,
fleet-wide file — not split per cluster.**

- Raw export files: always per-cluster, per-day (never merged with each other at that
  stage).
- `result.csv`: one single file combining **every** cluster's data together. Running
  merge doesn't produce 50 separate result files — it produces exactly one.

### Can you still get a per-cluster view from that one file?

**Yes — `result.csv` includes a dedicated `ClusterName` column.** The export job now
writes its own cluster name (`CLUSTER_NAME` env var, set from the Terraform
`cluster_name`/`hub_cluster_name` variable) as a literal column on every row it
exports, and the merge join carries it straight through — sourced from the `aks_rg` CTE
so it's attached even to `__unallocated__` rows (ones with no matching Kubernetes split
data), not just rows with an actual namespace/workload attribution. Rows whose cluster
couldn't be determined (e.g. very old export files written before this column existed)
fall back to `__unknown__` rather than breaking the join.

This means `result.csv` is simultaneously:
- **One monolithic, fleet-wide report** — the default view, nothing extra needed.
- **Filterable/sliceable per cluster** in Power BI/Excel — just filter or group by
  `ClusterName` — without needing to run merge separately per cluster or maintain
  separate output files per cluster.

**Backward compatibility**: raw export files written before this change (no
`ClusterName` column) still import fine — the import is header-driven per file, so
older files simply contribute `NULL` for that column, which the join's
`COALESCE(r.ClusterName, '__unknown__')` handles gracefully rather than erroring.

### Alternative if you specifically want separate physical files per cluster

Technically possible by running the merge job once per cluster (scoping
`AZURE_STORAGE_AKS_DATA_PREFIX` and `AZURE_STORAGE_RESULT_FILE` to that one cluster's
path each time) — but this isn't the recommended pattern at scale, since it
reintroduces the redundant-work problem the centralized merge pattern was designed to
avoid (each per-cluster merge run would re-download and re-import the entire Cost
Management export again). The `ClusterName` column above gets you the same per-cluster
breakdown from one efficient, centralized run instead.
