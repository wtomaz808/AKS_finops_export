$acct = "finopshubug4x7ytxror47uu"
$key = az storage account keys list --account-name $acct --resource-group rg-il5-finops-mgmt-ugtx --subscription f616ec0a-c8b7-451a-b119-90ee96d716db --query "[0].value" -o tsv
$blob = "reports/aks-cost-export/20261001-20261031/aks-cost-export_9252b9a1-981f-4f10-a793-ccea061722a1.csv"
az storage blob show --account-name $acct --account-key $key --container-name aksexports --name $blob --query "{size:properties.contentLength,modified:properties.lastModified}" -o json
az storage blob download --account-name $acct --account-key $key --container-name aksexports --name $blob --file "$env:TEMP\apps-oct.csv" --overwrite --only-show-errors -o none 2>&1 | Out-Null
$targets = 'rg-atlas-dev-usgovva-cluster-analysis','rg-atlas-dev-usgovva-cluster-devops','rg-atlas-dev-usgovva-cluster-devtest','rg-atlas-dev-usgovva-cluster-ida','rg-ams-dev-usgovva-cluster-devtest'
$counts = @{}
$dates = @{}
foreach ($t in $targets) { $counts[$t] = 0 }
Import-Csv "$env:TEMP\apps-oct.csv" | ForEach-Object {
  $id = $_.InstanceId.ToLower()
  foreach ($t in $targets) {
    if ($id.Contains("/resourcegroups/$t/")) {
      $counts[$t]++
      if (-not $dates.ContainsKey($t)) { $dates[$t] = New-Object System.Collections.Generic.HashSet[string] }
      [void]$dates[$t].Add($_.UsageDateTime)
    }
  }
}
foreach ($t in $targets) { "{0}  rows={1}  days={2}" -f $t, $counts[$t], $(if ($dates.ContainsKey($t)) { ($dates[$t] | Sort-Object | Select-Object -First 1) + ' .. ' + ($dates[$t] | Sort-Object | Select-Object -Last 1) } else { 'none' }) }
