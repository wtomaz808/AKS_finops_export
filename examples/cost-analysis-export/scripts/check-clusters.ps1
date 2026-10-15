$base = "https://management.usgovcloudapi.net/subscriptions"
$items = @(
  @("c98c2229-d604-406d-9746-d163d5d6069a","rg-atlas-dev-usgovva-aks-analysis","aks-atlas-dev-usgovva-analysis"),
  @("c98c2229-d604-406d-9746-d163d5d6069a","rg-atlas-dev-usgovva-aks-devops","aks-atlas-dev-usgovva-devops"),
  @("c98c2229-d604-406d-9746-d163d5d6069a","rg-atlas-dev-usgovva-aks-devtest","aks-atlas-dev-usgovva-devtest"),
  @("c98c2229-d604-406d-9746-d163d5d6069a","rg-atlas-dev-usgovva-aks-ida","aks-atlas-dev-usgovva-ida"),
  @("f4ee4fc4-ea48-4c3f-8b6f-b6699724b6fe","rg-ams-dev-usgovva-aks-devtest","aks-ams-dev-usgovva-devtest"),
  @("7707fc25-6678-4ed5-81f4-2f17eae1f636","rg-paas-dev-usgovva-aks-kites","aks-paas-dev-usgovva-kites")
)
foreach ($i in $items) {
  $u = "$base/$($i[0])/resourceGroups/$($i[1])/providers/Microsoft.ContainerService/managedClusters/$($i[2])?api-version=2025-01-01"
  $r = az rest --method get --url $u -o json | ConvertFrom-Json
  $p = $r.properties
  "{0}  tier={1} costAnalysis={2} oidc={3} wi={4} k8s={5}" -f $r.name, $r.sku.tier, $p.metricsProfile.costAnalysis.enabled, $p.oidcIssuerProfile.enabled, $p.securityProfile.workloadIdentity.enabled, $p.kubernetesVersion
}
