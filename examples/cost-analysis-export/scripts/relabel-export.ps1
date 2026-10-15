param(
  [Parameter(Mandatory)] [string] $BlobName,       # e.g. cost-analysis/aks-atlas-dev-usgovva-devops/export-2026-10-13.csv
  [Parameter(Mandatory)] [string] $WrongCluster,   # name written in the file (wrong)
  [Parameter(Mandatory)] [string] $RightCluster,   # cluster the data actually belongs to
  [string] $Account = "finopshubug4x7ytxror47uu",
  [string] $Container = "aksexports"
)
# Relabels an export file written under the wrong cluster, uploads it under the right cluster prefix,
# keeps a local backup, then deletes the mislabeled blob. Aborts if the file doesn't look as expected.
$ErrorActionPreference = "Stop"
$key = az storage account keys list --account-name $Account --resource-group rg-il5-finops-mgmt-ugtx --subscription f616ec0a-c8b7-451a-b119-90ee96d716db --query "[0].value" -o tsv
$leaf = [IO.Path]::GetFileName($BlobName)
$backup = Join-Path $env:TEMP "$WrongCluster.$leaf.backup"
$fixed = Join-Path $env:TEMP "$RightCluster.$leaf"

az storage blob download --account-name $Account --account-key $key --container-name $Container --name $BlobName --file $backup --overwrite --only-show-errors -o none
$text = [IO.File]::ReadAllText($backup)
$rows = ($text -split "`n").Count - 2   # minus header and trailing newline
$hits = ([regex]::Matches($text, [regex]::Escape($WrongCluster))).Count
"rows=$rows occurrences of '$WrongCluster'=$hits"
if ($hits -ne $rows -or $text -match [regex]::Escape("/resourceGroups/rg-atlas-dev-usgovva-cluster-$($WrongCluster.Split('-')[-1])/")) {
  throw "File does not match expectation (one cluster-name occurrence per row, none for the wrong cluster's resource group). Nothing changed."
}
[IO.File]::WriteAllText($fixed, $text.Replace($WrongCluster, $RightCluster), (New-Object Text.UTF8Encoding($false)))

$newBlob = ($BlobName -replace [regex]::Escape($WrongCluster), $RightCluster)
az storage blob upload --account-name $Account --account-key $key --container-name $Container --name $newBlob --file $fixed --only-show-errors -o none
"uploaded $newBlob"
az storage blob delete --account-name $Account --account-key $key --container-name $Container --name $BlobName --only-show-errors
"deleted $BlobName (backup: $backup)"
