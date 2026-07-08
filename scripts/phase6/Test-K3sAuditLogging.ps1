param(
  [string]$Namespace = "default",
  [string]$OutputDirectory = "local/phase6"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$cmName = "audit-smoke-$stamp"

kubectl -n $Namespace create configmap $cmName --from-literal=purpose=deploy-lgtm-audit-smoke | Out-Null
kubectl -n $Namespace delete configmap $cmName | Out-Null

@"
Audit smoke generated:
- namespace: $Namespace
- configmap: $cmName
- expected audit verbs: create, delete
- expected resource: configmaps

Verification:
1. Sur le serveur K3S, verifier /var/log/kubernetes/audit/audit.log.
2. Dans Loki, chercher les evenements audit Kubernetes si Alloy collecte ce fichier.
"@ | Out-File -FilePath (Join-Path $OutputDirectory "audit-smoke-$stamp.txt") -Encoding utf8

Write-Host "Audit smoke event generated for ConfigMap $cmName in namespace $Namespace"
