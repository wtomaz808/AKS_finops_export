$d = Import-Csv "$env:TEMP\result.csv"
"rows: $($d.Count)"
"--- by cluster"
$d | Group-Object ClusterName | ForEach-Object { "{0}`t{1}`t{2}" -f $_.Name, $_.Count, [math]::Round(($_.Group | Measure-Object PreTaxCost -Sum).Sum, 2) }
"--- by bucket"
$d | Group-Object SplitBucket | ForEach-Object { "{0}`t{1}`t{2}" -f $_.Name, $_.Count, [math]::Round(($_.Group | Measure-Object PreTaxCost -Sum).Sum, 2) }
"--- by date"
$d | Group-Object UsageDateTime | Sort-Object Name | ForEach-Object { "{0}`t{1}`t{2}" -f $_.Name, $_.Count, [math]::Round(($_.Group | Measure-Object PreTaxCost -Sum).Sum, 2) }
"--- by cluster and subscription"
$d | Group-Object ClusterName, SubscriptionName | ForEach-Object { "{0}`t{1}" -f $_.Name, $_.Count }
