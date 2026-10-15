$acr = "/subscriptions/bd4a0538-88f5-47ed-8ac3-a43ee9ad9862/resourceGroups/rg-il5-team-prd-ugva-acr/providers/Microsoft.ContainerRegistry/registries/craksprodusgovva"
$kubelets = [ordered]@{
  "aks-atlas-dev-usgovva-analysis" = "278fba5a-db23-4e14-99cb-0305886ad893"
  "aks-atlas-dev-usgovva-devops"   = "8099be94-737f-4a8c-8a57-0d5fdb0927db"
  "aks-atlas-dev-usgovva-devtest"  = "2fa56d97-a367-44cb-b165-7663a254c604"
  "aks-atlas-dev-usgovva-ida"      = "2ffb7b8b-43e8-479b-923d-a48224de16cb"
}
foreach ($k in $kubelets.Keys) {
  $oid = $kubelets[$k]
  $existing = az role assignment list --assignee $oid --scope $acr --query "[?roleDefinitionName=='Container Registry Repository Reader'] | length(@)" -o tsv
  if ($existing -eq "0") {
    az role assignment create --assignee-object-id $oid --assignee-principal-type ServicePrincipal --role "Container Registry Repository Reader" --scope $acr --query "{principal:principalId,role:roleDefinitionName}" -o json --only-show-errors
  } else {
    "$k already has Container Registry Repository Reader"
  }
}
"--- verify"
foreach ($k in $kubelets.Keys) {
  "{0}: {1}" -f $k, ((az role assignment list --assignee $kubelets[$k] --scope $acr --query "[].roleDefinitionName" -o tsv) -join ', ')
}
