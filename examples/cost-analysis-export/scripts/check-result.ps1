param(
  [string] $Account = "finopshubug4x7ytxror47uu",
  [string] $Container = "aksexports",
  [string] $Blob = "cost-analysis/result.csv",
  [switch] $Download
)
# Shows result.csv size and last-modified time. With -Download, saves it to %TEMP%\result.csv for analyze.ps1.
$ErrorActionPreference = "Stop"
$key = az storage account keys list --account-name $Account --resource-group rg-il5-finops-mgmt-ugtx --subscription f616ec0a-c8b7-451a-b119-90ee96d716db --query "[0].value" -o tsv
$p = az storage blob show --account-name $Account --account-key $key --container-name $Container --name $Blob --only-show-errors -o json | ConvertFrom-Json
"{0}  size={1:N1} MB  modified={2:u}" -f $Blob, ($p.properties.contentLength / 1MB), $p.properties.lastModified
if ($Download) {
  az storage blob download --account-name $Account --account-key $key --container-name $Container --name $Blob --file "$env:TEMP\result.csv" --overwrite --only-show-errors -o none
  if ($LASTEXITCODE -ne 0) { throw "download failed" }
  "downloaded to $env:TEMP\result.csv"
}
