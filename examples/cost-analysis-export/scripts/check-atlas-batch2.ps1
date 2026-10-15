$base = "https://management.usgovcloudapi.net/subscriptions"
$sub = "c98c2229-d604-406d-9746-d163d5d6069a"
$names = 'ingest','integration','play','play-unstable','test','vtest'
foreach ($n in $names) {
  $c = "aks-atlas-dev-usgovva-$n"
  $rg = "rg-atlas-dev-usgovva-aks-$n"
  $u = "$base/$sub/resourceGroups/$rg/providers/Microsoft.ContainerService/managedClusters/$($c)?api-version=2025-01-01"
  $r = az rest --method get --url $u -o json | ConvertFrom-Json
  $p = $r.properties
  "{0}  tier={1} costAnalysis={2} oidc={3} wi={4} state={5} kubelet={6}" -f $r.name, $r.sku.tier, $p.metricsProfile.costAnalysis.enabled, $p.oidcIssuerProfile.enabled, $p.securityProfile.workloadIdentity.enabled, $p.provisioningState, $p.identityProfile.kubeletidentity.objectId
  "   issuer={0}" -f $p.oidcIssuerProfile.issuerURL
}
