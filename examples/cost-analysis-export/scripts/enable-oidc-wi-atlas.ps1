param(
  [Parameter(Mandatory)] [string[]] $Suffixes,
  [string] $Subscription = "c98c2229-d604-406d-9746-d163d5d6069a"
)
# Enables the OIDC issuer and workload identity on atlas clusters (asynchronous).
foreach ($s in $Suffixes) {
  $c = "aks-atlas-dev-usgovva-$s"
  $rg = "rg-atlas-dev-usgovva-aks-$s"
  "starting update on $c"
  az aks update --subscription $Subscription --resource-group $rg --name $c --enable-oidc-issuer --enable-workload-identity --no-wait --only-show-errors
  "exit code: $LASTEXITCODE"
}
