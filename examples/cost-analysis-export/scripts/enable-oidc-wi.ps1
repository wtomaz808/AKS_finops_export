$sub = "c98c2229-d604-406d-9746-d163d5d6069a"
$clusters = @(
  @("rg-atlas-dev-usgovva-aks-analysis","aks-atlas-dev-usgovva-analysis"),
  @("rg-atlas-dev-usgovva-aks-devops","aks-atlas-dev-usgovva-devops"),
  @("rg-atlas-dev-usgovva-aks-devtest","aks-atlas-dev-usgovva-devtest"),
  @("rg-atlas-dev-usgovva-aks-ida","aks-atlas-dev-usgovva-ida")
)
foreach ($c in $clusters) {
  "starting update on $($c[1])"
  az aks update --subscription $sub --resource-group $c[0] --name $c[1] --enable-oidc-issuer --enable-workload-identity --no-wait --only-show-errors
  "exit code: $LASTEXITCODE"
}
