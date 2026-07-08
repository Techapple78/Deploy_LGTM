# Rapport Phase 5 - Plan de test complet

Date: 2026-07-08

## Objectif

Lancer la stabilisation production legere avec une application temoin maitrisee et un harnais OTLP de bout en bout.

Le perimetre Phase 5 couvre:

- application web maitrisee `phase5-telemetry-app`;
- logs JSON collectes par Alloy depuis Kubernetes;
- metriques Prometheus scrapees par Alloy et poussees vers Mimir;
- traces OTLP/HTTP envoyees vers Alloy puis Tempo;
- dashboard Grafana dedie;
- NetworkPolicies default-deny et allowlists explicites;
- plan de test unitaire, global, stress, charge et regression.

## Architecture de test

```mermaid
flowchart LR
  User[Navigateur] -->|HTTP via Traefik| App[phase5-telemetry-app]
  App -->|stdout JSON| Alloy[Alloy]
  App -->|/metrics| Alloy
  App -->|OTLP HTTP 4318| Alloy
  Alloy --> Loki[Loki]
  Alloy --> Mimir[Mimir]
  Alloy --> Tempo[Tempo]
  Grafana[Grafana] --> Loki
  Grafana --> Mimir
  Grafana --> Tempo
```

## Ressources creees

| Ressource | Role |
| --- | --- |
| `phase5-telemetry` | Namespace dedie a l'application temoin. |
| `phase5-telemetry-app` | Application Node.js maitrisee, sans dependance npm externe. |
| `phase5-telemetry-source` | Code source applicatif embarque en `ConfigMap`. |
| `phase5-telemetry-app` Service | Exposition interne sur TCP 3000. |
| `phase5-telemetry-app` Ingress | Acces via Traefik sur `phase5-app.example.local`. |
| NetworkPolicies `phase5-*` | Default deny, DNS, Traefik, Alloy OTLP et scrape metrics. |
| Dashboard Grafana | `Deploy_LGTM Phase 5 Telemetry Overview`. |

## Tests unitaires

| Test | Commande | Attendu |
| --- | --- | --- |
| Healthcheck | `GET /healthz` | `ok` |
| Page HTML | `GET /` | page Phase 5 servie |
| Trafic nominal | `GET /api/work` | JSON `status=ok` avec `trace_id` |
| Erreur controlee | `GET /api/error` | HTTP 500 controle avec `trace_id` |
| Metrics | `GET /metrics` | compteurs `phase5_*` |

## Tests globaux LGTM

| Backend | Verification | Requete indicative |
| --- | --- | --- |
| Loki | logs JSON applicatifs visibles | `{namespace="phase5-telemetry", app="phase5-telemetry-app"} |= "trace_id"` |
| Mimir | metriques scrapees par Alloy | `up{app="phase5-telemetry-app"}` |
| Mimir | trafic applicatif | `rate(phase5_http_requests_total{app="phase5-telemetry-app"}[5m])` |
| Tempo | traces recues via OTLP | recherche service `phase5-telemetry-app` |
| Grafana | dashboard non vide | `Deploy_LGTM Phase 5 Telemetry Overview` |

## Tests de stress

Objectif: verifier que l'application, Alloy et les backends LGTM restent stables avec une generation rapide d'evenements.

Plan:

1. Generer des appels repetes sur `/api/work`.
2. Injecter un ratio controle d'appels `/api/error`.
3. Observer CPU/RAM/restarts des pods `phase5-telemetry`, `alloy`, `loki`, `mimir`, `tempo` et `grafana`.
4. Observer les compteurs `phase5_otlp_traces_sent_total` et `phase5_otlp_trace_failures_total`.

Critere de sortie:

- pas de CrashLoopBackOff;
- pas de progression anormale des erreurs OTLP;
- dashboard Grafana exploitable pendant le test;
- Loki/Mimir/Tempo restent interrogeables.

## Tests de charge

Objectif: utiliser une charge moderee sur 24h pour ajuster ressources, retention et NetworkPolicies.

Mesures:

- CPU/RAM des pods LGTM;
- latence de requete Grafana;
- volume logs Loki;
- cardinalite et series Mimir;
- disponibilite Tempo;
- restarts et events Kubernetes.

Critere de sortie:

- ressources ajustees;
- aucune saturation PVC evidente;
- alertes essentielles proposees ou creees;
- runbook d'exploitation mis a jour.

## Tests de regression

Avant chaque changement Phase 5:

```powershell
.\scripts\Test-Repository.ps1
```

Apres synchronisation Argo CD:

```powershell
.\scripts\phase5\Test-Phase5Telemetry.ps1
kubectl -n argocd get applications
kubectl -n phase5-telemetry get pods,svc,ingress,networkpolicy
kubectl -n observability get pods
```

Regression fonctionnelle attendue:

- application accessible via Traefik;
- logs visibles dans Loki;
- metriques visibles dans Mimir;
- traces visibles dans Tempo;
- dashboard Grafana non vide;
- aucun secret en clair ajoute au repo.

## Risques et limites

- Le chemin MySQL reel n'est pas encore deploye: il necessite des credentials sous forme `SealedSecret`.
- L'application Phase 5 actuelle valide le chemin web/logs/metrics/traces, puis le lot MySQL sera ajoute apres preparation des secrets.
- Les tests de stress et de charge doivent etre lances depuis l'environnement cluster, pas depuis CI.
- Le DNS `phase5-app.example.local` doit etre adapte localement hors Git si un acces navigateur est requis.
