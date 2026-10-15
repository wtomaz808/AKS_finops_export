param(
  [Parameter(Mandatory)] [hashtable] $Kubelets   # cluster name -> kubelet identity objectId
)
# Grants Container Registry Repository Reader on the registry to each kubelet identity (skips if present).
# Fails loudly: any CLI error stops the script, and the final check must list the role for every identity.
$ErrorActionPreference = "Stop"
$acr = "/subscriptions/bd4a0538-88f5-47ed-8ac3-a43ee9ad9862/resourceGroups/rg-il5-team-prd-ugva-acr/providers/Microsoft.ContainerRegistry/registries/craksprodusgovva"
$role = "Container Registry Repository Reader"

function Get-Roles($oid) {
  $out = az role assignment list --assignee $oid --scope $acr --query "[].roleDefinitionName" -o tsv --only-show-errors 2>$null
  if ($LASTEXITCODE -ne 0) { throw "role assignment list failed for $oid" }
  return @($out)
}

foreach ($k in ($Kubelets.Keys | Sort-Object)) {
  $oid = $Kubelets[$k]
  if ((Get-Roles $oid) -contains $role) {
    "$k : already has the role"
  } else {
    az role assignment create --assignee-object-id $oid --assignee-principal-type ServicePrincipal --role $role --scope $acr --only-show-errors -o none
    if ($LASTEXITCODE -ne 0) { throw "role assignment create failed for $k" }
    "$k : granted"
  }
}
"--- verify"
$failed = @()
foreach ($k in ($Kubelets.Keys | Sort-Object)) {
  $roles = Get-Roles $Kubelets[$k]
  "{0}: {1}" -f $k, ($roles -join ', ')
  if ($roles -notcontains $role) { $failed += $k }
}
if ($failed) { throw "Missing role on: $($failed -join ', ')" }
"All identities verified."
