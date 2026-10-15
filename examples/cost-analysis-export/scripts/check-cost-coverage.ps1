param(
  [Parameter(Mandatory)] [string[]] $NodeResourceGroups,
  [string] $Account = "finopshubug4x7ytxror47uu",
  [string] $Container = "aksexports",
  [string] $Blob = "reports/aks-cost-export/20261001-20261031/aks-cost-export_9252b9a1-981f-4f10-a793-ccea061722a1.csv"
)
# Counts Cost Management rows per node resource group in the customer's applications export.
$key = az storage account keys list --account-name $Account --resource-group rg-il5-finops-mgmt-ugtx --subscription f616ec0a-c8b7-451a-b119-90ee96d716db --query "[0].value" -o tsv
$f = Join-Path $env:TEMP "apps-oct.csv"
if (-not (Test-Path $f)) {
  az storage blob download --account-name $Account --account-key $key --container-name $Container --name $Blob --file $f --overwrite --only-show-errors -o none 2>&1 | Out-Null
}
$counts = @{}; $days = @{}
foreach ($t in $NodeResourceGroups) { $counts[$t] = 0; $days[$t] = New-Object System.Collections.Generic.HashSet[string] }
Import-Csv $f | ForEach-Object {
  $id = $_.InstanceId.ToLower()
  foreach ($t in $NodeResourceGroups) {
    if ($id.Contains("/resourcegroups/$t/")) { $counts[$t]++; [void]$days[$t].Add($_.UsageDateTime) }
  }
}
foreach ($t in $NodeResourceGroups) {
  $d = $days[$t] | Sort-Object
  "{0}  rows={1}  days={2}" -f $t, $counts[$t], $(if ($d) { "$($d[0]) .. $($d[-1])" } else { "none" })
}
