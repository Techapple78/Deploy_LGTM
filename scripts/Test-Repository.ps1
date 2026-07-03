[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [switch]$SkipHelmRender
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

function Invoke-HelmTemplate {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
  )

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & helm @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($exitCode -ne 0) {
    $output | ForEach-Object { Write-Host $_ }
    throw "Helm render failed: helm $($Arguments -join ' ')"
  }
  $output | Set-Content -LiteralPath $OutputPath -Encoding utf8
}

$toolsDir = Join-Path $repoRoot ".tools"
if (Test-Path -LiteralPath $toolsDir) {
  $env:PATH = "$toolsDir;$env:PATH"
}

Write-Host "== PowerShell syntax =="
$failed = $false
Get-ChildItem -Recurse -Filter *.ps1 |
  Where-Object { $_.FullName -notmatch "\\.terraform\\" -and $_.FullName -notmatch "\\.tools\\" } |
  ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
      $failed = $true
      Write-Host "ERROR $($_.FullName)" -ForegroundColor Red
      $errors | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }
    }
  }
if ($failed) {
  throw "PowerShell syntax validation failed"
}

Write-Host "== YAML parse =="
python -c "import yaml, pathlib; [list(yaml.safe_load_all(p.read_text(encoding='utf-8'))) for p in pathlib.Path('.').rglob('*.yaml') if 'secrets/tmp' not in str(p) and 'rendered/' not in p.as_posix() and '.terraform' not in str(p) and '.tools' not in str(p) and '/charts/' not in p.as_posix()]; print('YAML parse OK')"
if ($LASTEXITCODE -ne 0) {
  throw "YAML parse validation failed"
}

Write-Host "== Kustomize =="
kubectl kustomize clusters/k3s/dev | Out-Null
kubectl kustomize clusters/k3s/prod | Out-Null

Write-Host "== Terraform =="
terraform -chdir=infra/terraform/vsphere fmt -check
terraform -chdir=infra/terraform/vsphere validate

Write-Host "== Secret scan =="
$patterns = @(
  ("super" + "secret"),
  ("BEGIN" + " RSA"),
  ("BEGIN" + " OPENSSH"),
  ("BEGIN" + " PRIVATE"),
  "AKIA[0-9A-Z]{16}",
  ("secret" + "_access_key"),
  ("k3s" + "_token\s*="),
  ("vsphere" + "_password\s*=")
)
foreach ($pattern in $patterns) {
  $result = rg -n $pattern --glob "!secrets/tmp/**" --glob "!secrets/sealed/*.yaml" --glob "!rendered/**" --glob "!.tools/**" --glob "!.terraform/**" .
  $result = $result | Where-Object { $_ -notmatch [regex]::Escape("scripts\Test-Repository.ps1") }
  if ($LASTEXITCODE -eq 0) {
    if ($result) {
      Write-Host $result
      throw "Potential secret marker detected: $pattern"
    }
  }
}

if (-not $SkipHelmRender) {
  Write-Host "== Helm render =="
  $renderDir = Join-Path $repoRoot "rendered"
  New-Item -ItemType Directory -Path $renderDir -Force | Out-Null
  Invoke-HelmTemplate -Arguments @("template", "grafana", "grafana/grafana", "--version", "10.5.15", "--namespace", "observability", "-f", "platform/lgtm/grafana/values.yaml") -OutputPath (Join-Path $renderDir "grafana.yaml")
  Invoke-HelmTemplate -Arguments @("template", "loki", "grafana/loki", "--version", "7.0.0", "--namespace", "observability", "-f", "platform/lgtm/loki/values.yaml") -OutputPath (Join-Path $renderDir "loki.yaml")
  Invoke-HelmTemplate -Arguments @("template", "mimir", "grafana/mimir-distributed", "--version", "6.1.0", "--namespace", "observability", "-f", "platform/lgtm/mimir/values.yaml") -OutputPath (Join-Path $renderDir "mimir.yaml")
  Invoke-HelmTemplate -Arguments @("template", "tempo", "grafana/tempo", "--version", "1.24.4", "--namespace", "observability", "-f", "platform/lgtm/tempo/values.yaml") -OutputPath (Join-Path $renderDir "tempo.yaml")
  Invoke-HelmTemplate -Arguments @("template", "alloy", "grafana/alloy", "--version", "1.10.0", "--namespace", "observability", "-f", "platform/lgtm/alloy/values.yaml") -OutputPath (Join-Path $renderDir "alloy.yaml")
  Invoke-HelmTemplate -Arguments @("template", "kyverno-crds", "platform/security/kyverno-crds", "--namespace", "kyverno", "-f", "platform/security/kyverno-crds/values.yaml") -OutputPath (Join-Path $renderDir "kyverno-crds.yaml")
}

Write-Host "Repository validation OK"
