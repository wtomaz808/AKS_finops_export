# AKS cluster inventory

Inventory queried from Azure Government on **2026-10-16**.

The supplied working list contained `hub-mgmt-test-aks` twice. This document records
**53 unique AKS clusters**.

## Status definitions

- **Implemented** — the cost-analysis export solution is already deployed and tracked
  in this repository for the cluster.
- **Prepared only** — a manifest exists for the cluster, but the Azure identity and/or
  kube VDI deployment has not been completed.
- **Not implemented** — the cluster is in the customer inventory, but this solution is
  not currently deployed there.

OIDC, Workload Identity, and Cost Analysis were queried from the AKS resource. Cost
Analysis was read through the AKS REST API because the installed Azure CLI does not
expose the current `metricsProfile.costAnalysis.enabled` field correctly.

## Inventory

| Cluster | Subscription | Resource group | Solution | OIDC | Workload Identity | Cost Analysis | Provisioning |
|---|---|---|---|---|---|---|---|
| `aks-ams-dev-usgovva-devtest` | `f4ee4fc4-ea48-4c3f-8b6f-b6699724b6fe` | `rg-ams-dev-usgovva-aks-devtest` | Not implemented | Enabled | Enabled | Disabled | Succeeded |
| `aks-atlas-dev-usgovva-analysis` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-analysis` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-devops` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-devops` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-devtest` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-devtest` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-ida` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-ida` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-ingest` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-ingest` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-integration` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-integration` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-play` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-play` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-play-unstable` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-play-unstable` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-test` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-test` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-atlas-dev-usgovva-vtest` | `c98c2229-d604-406d-9746-d163d5d6069a` | `rg-atlas-dev-usgovva-aks-vtest` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-datasvc-dev-usgovva-argo` | `bf7a7fd5-0bad-4232-bbe1-a14a42c74412` | `rg-datasvc-dev-usgovva-aks-argo` | Prepared only | Enabled | Enabled | Enabled | Succeeded |
| `aks-datasvc-dev-usgovva-cyber` | `bf7a7fd5-0bad-4232-bbe1-a14a42c74412` | `rg-datasvc-dev-usgovva-aks-cyber` | Prepared only | Disabled | Disabled | Enabled | Succeeded |
| `aks-datasvc-dev-usgovva-observability` | `bf7a7fd5-0bad-4232-bbe1-a14a42c74412` | `rg-datasvc-dev-usgovva-aks-observability` | Prepared only | Disabled | Disabled | Enabled | Succeeded |
| `aks-datasvc-dev-usgovva-shared` | `bf7a7fd5-0bad-4232-bbe1-a14a42c74412` | `rg-datasvc-dev-usgovva-aks-shared` | Prepared only | Disabled | Disabled | Enabled | Succeeded |
| `aks-datasvc-sbx-usgovva-shared` | `bf7a7fd5-0bad-4232-bbe1-a14a42c74412` | `rg-datasvc-sbx-usgovva-aks-shared` | Prepared only | Enabled | Enabled | Enabled | Failed |
| `aks-il5-team-dev-ugva-development` | `8f225e15-db94-4fa5-9f29-0669936b7b8a` | `rg-il5-team-dev-ugva-aks-development` | Prepared only | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-il4dev-ugva-development` | `87418a88-0024-4a3a-a5c4-c9f91fc085e0` | `rg-il5-team-il4dev-ugva-aks-development` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-il4mgmt-ugva-management` | `4474c9a2-750a-4e26-a00d-9f0c8a66aadd` | `rg-il5-team-il4mgmt-ugva-aks-management` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-il4prod-ugva-production` | `c4e24366-bb01-4839-a037-69bedff4e013` | `rg-il5-team-il4prod-ugva-aks-production` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-il4stg-ugaz-staging` | `ab5409ac-1aca-4840-b084-33d1ffd20e46` | `rg-il5-team-il4stg-ugaz-aks-staging` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-il4svcs-ugva-services` | `843b4da0-f7a6-4f47-b6a2-d812c49ff3e7` | `rg-il5-team-il4svcs-ugva-aks-services` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-mgmt-ugva-management` | `f616ec0a-c8b7-451a-b119-90ee96d716db` | `rg-il5-team-mgmt-ugva-aks-management` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-prod-ugva-production` | `a2d90e08-c6f6-4458-a055-5f5bbfad357e` | `rg-il5-team-prod-ugva-aks-production` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-stage-ugva-staging` | `c1445365-76a9-4a50-b5b8-1570c8416c49` | `rg-il5-team-stage-ugva-aks-staging` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-il5-team-svcs-ugva-services` | `e8574b94-17f5-46a4-b313-1127c8201efb` | `rg-il5-team-svcs-ugva-aks-services` | Not implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-iris-dev-usgovva-devtest` | `d1649186-f212-40fe-8572-0a45f3a2713b` | `rg-iris-dev-usgovva-aks-devtest` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-iris-dev-usgovva-integration` | `d1649186-f212-40fe-8572-0a45f3a2713b` | `rg-iris-dev-usgovva-aks-integration` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-iris-dev-usgovva-play` | `d1649186-f212-40fe-8572-0a45f3a2713b` | `rg-iris-dev-usgovva-aks-play` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-kites-dev-usgovva-ams` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-ams` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-atlassian` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-atlassian` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-gitlab` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-gitlab` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-gitlab-runners-000` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-gitlab-runners-000` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-harbor` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-harbor` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-mattermost` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-mattermost` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-nexus` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-nexus` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-kites-dev-usgovva-opensearch` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-opensearch` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-kites-dev-usgovva-sonarqube` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-sonarqube` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-staging` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-staging` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-kites-dev-usgovva-vault` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-kites-dev-usgovva-aks-vault` | Not implemented | Disabled | Disabled | Enabled | Succeeded |
| `aks-mitll-dev-usgovva-ja3` | `90c731aa-ebcc-4f2b-bdea-303f640998d9` | `rg-mitll-dev-usgovva-aks-ja3` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-paas-dev-usgovva-devtest` | `0c445027-17dd-4f92-9815-2df200fa61f2` | `rg-paas-dev-usgovva-aks-devtest` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-paas-dev-usgovva-gorf` | `88f122c1-9af6-4fac-b05f-1f6d62448247` | `rg-paas-dev-usgovva-aks-gorf` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-paas-dev-usgovva-hyperion` | `bd53b600-7dc3-448a-8516-df2e823342c2` | `rg-paas-dev-usgovva-aks-hyperion` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-paas-dev-usgovva-kahless` | `2f9fc4ec-8e7c-4571-a872-a1a13079947d` | `rg-paas-dev-usgovva-aks-kahless` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-paas-dev-usgovva-kites` | `7707fc25-6678-4ed5-81f4-2f17eae1f636` | `rg-paas-dev-usgovva-aks-kites` | Implemented | Enabled | Enabled | Enabled | Succeeded |
| `aks-paas-dev-usgovva-malibu` | `de3ad862-92df-4c82-a26f-754d4007f9cf` | `rg-paas-dev-usgovva-aks-malibu` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-paas-dev-usgovva-spectra` | `bc0e85d9-5fda-4a28-8e89-863db29e57e9` | `rg-paas-dev-usgovva-aks-spectra` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-paas-dev-usgovva-starfox` | `fca67800-aec8-45ec-8650-78ee95414bd4` | `rg-paas-dev-usgovva-aks-starfox` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-pitt-sim-ugva-sim` | `fe120894-dcf1-474b-a5bd-aaea3f70c208` | `rg-pitt-sim-ugva-aks-sim` | Not implemented | Enabled | Enabled | Disabled | Succeeded |
| `aks-pitt-sim02-ugva-sim02` | `fe120894-dcf1-474b-a5bd-aaea3f70c208` | `rg-pitt-sim02-ugva-aks-sim02` | Not implemented | Enabled | Enabled | Disabled | Succeeded |
| `aks-quake-dev-usgovva-rssc` | `f6b2c59d-7797-4c8b-822e-41129a8df960` | `rg-quake-dev-usgovva-aks-rssc` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `aks-vpng-dev-usgovva-vpng` | `879b13d8-3e9e-4d25-83af-fe27692f2755` | `rg-vpng-dev-usgovva-aks-vpng` | Not implemented | Disabled | Disabled | Disabled | Succeeded |
| `hub-mgmt-test-aks` | `7c4458c5-3287-4857-8219-39a72be434cf` | `rg-hub-mgmt-test-aks` | Not implemented | Disabled | Disabled | Disabled | Succeeded |

## Summary

- **53** unique clusters queried.
- **12** clusters currently have the solution implemented: the ten Atlas clusters,
  `aks-kites-dev-usgovva-staging`, and `aks-paas-dev-usgovva-kites`.
- **5** Data Services clusters have manifests prepared but are not yet deployed:
  `aks-datasvc-dev-usgovva-argo`, `aks-datasvc-dev-usgovva-cyber`,
  `aks-datasvc-dev-usgovva-observability`, `aks-datasvc-dev-usgovva-shared`, and
  `aks-datasvc-sbx-usgovva-shared`.
- **1** IL5 team cluster (`aks-il5-team-dev-ugva-development`) has a dedicated
  manifest prepared and its UAMI granted Storage Blob Data Contributor on the
  `aksexports` container and federated to the export ServiceAccount. Its kube VDI
  deployment and export test have **not** happened yet. The other four proposed
  IL5/IL4 team clusters remain untouched.
- `aks-datasvc-sbx-usgovva-shared` reports `Failed` provisioning state and should not
  be changed until that state is understood.
- The current solution uses Cost Analysis, so clusters marked Cost Analysis `Enabled`
  are the candidates for future onboarding after UAMI, storage RBAC, federation, and
  kube VDI validation are complete.
- A `Cost Analysis` status of `Enabled` does not mean this repository's export workload
  is deployed; the separate `Solution` column is authoritative for that distinction.
