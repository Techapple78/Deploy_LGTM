[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InputFile,

  [Parameter(Mandatory = $false)]
  [string]$OutputDir = ".\secrets\sealed",

  [Parameter(Mandatory = $false)]
  [string]$Namespace = "observability",

  [Parameter(Mandatory = $false)]
  [string]$ControllerName = "sealed-secrets-controller",

  [Parameter(Mandatory = $false)]
  [string]$ControllerNamespace = "kube-system"
)

$ErrorActionPreference = "Stop"

foreach ($tool in @("kubectl", "kubeseal")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Required tool not found in PATH: $tool"
  }
}

if (-not (Test-Path -LiteralPath $InputFile)) {
  throw "InputFile not found: $InputFile"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$data = Get-Content -Raw -LiteralPath $InputFile | ConvertFrom-Json

function ConvertTo-SecretKey {
  param([Parameter(Mandatory = $true)][string]$Value)

  $key = $Value.ToLowerInvariant() -replace '[^a-z0-9\.\-_]', '-'
  $key = $key.Trim('.-_')
  if (-not $key) {
    throw "Unable to derive a Kubernetes Secret key from: $Value"
  }
  $key
}

function New-SealedSecretFromFiles {
  param(
    [Parameter(Mandatory = $true)][string]$SecretName,
    [Parameter(Mandatory = $true)][array]$Items,
    [Parameter(Mandatory = $true)][string]$OutputFile
  )

  $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tempDir | Out-Null

  try {
    $fromFileArgs = @()
    foreach ($item in $Items) {
      $key = ConvertTo-SecretKey -Value $item.key
      $tempFile = Join-Path $tempDir $key
      [System.IO.File]::WriteAllBytes($tempFile, [Convert]::FromBase64String([string]$item.contentBase64))
      $fromFileArgs += "--from-file"
      $fromFileArgs += "$key=$tempFile"
    }

    $secretYaml = & kubectl create secret generic $SecretName `
      --namespace $Namespace `
      @fromFileArgs `
      --dry-run=client `
      -o yaml

    $sealedYaml = $secretYaml | & kubeseal `
      --controller-name $ControllerName `
      --controller-namespace $ControllerNamespace `
      --format yaml
    if ($LASTEXITCODE -ne 0) {
      throw "kubeseal failed while generating $OutputFile"
    }
    $sealedYaml | Set-Content -LiteralPath $OutputFile -Encoding UTF8
  } finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force
  }
}

if ($data.profile -eq "DeployCrewAI") {
  $terraformItems = @()
  foreach ($file in @($data.terraform.files)) {
    $terraformItems += [pscustomobject]@{
      key = "terraform-$($file.relativePath)"
      contentBase64 = $file.contentBase64
    }
  }

  if ($terraformItems.Count -gt 0) {
    New-SealedSecretFromFiles `
      -SecretName "deploy-crewai-terraform-vars" `
      -Items $terraformItems `
      -OutputFile (Join-Path $OutputDir "deploy-crewai-terraform-vars.sealedsecret.yaml")
  }

  $fileItems = @()
  foreach ($file in @($data.files)) {
    $fileItems += [pscustomobject]@{
      key = $file.relativePath
      contentBase64 = $file.contentBase64
    }
  }

  if ($fileItems.Count -gt 0) {
    New-SealedSecretFromFiles `
      -SecretName "deploy-crewai-imported-secrets" `
      -Items $fileItems `
      -OutputFile (Join-Path $OutputDir "deploy-crewai-imported-secrets.sealedsecret.yaml")
  }

  Write-Host "Generated source-project SealedSecrets in $OutputDir"
  return
}

if (-not $data.grafana.adminUser -or -not $data.grafana.adminPassword) {
  throw "Input JSON must contain grafana.adminUser and grafana.adminPassword"
}

$secretYaml = & kubectl create secret generic grafana-admin `
  --namespace $Namespace `
  --from-literal "admin-user=$($data.grafana.adminUser)" `
  --from-literal "admin-password=$($data.grafana.adminPassword)" `
  --dry-run=client `
  -o yaml

$outputFile = Join-Path $OutputDir "grafana-admin.sealedsecret.yaml"

$sealedYaml = $secretYaml | & kubeseal `
  --controller-name $ControllerName `
  --controller-namespace $ControllerNamespace `
  --format yaml
if ($LASTEXITCODE -ne 0) {
  throw "kubeseal failed while generating $outputFile"
}
$sealedYaml | Set-Content -LiteralPath $outputFile -Encoding UTF8

Write-Host "Wrote $outputFile"
Write-Host "Review that the file kind is SealedSecret before committing."
