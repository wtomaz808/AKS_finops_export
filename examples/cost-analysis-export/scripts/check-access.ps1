"--- my roles on the atlas and ams subscriptions"
$me = az ad signed-in-user show --query id -o tsv 2>$null
foreach ($s in 'c98c2229-d604-406d-9746-d163d5d6069a','f4ee4fc4-ea48-4c3f-8b6f-b6699724b6fe') {
  "sub $s"
  az role assignment list --scope "/subscriptions/$s" --assignee $me --include-inherited --include-groups --query "[].{role:roleDefinitionName,scope:scope}" -o tsv
}
"--- management group descendants of 'applications' matching atlas or ams"
az account management-group show -n applications -e -r --query "children[].{name:displayName,id:name,type:type}" -o tsv 2>&1 | Select-String -Pattern "atlas|ams|c98c2229|f4ee4fc4"
"--- ancestors of the atlas sub"
az rest --method get --url "https://management.usgovcloudapi.net/providers/Microsoft.Management/managementGroups/applications/descendants?api-version=2020-05-01" --query "value[?contains(id,'c98c2229') || contains(id,'f4ee4fc4')].{id:id,name:properties.displayName,parent:properties.parent.id}" -o json 2>&1
