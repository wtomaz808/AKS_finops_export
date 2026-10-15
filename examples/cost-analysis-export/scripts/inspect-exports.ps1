param(
  [Parameter(Mandatory)] [string] $Prefix,
  [string] $Account = "finopshubug4x7ytxror47uu",
  [string] $Container = "aksexports"
)
# Lists blobs under a prefix and summarizes the node resource groups referenced in each export file.
$key = az storage account keys list --account-name $Account --resource-group rg-il5-finops-mgmt-ugtx --subscription f616ec0a-c8b7-451a-b119-90ee96d716db --query "[0].value" -o tsv
$blobs = az storage blob list --account-name $Account --account-key $key --container-name $Container --prefix $Prefix --query "[].name" -o tsv
foreach ($b in $blobs) {
  $f = Join-Path $env:TEMP ([IO.Path]::GetFileName($b))
  az storage blob download --account-name $Account --account-key $key --container-name $Container --name $b --file $f --overwrite --only-show-errors -o none
  $meta = az storage blob show --account-name $Account --account-key $key --container-name $Container --name $b --query "properties.lastModified" -o tsv
  "== $b  (modified $meta)"
  Import-Csv $f | Group-Object ClusterName, @{Expression = { if ($_.ID -match '/resourceGroups/([^/]+)/') { $Matches[1].ToLower() } else { 'none' } } } | ForEach-Object { "   {0}  rows={1}" -f $_.Name, $_.Count }
}
