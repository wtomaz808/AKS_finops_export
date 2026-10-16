# AKS resource add-ons and downtime considerations

This document describes the expected impact of enabling the AKS features required by
Cost Analysis export workloads:

- OIDC issuer
- Microsoft Entra Workload Identity
- AKS Cost Analysis

These changes are generally designed to be non-disruptive to running application
workloads, but Azure does not provide an absolute zero-downtime guarantee for every
cluster configuration. Treat them as AKS update operations and perform them during an
approved maintenance window when the customer requires strict availability.

## Expected impact

| Feature | Expected impact |
|---|---|
| **OIDC issuer** | Changes AKS control-plane configuration. Existing application Pods should continue running. A brief Kubernetes API/control-plane interruption is possible while Azure reconciles the cluster. |
| **Workload Identity** | Enables the AKS Workload Identity webhook/add-on. Existing Pods are normally unaffected. Pods using Workload Identity must be newly created or restarted to receive injected identity tokens. |
| **Cost Analysis** | Deploys the `cost-analysis-agent` into `kube-system` and updates AKS monitoring configuration. It should not restart application Pods, but it consumes node resources and may be affected by insufficient capacity. |

## Important distinctions

- These changes do not intentionally delete or restart application workloads.
- They are still Azure AKS update operations and may temporarily affect Kubernetes API
  access.
- Enabling Workload Identity does not alter existing application Pods unless they are
  recreated or explicitly restarted.
- Workload Identity injection applies when a Pod is created with the appropriate
  ServiceAccount and workload identity label.
- Enabling Cost Analysis adds a system Pod and therefore requires sufficient node
  capacity.
- A cluster reporting `provisioningState: Failed` should not be modified until that
  condition is understood.
- `provisioningState` describes the Azure Resource Manager state of the AKS resource;
  it is not the health state of application Deployments or Pods.

## Recommended no-downtime procedure

For each cluster, complete the following steps independently:

1. Schedule the changes during an approved maintenance window.
2. Confirm application health before making changes.
3. Confirm node health and available capacity.
4. Confirm workloads have appropriate replica counts and PodDisruptionBudgets.
5. Enable one feature at a time.
6. Monitor application health, nodes, and Kubernetes API access during the operation.
7. Wait for the AKS provisioning state to return to `Succeeded`.
8. Confirm the Cost Analysis agent is `Running` in `kube-system`.
9. Confirm the OIDC issuer and Workload Identity settings.
10. Proceed to the next cluster only after validation succeeds.

## Azure portal checks before changing a cluster

1. Open the AKS cluster in the Azure Government portal.
2. Review the cluster's **Activity log** for recent failed operations.
3. Review **Monitoring** and application health dashboards.
4. Review **Nodes and node pools** for capacity and unhealthy nodes.
5. Confirm the cluster is not already undergoing an update or maintenance operation.
6. Confirm the customer has an approved change window.

## Feature-specific validation

### OIDC issuer

After enabling OIDC, verify that the cluster exposes an issuer URL. The URL is later
used in the federated identity credential for the customer-provided UAMI.

### Workload Identity

After enabling Workload Identity, verify that the cluster reports the feature enabled.
The export workload must use:

- The customer-provided UAMI client ID.
- The `cost-analysis-export-sa` ServiceAccount.
- The `azure.workload.identity/use: "true"` Pod label.

Existing application Pods should not require a restart unless they themselves need to
start using Workload Identity.

### Cost Analysis

After enabling Cost Analysis, verify that the AKS Cost Analysis agent is running in
`kube-system` before deploying the export workload. If the agent cannot schedule,
inspect node capacity and Pod events before proceeding.

## Azure CLI and portal note

The Azure CLI installed on the original deployment workstation was version `2.55.0`
and did not recognize `--enable-cost-analysis`. The Azure portal or a current Azure
Cloud Shell can be used to enable Cost Analysis when the local CLI does not support the
flag.

The Azure portal path is generally:

**AKS cluster → Monitoring → Cost analysis → Enable cost analysis**

The exact portal labels can vary by Azure Government portal version. Verify the feature
shows as enabled before continuing.

## Decision rule

These operations should be treated as **expected to be non-disruptive, but not
risk-free**. Do not claim guaranteed zero downtime. If the customer cannot accept even
a brief control-plane or scheduling interruption, defer the change until an approved
maintenance window or customer-approved operational process is available.
