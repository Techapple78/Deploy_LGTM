param(
  [string]$Namespace = "phase5-telemetry",
  [string]$ObservabilityNamespace = "observability",
  [string]$App = "phase5-telemetry-app",
  [int]$StressIterations = 120,
  [int]$ChargeDurationSeconds = 180
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  Write-Host "== $Name =="
  & $Command
  Write-Host ""
}

function Invoke-InApp {
  param(
    [string]$Path,
    [switch]$AllowFailure
  )

  $command = "wget -qO- http://127.0.0.1:3000$Path"
  if ($AllowFailure) {
    $command = "$command 2>/dev/null || true"
  }
  kubectl -n $Namespace exec deploy/$App -- sh -c $command
}

function Start-PortForward {
  param(
    [string]$Service,
    [int]$LocalPort,
    [int]$RemotePort
  )

  $job = Start-Job -ScriptBlock {
    param($ns, $svc, $local, $remote)
    kubectl -n $ns port-forward "svc/$svc" "$local`:$remote"
  } -ArgumentList $ObservabilityNamespace, $Service, $LocalPort, $RemotePort

  Start-Sleep -Seconds 3
  return $job
}

function Stop-PortForward {
  param(
    [System.Management.Automation.Job]$Job
  )

  if ($Job) {
    Stop-Job $Job -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $Job -Force -ErrorAction SilentlyContinue | Out-Null
  }
}

function Invoke-LokiQuery {
  param([string]$Query)

  $encoded = [uri]::EscapeDataString($Query)
  Invoke-RestMethod -Uri "http://127.0.0.1:3100/loki/api/v1/query_range?query=$encoded&limit=5" -TimeoutSec 30
}

function Invoke-MimirQuery {
  param([string]$Query)

  $encoded = [uri]::EscapeDataString($Query)
  Invoke-RestMethod -Uri "http://127.0.0.1:9009/prometheus/api/v1/query?query=$encoded" -TimeoutSec 30
}

function Invoke-TempoSearch {
  Invoke-RestMethod -Uri "http://127.0.0.1:3201/api/search?tags=service.name%3Dphase5-telemetry-app&limit=5" -TimeoutSec 30
}

$startedAt = Get-Date
Write-Host "Phase 5 full test started at $($startedAt.ToString("s"))"
Write-Host "StressIterations=$StressIterations ChargeDurationSeconds=$ChargeDurationSeconds"
Write-Host ""

Invoke-Step "GitOps and runtime inventory" {
  kubectl -n argocd get applications alloy grafana phase5-telemetry observability-network-policies -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
  kubectl -n $Namespace get pods,svc,ingress,networkpolicy
  kubectl -n $ObservabilityNamespace get pods -l app.kubernetes.io/name=alloy
}

Invoke-Step "Unit tests" {
  Write-Host "healthz:"
  Invoke-InApp -Path "/healthz"
  Write-Host "page:"
  $page = (Invoke-InApp -Path "/") -join "`n"
  if ($page -notmatch "Deploy_LGTM Phase 5 Telemetry") {
    throw "HTML page did not contain expected title"
  }
  Write-Host "page contains expected title"
  Write-Host "nominal traffic:"
  Invoke-InApp -Path "/api/work"
  Write-Host "controlled error:"
  Invoke-InApp -Path "/api/error" -AllowFailure
  Write-Host "metrics:"
  $metrics = (Invoke-InApp -Path "/metrics") -join "`n"
  $metrics
  if ($metrics -notmatch "phase5_http_requests_total") {
    throw "Application metrics are missing phase5_http_requests_total"
  }
}

Invoke-Step "Stress test" {
  for ($i = 1; $i -le $StressIterations; $i++) {
    Invoke-InApp -Path "/api/work" | Out-Null
    if (($i % 12) -eq 0) {
      Invoke-InApp -Path "/api/error" -AllowFailure | Out-Null
    }
  }
  Write-Host "stress requests sent: $StressIterations nominal, $([math]::Floor($StressIterations / 12)) controlled errors"
}

Invoke-Step "Short load test" {
  $deadline = (Get-Date).AddSeconds($ChargeDurationSeconds)
  $nominal = 0
  $errors = 0
  while ((Get-Date) -lt $deadline) {
    Invoke-InApp -Path "/api/work" | Out-Null
    $nominal += 1
    if (($nominal % 15) -eq 0) {
      Invoke-InApp -Path "/api/error" -AllowFailure | Out-Null
      $errors += 1
    }
    Start-Sleep -Milliseconds 500
  }
  Write-Host "load requests sent: $nominal nominal, $errors controlled errors"
}

Invoke-Step "LGTM backend validation" {
  $lokiJob = Start-PortForward -Service "loki-gateway" -LocalPort 3100 -RemotePort 80
  $mimirJob = Start-PortForward -Service "mimir-gateway" -LocalPort 9009 -RemotePort 80
  $tempoJob = Start-PortForward -Service "tempo" -LocalPort 3201 -RemotePort 3200

  try {
    $loki = Invoke-LokiQuery -Query '{namespace="phase5-telemetry"} |= "trace_id"'
    $lokiStreams = @($loki.data.result).Count
    Write-Host "loki_streams=$lokiStreams"
    if ($lokiStreams -lt 1) {
      throw "Loki did not return Phase 5 logs"
    }

    $mimir = Invoke-MimirQuery -Query 'phase5_http_requests_total{app="phase5-telemetry-app"}'
    $mimirSeries = @($mimir.data.result).Count
    Write-Host "mimir_series=$mimirSeries"
    if ($mimirSeries -lt 1) {
      throw "Mimir did not return Phase 5 metrics"
    }

    $tempo = Invoke-TempoSearch
    $tempoTraces = @($tempo.traces).Count
    Write-Host "tempo_traces=$tempoTraces"
    if ($tempoTraces -lt 1) {
      throw "Tempo did not return Phase 5 traces"
    }
  } finally {
    Stop-PortForward -Job $lokiJob
    Stop-PortForward -Job $mimirJob
    Stop-PortForward -Job $tempoJob
  }
}

Invoke-Step "Regression checks" {
  kubectl -n $Namespace get pods
  kubectl -n $Namespace logs deploy/$App --tail=20
  kubectl -n $ObservabilityNamespace get pods
}

$finishedAt = Get-Date
Write-Host "Phase 5 full test completed at $($finishedAt.ToString("s"))"
Write-Host "DurationSeconds=$([int]($finishedAt - $startedAt).TotalSeconds)"
