param(
  [string]$OutputDirectory = "local/phase6"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Invoke-KubectlJson {
  param(
    [string[]]$Arguments,
    [string]$OutputFile
  )

  $target = Join-Path $OutputDirectory $OutputFile
  & kubectl @Arguments -o json | Out-File -FilePath $target -Encoding utf8
}

function Invoke-KubectlText {
  param(
    [string[]]$Arguments,
    [string]$OutputFile
  )

  $target = Join-Path $OutputDirectory $OutputFile
  & kubectl @Arguments | Out-File -FilePath $target -Encoding utf8
}

Invoke-KubectlText -Arguments @("config", "current-context") -OutputFile "context.txt"
Invoke-KubectlJson -Arguments @("get", "nodes") -OutputFile "nodes.json"
Invoke-KubectlJson -Arguments @("get", "namespaces") -OutputFile "namespaces.json"
Invoke-KubectlJson -Arguments @("get", "clusterroles") -OutputFile "clusterroles.json"
Invoke-KubectlJson -Arguments @("get", "clusterrolebindings") -OutputFile "clusterrolebindings.json"
Invoke-KubectlJson -Arguments @("get", "roles", "-A") -OutputFile "roles.json"
Invoke-KubectlJson -Arguments @("get", "rolebindings", "-A") -OutputFile "rolebindings.json"
Invoke-KubectlJson -Arguments @("get", "networkpolicies", "-A") -OutputFile "networkpolicies.json"
Invoke-KubectlJson -Arguments @("get", "clusterpolicies.kyverno.io") -OutputFile "kyverno-clusterpolicies.json"
Invoke-KubectlJson -Arguments @("get", "policyreports.wgpolicyk8s.io", "-A") -OutputFile "policyreports.json"

$summary = [ordered]@{
  generatedAt = (Get-Date).ToString("s")
  outputDirectory = (Resolve-Path $OutputDirectory).Path
  note = "Local evidence only. Do not commit this directory."
}

$summary | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $OutputDirectory "summary.json") -Encoding utf8

Write-Host "Phase 6 evidence exported to $OutputDirectory"
