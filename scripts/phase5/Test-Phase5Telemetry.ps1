param(
    [string]$Namespace = "phase5-telemetry",
    [string]$ObservabilityNamespace = "observability",
    [string]$App = "phase5-telemetry-app"
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

Invoke-Step "Pods phase5" {
    kubectl -n $Namespace get pods -o wide
}

Invoke-Step "Services phase5" {
    kubectl -n $Namespace get svc,ingress
}

Invoke-Step "NetworkPolicies phase5" {
    kubectl -n $Namespace get networkpolicy
}

Invoke-Step "Alloy status" {
    kubectl -n $ObservabilityNamespace get pods -l app.kubernetes.io/name=alloy -o wide
}

Invoke-Step "Application health endpoint" {
    kubectl -n $Namespace exec deploy/$App -- wget -qO- http://127.0.0.1:3000/healthz
}

Invoke-Step "Generate nominal traffic" {
    kubectl -n $Namespace exec deploy/$App -- wget -qO- http://127.0.0.1:3000/api/work
}

Invoke-Step "Generate controlled error" {
    kubectl -n $Namespace exec deploy/$App -- wget -qO- http://127.0.0.1:3000/api/error
}

Invoke-Step "Application metrics sample" {
    kubectl -n $Namespace exec deploy/$App -- wget -qO- http://127.0.0.1:3000/metrics
}

Invoke-Step "Recent application logs" {
    kubectl -n $Namespace logs deploy/$App --tail=30
}

Write-Host "Phase 5 smoke checks completed. Validate Loki, Mimir and Tempo from Grafana dashboards."
