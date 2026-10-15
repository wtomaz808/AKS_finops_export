param(
  [Parameter(Mandatory)] [string] $Cluster,
  [Parameter(Mandatory)] [string] $ResourceGroup,
  [string] $Subscription = "c98c2229-d604-406d-9746-d163d5d6069a"
)
# Read-only diagnostics run through the ARM run-command API (works on private clusters).
$cmd = "kubectl get pods -n kube-system -l app=cost-analysis-agent -o wide; echo ---; kubectl get sa,cronjob,job,pods -n cost-analysis; echo ---; kubectl get events -n cost-analysis --sort-by=.lastTimestamp | tail -15"
az aks command invoke --subscription $Subscription -g $ResourceGroup -n $Cluster --command $cmd --only-show-errors
