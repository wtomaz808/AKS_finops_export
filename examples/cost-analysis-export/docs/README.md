# AKS Cost Analysis Export — Documentation

This folder documents the self-managed AKS Cost Analysis CSV export solution in
[`examples/cost-analysis-export`](../), including the Azure Government-compatible
Terraform scaffold added for multi-cluster rollouts.

## Executive summary

The AKS Cost Analysis add-on gives customers a portal view of Kubernetes cost
breakdowns (namespace, deployment, labels), but that data isn't exportable on its own —
and it doesn't include the full Azure Cost Management context (meter details, tags,
reservations, chargebacks). This solution closes that gap: a small Go application, run
as a Kubernetes CronJob, that pulls data from the in-cluster Cost Analysis add-on agent,
joins it against the customer's existing Azure Cost Management export, and produces a
single daily `result.csv` in Blob Storage — combining Kubernetes-level cost attribution
with full Azure Cost Management fidelity, in a format finance/FinOps teams can consume
directly (Excel, Power BI, a data warehouse) without needing portal or API access.

It's self-hosted, self-supported, and requires no changes to customer billing
configuration beyond a standard Cost Management export. Authentication uses Microsoft
Entra Workload Identity throughout — no connection strings, no stored credentials,
nothing to rotate.

This documentation set was written after building, deploying, and validating the
solution end-to-end in a real Azure Government subscription (see
[Deployment guide](06-deployment-guide.md) and [Operations & troubleshooting](07-operations-and-troubleshooting.md)
for the specific gotchas found along the way).

## Contents

| Doc | Covers |
|---|---|
| [01-architecture.md](01-architecture.md) | Detailed architecture, data flow, workflow diagrams, single-cluster vs. many-cluster scale/scope |
| [02-azure-resources.md](02-azure-resources.md) | Every Azure resource the solution creates, and why |
| [03-permissions-and-rbac.md](03-permissions-and-rbac.md) | Managed identity permissions and their limitations, AKS RBAC needs |
| [04-aks-configuration.md](04-aks-configuration.md) | AKS-specific settings: containers, CronJobs, Services, security context |
| [05-terraform-modules.md](05-terraform-modules.md) | Terraform module structure and design decisions |
| [06-deployment-guide.md](06-deployment-guide.md) | Step-by-step deployment guide, prerequisites, configuration |
| [07-operations-and-troubleshooting.md](07-operations-and-troubleshooting.md) | Day-2 operations, monitoring, and troubleshooting playbook |
| [08-blob-storage-and-reporting.md](08-blob-storage-and-reporting.md) | Detailed blob storage folder structure, and per-cluster vs. fleet-wide reporting granularity |

## Quick facts

- **Language/runtime:** Go 1.24, distroless base image, non-root (UID 65534)
- **Deployment unit:** Kubernetes CronJob (one per cluster for export, one centralized for merge)
- **Auth:** Microsoft Entra Workload Identity (OIDC federation) — zero secrets
- **Data destination:** Azure Blob Storage (one shared storage account across all clusters)
- **Clouds validated:** Azure Public and Azure Government (this repo's fork adds Gov Cloud support)
- **Scale tested:** 1 cluster (POC); designed for 50+ clusters across multiple subscriptions under one management group
