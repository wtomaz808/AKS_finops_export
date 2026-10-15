$sub = "c98c2229-d604-406d-9746-d163d5d6069a"
$clusters = @(
  @("rg-atlas-dev-usgovva-aks-analysis","aks-atlas-dev-usgovva-analysis"),
  @("rg-atlas-dev-usgovva-aks-devops","aks-atlas-dev-usgovva-devops"),
  @("rg-atlas-dev-usgovva-aks-devtest","aks-atlas-dev-usgovva-devtest"),
  @("rg-atlas-dev-usgovva-aks-ida","aks-atlas-dev-usgovva-ida")
)
foreach ($c in $clusters) {
  $r = az aks show --subscription $sub -g $c[0] -n $c[1] --query "{state:provisioningState,oidc:oidcIssuerProfile.enabled,wi:securityProfile.workloadIdentity.enabled,issuer:oidcIssuerProfile.issuerUrl}" -o json | ConvertFrom-Json
  "{0}`tstate={1} oidc={2} wi={3}`n  {4}" -f $c[1], $r.state, $r.oidc, $r.wi, $r.issuer
}
