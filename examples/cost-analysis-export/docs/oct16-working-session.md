# October 16, 2026 working session

## Summary

The session advanced Azure-side preparation for the next clusters, but no new cluster
export workload was successfully deployed from the kube VDI. The two clusters actively
worked today were:

- `aks-il5-team-dev-ugva-development`
- `aks-il5-team-il4dev-ugva-development`

The existing 12-cluster implementation was not changed. No application workloads were
restarted, and no AKS add-on changes were made during the IL5/IL4 rollout work.

## What succeeded

### Repository and documentation

- Added and published the cluster inventory in [14-aks-cluster-inventory.md](14-aks-cluster-inventory.md).
- Added and published AKS add-on and downtime guidance in
  [13-aks-resource-addons.md](13-aks-resource-addons.md).
- Updated [12-aks-commands.md](12-aks-commands.md) to use individual copy/paste blocks
  rather than loops or scripts on the kube VDI.
- Added cluster-specific manifests for the two IL5/IL4 development clusters.
- Kept the remaining clusters untouched.

### Azure-side preparation: IL5 development

Cluster: `aks-il5-team-dev-ugva-development`

- Subscription: `km-il5-dev`
- Cluster resource group: `rg-il5-team-dev-ugva-aks-development`
- Customer UAMI: `cost-analysis-aks-il5-team-dev-ugva-development`
- UAMI resource group: `rg-il5-team-dev-ugva-cluster-development`
- UAMI client ID: `68c02d1a-41dc-4d13-9fcf-e8d4c31d6a0e`
- OIDC issuer: enabled and verified.
- Workload Identity: enabled and verified.
- Cost Analysis: enabled according to the AKS REST API.
- Provisioning state: `Succeeded`.
- Granted `Storage Blob Data Contributor` on the existing `aksexports` container only.
- Created and verified the federated credential for:
  `system:serviceaccount:cost-analysis:cost-analysis-export-sa`.
- Verified the kubelet already had registry pull access for the pinned export image.

### Azure-side preparation: IL4 development

Cluster: `aks-il5-team-il4dev-ugva-development`

- Subscription: `km-il4-dev` — this is not the `km-il5-dev` subscription.
- Cluster resource group: `rg-il5-team-il4dev-ugva-aks-development`
- Customer UAMI: `cost-analysis-aks-il5-team-il4dev-ugva-development`
- UAMI resource group: `rg-il5-team-il4dev-ugva-cluster-development`
- UAMI client ID: `cfd6a38e-a852-4743-8c94-8294b90ea86c`
- OIDC issuer: enabled and verified.
- Workload Identity: enabled and verified.
- Cost Analysis: enabled according to the AKS REST API.
- Provisioning state: `Succeeded`.
- Granted `Storage Blob Data Contributor` on the existing `aksexports` container only.
- Created and verified the federated credential for:
  `system:serviceaccount:cost-analysis:cost-analysis-export-sa`.
- Verified the kubelet already had registry pull access for the pinned export image.

## What did not succeed

### IL5 development: Kubernetes RBAC blocked the apply

The kube VDI successfully obtained credentials and reached the cluster. The Cost
Analysis agent was healthy at `3/3 Running`.

The manifest apply was rejected by Azure Kubernetes RBAC:

- Namespace creation: `Forbidden`.
- ServiceAccount creation: `Forbidden`.
- `kube-system` Service creation: `Forbidden`.
- CronJob creation: `Forbidden`.

The cluster uses Azure RBAC for Kubernetes authorization and has local AKS accounts
disabled. The current kube VDI user can authenticate and read resources, but does not
have sufficient Kubernetes write permissions. The `cost-analysis` namespace was not
created, and no export Job ran.

### IL4 development: private DNS blocked access before Kubernetes RBAC

The kube VDI context was correctly set to:

`aks-il5-team-il4dev-ugva-development`

However, the kube VDI could not resolve the private API hostname:

`aks-il5-team-il4dev-ugva-development.privatelink.usgovvirginia.cx.aks.containerservice.azure.us`

The VDI uses custom DNS servers:

- `10.122.100.24`
- `10.122.100.25`
- `10.122.100.26`
- `168.63.129.16`

The first resolver returned `DNS name does not exist`. The exact tests against the other
custom resolvers were not completed. Azure-side checks confirmed:

- The AKS cluster is private.
- The private DNS A record exists and points to `10.97.168.4`.
- The central private DNS zone is linked to the cluster VNet.
- The cluster provisioning state is `Succeeded`.

This indicates a DNS forwarding or network-path problem between the kube VDI and the
Azure private DNS zone. Kubernetes RBAC was not reached for this cluster, and the
manifest was not applied.

## Issues discovered

### 1. Kube VDI Azure Kubernetes RBAC access

The deployment identity needs approved Azure Kubernetes RBAC permissions to create:

- The `cost-analysis` namespace at cluster scope.
- The export ServiceAccount and CronJob in `cost-analysis`.
- The `cost-analysis-agent-svc` Service in `kube-system`.

A namespace-only writer role is insufficient because the manifest also creates a
Service in `kube-system`. Do not use `--admin`; local accounts are disabled on these
clusters.

### 2. Private AKS DNS resolution

The IL4 development kube VDI cannot resolve the private API endpoint. The DNS/network
team must provide forwarding or another approved DNS path for:

`privatelink.usgovvirginia.cx.aks.containerservice.azure.us`

Do not use a hosts-file entry or modify AKS private networking as a workaround.

### 3. Azure CLI Cost Analysis field

The installed local Azure CLI is version `2.55.0` and does not expose the current
Cost Analysis flag/property correctly. The authoritative status was obtained through
the AKS REST API. No Cost Analysis enablement changes were made during this session.

### 4. Shared versus customer UAMIs

The rollout was corrected to use one customer-provided cost-analysis UAMI per cluster,
located in the supporting cluster resource group. New clusters must not use the shared
hub UAMI.

An earlier exploratory argo federated credential was added to the shared hub UAMI. It
should be reviewed and removed after the customer-specific argo UAMI federation is
confirmed, to avoid leaving an unnecessary trust relationship.

## Next steps

### IL5 development

1. Have the customer grant the kube VDI deployment user approved Azure Kubernetes RBAC
   write access for this cluster, or have an authorized cluster administrator perform
   the apply.
2. Pull the latest `cx_usecase` branch on the kube VDI.
3. Confirm the context and Cost Analysis agent.
4. Apply the manifest as a separate command.
5. Verify the namespace and CronJob exist.
6. Run `export-1` and confirm the success log and cluster-specific blob path.
7. Do not proceed to another cluster until this validation succeeds.

### IL4 development

1. Ask the network/DNS team to correct forwarding from the kube VDI to the Azure private
   DNS zone.
2. Confirm `Resolve-DnsName` returns the private address `10.97.168.4`.
3. Confirm TCP 443 connectivity to the private API endpoint.
4. Run `kubectl auth can-i create namespaces` and
   `kubectl auth can-i create services -n kube-system`.
5. If both checks return `yes`, apply the manifest in a separate command.
6. Verify the namespace and CronJob before creating the export Job.
7. Run the export and validate the log and storage path.

### Remaining IL5/IL4 clusters

Do not prepare or deploy the remaining three team clusters until the two current
blockers are resolved and the first successful export is recorded. Continue using the
same sequence:

1. Verify the cluster and customer UAMI.
2. Verify Cost Analysis, OIDC, and Workload Identity.
3. Grant only the required storage-container role.
4. Create the exact federated credential.
5. Prepare one manifest.
6. Deploy with individual kube VDI copy/paste blocks.
7. Validate before moving on.
