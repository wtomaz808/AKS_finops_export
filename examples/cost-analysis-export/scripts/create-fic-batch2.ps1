$ErrorActionPreference = "Stop"
$sub = "7707fc25-6678-4ed5-81f4-2f17eae1f636"
$rg = "rg-kites-test-usgovva-001"
$id = "cost-analysis-export-aks-paas-dev-usgovva-kites"
$subject = "system:serviceaccount:cost-analysis:cost-analysis-export-sa"
$issuers = [ordered]@{
  "aks-atlas-dev-usgovva-ingest"        = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/5514aae8-64e7-421a-b0fc-42e220d775f3/"
  "aks-atlas-dev-usgovva-integration"   = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/9770d7a4-ea67-45b3-bfa8-df7fe28da62a/"
  "aks-atlas-dev-usgovva-play"          = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/d9c8949e-2468-416e-aeb6-406dc6cfc6cb/"
  "aks-atlas-dev-usgovva-play-unstable" = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/9120a9ff-42f1-4fcc-9cfc-e0b68f817a06/"
  "aks-atlas-dev-usgovva-test"          = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/7290bf0e-e264-4f2b-8bad-407910ea8e07/"
  "aks-atlas-dev-usgovva-vtest"         = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/56725966-35a9-4159-8eba-9db2a88b79e6/"
}
$existing = @(az identity federated-credential list --subscription $sub -g $rg --identity-name $id --query "[].name" -o tsv --only-show-errors)
foreach ($k in $issuers.Keys) {
  $name = "cost-analysis-$k-export"
  if ($existing -contains $name) { "$name : exists"; continue }
  az identity federated-credential create --subscription $sub -g $rg --identity-name $id --name $name --issuer $issuers[$k] --subject $subject --audiences "api://AzureADTokenExchange" --only-show-errors -o none
  if ($LASTEXITCODE -ne 0) { throw "create failed for $name" }
  "$name : created"
}
"--- verify (read back from Azure)"
$after = az identity federated-credential list --subscription $sub -g $rg --identity-name $id -o json --only-show-errors | ConvertFrom-Json
$bad = @()
foreach ($k in $issuers.Keys) {
  $f = $after | Where-Object { $_.name -eq "cost-analysis-$k-export" }
  $ok = $f -and $f.issuer -eq $issuers[$k] -and $f.subject -eq $subject -and $f.audiences -contains "api://AzureADTokenExchange"
  "{0} : {1}" -f $k, $(if ($ok) { "OK" } else { "MISMATCH" })
  if (-not $ok) { $bad += $k }
}
"total credentials on identity: $($after.Count) (limit 20)"
if ($bad) { throw "Mismatch: $($bad -join ', ')" }
