param(
  [string] $Account = "finopshubug4x7ytxror47uu",
  [string] $Container = "aksexports"
)
# Lists every cluster folder under cost-analysis/ with its files, then checks each file's contents:
# the ClusterName value and the resource groups it references must belong to the folder's cluster.
$ErrorActionPreference = "Stop"
$key = az storage account keys list --account-name $Account --resource-group rg-il5-finops-mgmt-ugtx --subscription f616ec0a-c8b7-451a-b119-90ee96d716db --query "[0].value" -o tsv
$json = az storage blob list --account-name $Account --account-key $key --container-name $Container --prefix "cost-analysis/" --only-show-errors -o json
$blobs = $json | ConvertFrom-Json | Where-Object { $_.name -match '/export-[^/]+\.csv(\.gz)?$' }
foreach ($g in ($blobs | Group-Object { ($_.name -split '/')[1] } | Sort-Object Name)) {
  $folder = $g.Name
  "== $folder  ($($g.Count) files)"
  foreach ($b in ($g.Group | Sort-Object name)) {
    $leaf = [IO.Path]::GetFileName($b.name)
    $f = Join-Path $env:TEMP "$folder.$leaf"
    az storage blob download --account-name $Account --account-key $key --container-name $Container --name $b.name --file $f --overwrite --only-show-errors -o none 2>$null
    $rows = Import-Csv $f
    $clusters = ($rows | Group-Object ClusterName | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ", "
    $rgs = ($rows | ForEach-Object { if ($_.ID -match '/resourceGroups/([^/]+)/') { $Matches[1].ToLower() } } | Sort-Object -Unique) -join ", "
    $flag = if ($clusters -eq "$folder=$($rows.Count)") { "OK" } else { "MISMATCH" }
    "   {0,-22} rows={1,-5} modified={2}  [{3}]" -f $leaf, $rows.Count, $b.properties.lastModified.ToString("MM-dd HH:mm"), $flag
    "      ClusterName: $clusters"
    "      resource groups: $rgs"
  }
}
