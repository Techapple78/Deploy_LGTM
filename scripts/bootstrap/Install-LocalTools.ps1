[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ToolsDir = ".\.tools"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ToolsDir)) {
  New-Item -ItemType Directory -Path $ToolsDir | Out-Null
}

$resolvedToolsDir = (Resolve-Path -LiteralPath $ToolsDir).Path

function Expand-ZipToTool {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$ExecutableName,
    [Parameter(Mandatory = $true)][string]$DestinationName
  )

  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
  $zip = Join-Path $tmp "tool.zip"
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
    $exe = Get-ChildItem -LiteralPath $tmp -Recurse -Filter $ExecutableName | Select-Object -First 1
    if (-not $exe) {
      throw "Unable to find $ExecutableName in archive $Uri"
    }
    Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $resolvedToolsDir $DestinationName) -Force
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force
  }
}

function Get-GitHubLatestAsset {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$Pattern
  )

  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
  $asset = $release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
  if (-not $asset) {
    throw "Unable to find asset matching $Pattern in $Repo latest release"
  }

  [pscustomobject]@{
    Version = $release.tag_name
    Name = $asset.name
    Url = $asset.browser_download_url
  }
}

$kubesealPath = Join-Path $resolvedToolsDir "kubeseal.exe"
if (-not (Test-Path -LiteralPath $kubesealPath)) {
  $kubeseal = Get-GitHubLatestAsset -Repo "bitnami-labs/sealed-secrets" -Pattern "kubeseal-.*windows-amd64.*\.tar\.gz$"
  $kubesealTmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $kubesealTmp | Out-Null
  try {
    $archive = Join-Path $kubesealTmp $kubeseal.Name
    Invoke-WebRequest -Uri $kubeseal.Url -OutFile $archive
    tar -xzf $archive -C $kubesealTmp
    $exe = Get-ChildItem -LiteralPath $kubesealTmp -Recurse -Filter "kubeseal.exe" | Select-Object -First 1
    if (-not $exe) {
      throw "Unable to find kubeseal.exe in $($kubeseal.Name)"
    }
    Copy-Item -LiteralPath $exe.FullName -Destination $kubesealPath -Force
  } finally {
    Remove-Item -LiteralPath $kubesealTmp -Recurse -Force
  }
} else {
  $kubeseal = [pscustomobject]@{ Version = "already-installed" }
}

$helmPath = Join-Path $resolvedToolsDir "helm.exe"
if (-not (Test-Path -LiteralPath $helmPath)) {
  $helmRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/helm/helm/releases/latest"
  $helmVersion = $helmRelease.tag_name
  $helmUrl = "https://get.helm.sh/helm-$helmVersion-windows-amd64.zip"
  Expand-ZipToTool -Uri $helmUrl -ExecutableName "helm.exe" -DestinationName "helm.exe"
} else {
  $helmVersion = "already-installed"
}

$terraformPath = Join-Path $resolvedToolsDir "terraform.exe"
if (-not (Test-Path -LiteralPath $terraformPath)) {
  $terraformIndex = Invoke-RestMethod -Uri "https://checkpoint-api.hashicorp.com/v1/check/terraform"
  $terraformVersion = $terraformIndex.current_version
  $terraformUrl = "https://releases.hashicorp.com/terraform/$terraformVersion/terraform_${terraformVersion}_windows_amd64.zip"
  Expand-ZipToTool -Uri $terraformUrl -ExecutableName "terraform.exe" -DestinationName "terraform.exe"
} else {
  $terraformVersion = "already-installed"
}

Write-Host "Installed local tools in $resolvedToolsDir"
Write-Host "kubeseal $($kubeseal.Version)"
Write-Host "helm $helmVersion"
Write-Host "terraform v$terraformVersion"
Write-Host "Use: `$env:PATH = '$resolvedToolsDir;' + `$env:PATH"
