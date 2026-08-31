# AKS-specific configuration

This page covers the Kubernetes-level configuration this solution depends on: the
container image, the CronJob spec, the Service it depends on, and the AKS cluster
settings required before any of it will work.

## Prerequisite AKS cluster settings

| Setting | Requirement | Why |
|---|---|---|
| **AKS pricing tier** | Standard or Premium (not Free) | The AKS Cost Analysis add-on is not available on the Free tier. |
| **OIDC issuer** | Enabled (`--enable-oidc-issuer`) | Required for Workload Identity federation — the cluster needs to expose an OIDC issuer URL that Entra ID can validate tokens against. |
| **Workload identity** | Enabled (`--enable-workload-identity`) | Installs the mutating webhook that projects the Azure AD-compatible service account token into annotated Pods. |
| **Cost Analysis add-on** | Enabled (`--enable-cost-analysis`) | Deploys the `cost-analysis-agent` pod in `kube-system` that the export job's HTTP call depends on. Enabling this on a cluster with the wrong tier will fail — upgrade the tier first. |
| **Container registry access** | ACR attached (`az aks update --attach-acr`), or equivalent `imagePullSecrets` | kubelet needs to pull the `aks-cost-export` image. |

## Container image

- **Base image**: multi-stage build — `golang:1.24` to compile (CGO enabled, for the
  SQLite driver), then `gcr.io/distroless/base-debian12` for the runtime image. No
  shell, no package manager, minimal attack surface.
- **Entrypoint**: `./aks-ca-export`, with the operation mode (`export`, `merge`, or
  `both`) passed as the first positional argument — this is what the CronJob's
  container `args` set.
- **Multi-arch**: the reference `build.sh` builds `linux/amd64` and `linux/arm64` via
  `docker buildx`. If Docker isn't available locally, `az acr build` (ACR Tasks) builds
  in the cloud with no local Docker daemon required — validated during this solution's
  testing.

## Container security context (already applied in both `kube.yaml` and the Terraform `workload` module)

| Setting | Value | Why |
|---|---|---|
| `runAsNonRoot` | `true` | Distroless image already runs as non-root; this enforces it can't silently regress. |
| `runAsUser` / `runAsGroup` | `65534` (nobody/nogroup) | No dedicated UID needed — the app touches only `/tmp` and the network. |
| `readOnlyRootFilesystem` | `true` | The app writes only to a temp SQLite file and downloaded blobs, both under `/tmp` (an explicit `emptyDir` volume) — nothing else needs to be writable. |
| `allowPrivilegeEscalation` | `false` | No reason for this workload to ever need more privilege than it starts with. |
| `capabilities.drop` | `["ALL"]` | The app makes outbound HTTP/HTTPS calls only — no raw sockets, no special capabilities needed. |
| `seccompProfile.type` | `RuntimeDefault` | Standard baseline seccomp filtering. |

**Best practice**: don't loosen any of these for convenience — the container has no
legitimate need for root, writable root filesystem, or extra Linux capabilities. If you
ever need to add e.g. a custom CA bundle, mount it as a read-only volume rather than
relaxing `readOnlyRootFilesystem`.

## Resource requests/limits

Both `kube.yaml` and the Terraform module set:
```yaml
resources:
  requests: { memory: "512Mi", cpu: "500m" }
  limits:   { memory: "512Mi", cpu: "500m" }
```
This is generous for what's typically a small daily job (single-digit MB of CSV data
per cluster in most environments), but SQLite's in-memory join and CSV parsing can
spike for very large fleets/long retention windows. **Best practice**: monitor actual
usage (`kubectl top pod` during a run, or Container Insights if enabled) and right-size
downward for small clusters, or upward if a centralized merge job is processing dozens
of clusters' data — the merge job in particular should get more headroom than a
single-cluster export job since it processes everyone's data.

## CronJob configuration

| Field | Recommended value | Why |
|---|---|---|
| `schedule` | Export: e.g. `10 0 * * *` (00:10 UTC). Merge: e.g. `30 0 * * *` (00:30 UTC), after exports. | Merge must run after all export jobs have had time to complete — stagger by at least 15-20 minutes, more for large fleets. |
| `concurrencyPolicy` | `Forbid` | Never run two instances of the same job concurrently — both export and merge assume exclusive access to their target blob paths for the duration of a run. |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | 3 / 3 (Terraform default) | Keeps enough history for troubleshooting without unbounded Job object accumulation. |
| `restartPolicy` | `OnFailure` | Let Kubernetes retry a transient failure (e.g. a momentary storage throttling error) rather than leaving a permanently failed Pod. |
| `volumes` | One `emptyDir` for `/tmp`, sized `2Gi` | Needed because `readOnlyRootFilesystem: true` means the app can't write anywhere else; sized to comfortably hold the temp SQLite DB and any downloaded CSVs for a single merge run. |

**Best practice**: manually trigger a one-off Job from the CronJob
(`kubectl create job --from=cronjob/<name> <test-name> -n cost-analysis`) after every
deployment or image update, rather than waiting for the next scheduled run, to validate
end-to-end before trusting the schedule.

## The `cost-analysis-agent-svc` Service (kube-system)

The AKS Cost Analysis add-on deploys the `cost-analysis-agent` **pod** automatically,
but — as discovered while validating this solution — it does **not** create a stable
Kubernetes Service for it. Without one, the export job has nothing to call. The
Service definition:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: cost-analysis-agent-svc
  namespace: kube-system
spec:
  selector:
    app: cost-analysis-agent
    kubernetes.azure.com/managedby: aks
  ports:
    - protocol: TCP
      port: 9094
      targetPort: 9094
```
This only needs to exist on clusters that actually run the `export` (or `both`) role.
A `merge`-only job on a dedicated hub cluster never calls the agent and doesn't need
this Service.

## Namespace and ServiceAccount naming (multi-role clusters)

If a single cluster ever hosts **both** an export job and the centralized merge job
(common in small POCs, less common at real scale where the hub is usually a dedicated
cluster), give each role its own ServiceAccount name
(`cost-analysis-export-sa` / `cost-analysis-merge-sa`) and its own federated identity
credential name. Two independent deployments both trying to create/own the exact same
namespace or ServiceAccount name will conflict — see
[Terraform modules](05-terraform-modules.md) for how this is handled.
