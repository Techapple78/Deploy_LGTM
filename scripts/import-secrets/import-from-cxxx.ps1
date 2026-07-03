[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourcePath,

  [Parameter(Mandatory = $false)]
  [string]$OutputPath = ".\secrets\tmp\imported-secrets.json",

  [Parameter(Mandatory = $false)]
  [ValidateSet("Auto", "Cxxx", "DeployCrewAI")]
  [string]$Profile = "Auto"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourcePath)) {
  throw "SourcePath not found: $SourcePath"
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

function ConvertTo-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $baseUri = [System.Uri]((Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\') + '\')
  $pathUri = [System.Uri]((Resolve-Path -LiteralPath $Path).Path)
  [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Get-TfVarsKeys {
  param([Parameter(Mandatory = $true)][string]$Path)

  Get-Content -LiteralPath $Path |
    Select-String -Pattern '^\s*([A-Za-z0-9_]+)\s*=' |
    ForEach-Object { $_.Matches[0].Groups[1].Value } |
    Select-Object -Unique
}

function New-FileSecret {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Category
  )

  [ordered]@{
    category = $Category
    relativePath = ConvertTo-RelativePath -BasePath $BasePath -Path $Path
    fileName = Split-Path -Leaf $Path
    contentBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path))
  }
}

if ($Profile -eq "Auto") {
  if ((Test-Path -LiteralPath (Join-Path $SourcePath "terraform")) -and (Test-Path -LiteralPath (Join-Path $SourcePath "secrets"))) {
    $Profile = "DeployCrewAI"
  } else {
    $Profile = "Cxxx"
  }
}

if ($Profile -eq "DeployCrewAI") {
  $terraformPath = Join-Path $SourcePath "terraform"
  $secretsPath = Join-Path $SourcePath "secrets"

  if (-not (Test-Path -LiteralPath $terraformPath) -or -not (Test-Path -LiteralPath $secretsPath)) {
    throw "DeployCrewAI profile expects terraform/ and secrets/ under $SourcePath"
  }

  $tfVarFiles = @(
    Join-Path $terraformPath "terraform.tfvars"
    Join-Path $terraformPath "credentials.auto.tfvars"
    Join-Path $secretsPath "k3s-vsphere-source\terraform\terraform.tfvars"
    Join-Path $secretsPath "k3s-vsphere-source\terraform\credentials.auto.tfvars"
  ) | Where-Object { Test-Path -LiteralPath $_ }

  $secretFiles = @(
    Join-Path $secretsPath "kubeconfig"
    Join-Path $secretsPath "argocd-repository-key"
    Join-Path $secretsPath "argocd-repository-key.pub"
    Join-Path $secretsPath "template-pbk"
    Join-Path $secretsPath "template-pvk"
  ) | Where-Object { Test-Path -LiteralPath $_ }

  $payload = [ordered]@{
    profile = "DeployCrewAI"
    sourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    terraform = [ordered]@{
      files = @($tfVarFiles | ForEach-Object {
        [ordered]@{
          relativePath = ConvertTo-RelativePath -BasePath $SourcePath -Path $_
          keys = @(Get-TfVarsKeys -Path $_)
          contentBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $_).Path))
        }
      })
    }
    files = @($secretFiles | ForEach-Object { New-FileSecret -BasePath $SourcePath -Path $_ -Category "deploy-crewai-secret-file" })
  }

  $payload | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  Write-Host "Imported source-project Terraform variables and secret files to $OutputPath"
  Write-Host "Values were not printed. This output path must remain ignored by Git."
  return
}

$candidateJson = Join-Path $SourcePath "secrets.json"

if (Test-Path -LiteralPath $candidateJson) {
  $payload = Get-Content -Raw -LiteralPath $candidateJson | ConvertFrom-Json
} else {
  $grafanaUserFile = Join-Path $SourcePath "grafana-admin-user.txt"
  $grafanaPasswordFile = Join-Path $SourcePath "grafana-admin-password.txt"

  if (-not (Test-Path -LiteralPath $grafanaUserFile) -or -not (Test-Path -LiteralPath $grafanaPasswordFile)) {
    throw "Expected either $candidateJson or grafana-admin-user.txt and grafana-admin-password.txt in $SourcePath"
  }

  $payload = [ordered]@{
    grafana = [ordered]@{
      adminUser = (Get-Content -Raw -LiteralPath $grafanaUserFile).Trim()
      adminPassword = (Get-Content -Raw -LiteralPath $grafanaPasswordFile).Trim()
    }
  }
}

$payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Imported local secret metadata to $OutputPath"
Write-Host "This file is ignored by Git and must remain local."
