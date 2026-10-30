# Export/merge schedule, how the merge works, and current fleet coverage

This explains **when** data shows up for FinOps, **how** the daily merge actually
produces `result.csv`, and the current caveat around clusters not yet reporting.

## Schedule

| Job | CronJob name | Schedule (cron) | Runs on | Meaning |
|---|---|---|---|---|
| **Export** | `aks-cost-analysis-export` | `10 0 * * *` | Every implemented cluster, individually | Daily at **00:10 UTC** |
| **Merge** | `aks-cost-analysis-merge` | `30 0 * * *` | Hub cluster only (`aks-paas-dev-usgovva-kites`) | Daily at **00:30 UTC** |

No custom `timeZone` is set on either CronJob, so both run in the Kubernetes
controller's default — UTC. The 20-minute gap between export (`:10`) and merge
(`:30`) is intentional, per the comment in
[merge.yaml](../clusters/aks-paas-dev-usgovva-kites/merge.yaml#L27): the merge job
needs every cluster's raw export already uploaded before it reads them.

### What FinOps can expect, in practical terms

- **Daily, roughly 00:30–00:50 UTC**, `cost-analysis/result.csv` (the "latest"
  convenience copy) is refreshed with the prior day's joined data across every
  cluster currently reporting.
- For US-based consumers, 00:30 UTC lands in the **previous evening** US time
  (≈ 8:30 PM ET / 5:30 PM PT the day before) — so the report is ready well before
  the start of the US business day.
- Starting with image `1.3.0`, the merge job **also** writes a dated archive copy
  each run: `cost-analysis/archive/<YYYY-MM>/result.csv`. Because the archive write
  happens on every run (not just the first of the month), the **current month's**
  archive file is overwritten/updated daily; a new `<YYYY-MM>` folder only starts
  when the month rolls over (e.g. `cost-analysis/archive/2026-11/result.csv` begins
  2026-11-01). See [08-blob-storage-and-reporting.md](08-blob-storage-and-reporting.md)
  for the full blob folder layout.

## How the merge actually works

1. **Export phase (per cluster, 00:10 UTC)** — each cluster's `cost-analysis-export`
   CronJob reads the in-cluster Cost Analysis add-on agent and writes one raw CSV to
   `cost-analysis/<cluster-name>/export-<YYYY-MM-DD>.csv`. Clusters never talk to each
   other; there's no cross-cluster connectivity requirement (see
   [09-multi-cluster-data-collection.md](09-multi-cluster-data-collection.md)).
2. **Merge phase (hub only, 00:30 UTC)** — `aks-cost-analysis-merge` on
   `aks-paas-dev-usgovva-kites` does, in order:
   - **Import AKS data**: lists every `cost-analysis/<cluster>/export-*.csv` blob
     across all clusters and loads them into a temporary SQLite database
     (`aks_splits` table). Logged as `processed AKS export files count=N`.
   - **Import Cost Management data**: lists blobs under `reports/aks-cost-export/`,
     keeps only the latest file per export-period folder (so re-runs of an Azure Cost
     Management export don't double-count), and loads them (`cost_management`
     table). Logged as `keeping latest cost management file per folder listed=X
     selected=Y` then `processed cost management files count=Y`.
   - **Join**: runs a SQL query joining `cost_management` rows to the matching
     `aks_splits` rows by resource group path and usage date, multiplying
     `UsageQuantity`/`PreTaxCost` by each split's `Fraction` to produce
     Kubernetes-attributed dollar amounts. Logged as `executing join query`, then
     `wrote result rows count=N` once the joined CSV is written to a temp file.
   - **Upload (archive, then latest)**: uploads the joined CSV to
     `cost-analysis/archive/<YYYY-MM>/result.csv` first (`archived result uploaded
     successfully`), then re-uploads the same content to `cost-analysis/result.csv`
     (`latest result uploaded successfully`). Finishes with `data processing
     completed successfully`.
3. On a real production run (validated 2026-10-30 against image `1.3.0`), this join
   produced **6,070,128 rows** from 196 AKS export files and 3 cost management
   files — the join and both uploads together took a few minutes end-to-end, which
   is expected given the dataset size and is not a sign of a problem.

## Caveat: not every cluster reports yet

Only clusters with the `cost-analysis-export` CronJob actually **applied** contribute
data to the merge. As of 2026-10-30:

- **12 clusters are implemented and reporting**: Atlas ×10,
  `aks-kites-dev-usgovva-staging`, and the hub `aks-paas-dev-usgovva-kites` (which
  also runs the merge). Nothing further needed here.
- **~15 more clusters have manifests in git pinned to image `1.3.0`** (bumped ahead of
  the pipeline, commit `499b43ed`) **but are not yet applied to their clusters** —
  these clusters are invisible to the merge until their CronJob is actually running.
  See [15-CICD_planning.md](15-CICD_planning.md) for the full cluster classification
  and planned rollout batches.
- **2 clusters are blocked on infra issues** (`aks-il5-team-dev-ugva-development` —
  AKS RBAC `Forbidden`; `aks-il5-team-il4dev-ugva-development` — private DNS
  resolution failure) and won't report until those are fixed.
- The remaining clusters have not been onboarded at all (no Azure identity/manifest
  work done yet).

**Practical takeaway for FinOps**: `result.csv` today reflects only the 12 already-
implemented clusters. Coverage will expand incrementally as the GitLab CI/CD pipeline
(see [15-CICD_planning.md](15-CICD_planning.md)) applies the remaining manifests in
batches — each newly-applied cluster starts contributing data starting with its first
`00:10 UTC` export run after apply, with no gap-filling or backfill of historical days
before that point.
