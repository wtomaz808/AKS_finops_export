$sub = "7707fc25-6678-4ed5-81f4-2f17eae1f636"
$rg = "rg-kites-test-usgovva-001"
$id = "cost-analysis-export-aks-paas-dev-usgovva-kites"
$issuers = [ordered]@{
  "aks-atlas-dev-usgovva-analysis" = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/76b57ac7-a719-4205-a45a-bcb25ccef598/"
  "aks-atlas-dev-usgovva-devops"   = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/5db46e0c-1cdb-4037-a3d8-731c9c805f3c/"
  "aks-atlas-dev-usgovva-devtest"  = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/69036372-fd93-4c3b-ba7f-9ba8a0a928a4/"
  "aks-atlas-dev-usgovva-ida"      = "https://usgovvirginia.oic.prod-aks.azure.us/071a8389-cee6-448e-9015-ce55e029f82f/f3570192-69c3-4189-bc4d-ace5d7c6507e/"
}
"--- existing credentials"
az identity federated-credential list --subscription $sub -g $rg --identity-name $id --query "[].{name:name,subject:subject,audiences:audiences[0]}" -o table
foreach ($k in $issuers.Keys) {
  $name = "cost-analysis-$k-export"
  "creating $name"
  az identity federated-credential create --subscription $sub -g $rg --identity-name $id --name $name --issuer $issuers[$k] --subject "system:serviceaccount:cost-analysis:cost-analysis-export-sa" --audiences "api://AzureADTokenExchange" --query "{name:name,subject:subject,issuer:issuer}" -o json --only-show-errors
}
"--- after"
az identity federated-credential list --subscription $sub -g $rg --identity-name $id --query "[].{name:name,subject:subject}" -o table
